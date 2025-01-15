`ifndef ROB
`define ROB
`include "const.v"

module ROB(
    input wire clk,
    input wire rst,
    input wire rdy,

    output reg rollback,

    output reg rob_full,

    //decoder to ROB
    input wire inst_valid,
    input wire [`OPCODE_WID] inst_opcode,
    input wire [`REG_ID_WID] inst_rd,
    input wire [`ADDR_WID] inst_pc,
    input wire inst_is_branch,
    input wire inst_predict_is_jump,
    input wire inst_can_commit,
    
    //LSB change rob_can_commit
    input wire lsb_chg,
    input wire [`ROB_ID_WID] lsb_rob_id,
    input wire [`DATA_WID] lsb_rob_data,

    //ALU change rob_can_commit
    input wire alu_chg,
    input wire [`ROB_ID_WID] alu_rob_id,
    input wire [`DATA_WID] alu_rob_data,
    input wire alu_is_jump,
    input wire [`ADDR_WID] alu_jump_pc,

    //decoder call ROB dependencies
    input wire is_call_rs1,
    input wire [`ROB_ID_WID] call_rs1_rob_id,
    input wire is_call_rs2,
    input wire [`ROB_ID_WID] call_rs2_rob_id,

    //ROB call ifetch change pc
    output reg pc_valid,
    output reg [`ADDR_WID] pc,
    output reg is_branch,
    output reg is_jump,
    output reg [`ADDR_WID] jump_pc,

    //ROB commit (update regfile) 
    output reg commit_reg_valid,
    output reg [`REG_ID_WID] commit_reg_rd,
    output reg [`DATA_WID] commit_reg_data, 
    output reg [`ROB_ID_WID] commit_reg_rob_id,
    output reg [`ADDR_WID] commit_reg_pc,

    //ROB update LSB
    output reg commit_lsb_valid,
    output reg [`ROB_ID_WID] commit_lsb_rob_id,
    output reg [`DATA_WID] commit_lsb_data,

    //ROB answer decoder call
    output wire is_rs1_depend,
    output wire [`DATA_WID] rs1_data,
    output wire is_rs2_depend,
    output wire [`DATA_WID] rs2_data,
    output wire [`ROB_ID_WID] rd_rob_id,

    output wire [`ROB_ID_WID] rob_head
);

    reg [`ROB_ID_WID] head;
    reg [`ROB_ID_WID] tail;
    reg [3:0] sz;

    reg rob_busy[`ROB_SZ-1:0];
    reg rob_can_commit[`ROB_SZ-1:0];
    reg [`OPCODE_WID] rob_opcode[`ROB_SZ-1:0];
    reg [`REG_ID_WID] rob_rd[`ROB_SZ-1:0];
    reg [`ADDR_WID] rob_pc[`ROB_SZ-1:0];
    reg [`DATA_WID] rob_rd_data[`ROB_SZ-1:0];
    reg rob_is_branch[`ROB_SZ-1:0];
    reg rob_predict_jump[`ROB_SZ-1:0];//predict
    reg rob_is_jump[`ROB_SZ-1:0];//real
    reg [`ADDR_WID] rob_jump_pc[`ROB_SZ-1:0];//real jump pc

    //ROB queue
    wire [`ROB_ID_WID] nxt_head=head+(sz>0?rob_can_commit[head]:0);
    wire [`ROB_ID_WID] nxt_tail=tail+inst_valid;
    wire [3:0] nxt_sz=sz-(sz>0?rob_can_commit[head]:0)+inst_valid;

    always @(*)begin
        rob_full=(nxt_head==nxt_tail&&nxt_sz>0);
    end

    //answer decoder call after any update
    assign is_rs1_depend=(is_call_rs1?(rob_busy[call_rs1_rob_id]?rob_can_commit[call_rs1_rob_id]:0):0);
    assign rs1_data=(is_call_rs1?(rob_busy[call_rs1_rob_id]?rob_rd_data[call_rs1_rob_id]:0):0);
    assign is_rs2_depend=(is_call_rs2?(rob_busy[call_rs2_rob_id]?rob_can_commit[call_rs2_rob_id]:0):0);
    assign rs2_data=(is_call_rs2?(rob_busy[call_rs2_rob_id]?rob_rd_data[call_rs2_rob_id]:0):0);
    assign rd_rob_id=tail;
    assign rob_head=head;

    // integer cnt,file;
    // initial begin
    //     cnt=1;
    //     file=$fopen("ROB.txt", "w");
    // end

    integer i;
    always @(posedge clk)begin
        if(rst||rollback)begin
            // $display("ROB rollback");
            rollback<=0;
            head<=0;
            tail<=0;
            sz<=0;
            pc_valid<=0;
            is_branch<=0;
            commit_reg_valid<=0;
            commit_lsb_valid<=0;
            for(i=0;i<`ROB_SZ;i=i+1)begin
                rob_busy[i]<=0;
                rob_can_commit[i]<=0;
                rob_opcode[i]<=0;
                rob_rd[i]<=0;
                rob_pc[i]<=0;
                rob_rd_data[i]<=0;
                rob_is_branch[i]<=0;
                rob_predict_jump[i]<=0;
                rob_is_jump[i]<=0;
                rob_jump_pc[i]<=0;
            end
        end else if(rdy)begin
            head<=nxt_head;
            tail<=nxt_tail;
            sz<=nxt_sz;
            commit_reg_valid<=0;
            commit_lsb_valid<=0;
            pc_valid<=0;
            is_branch<=0;

            // if(sz>0)begin
            //     $fwrite(file,"%d %d %d\n",head,tail,sz);
            //     for(i=0;i<`ROB_SZ;i=i+1)begin
            //         if(rob_busy[i])begin
            //             $fwrite(file,"%d %b %h\n",i,rob_opcode[i],rob_pc[i]);
            //         end
            //     end
            // end
            
            if(inst_valid)begin

                //debug
                // case(inst_opcode)
                //     `OPCODE_ARITH:begin
                //         $display("insert ARITH");
                //     end
                //     `OPCODE_S:begin
                //         $display("insert S");
                //     end
                //     `OPCODE_L:begin
                //         $display("insert L");
                //     end
                //     `OPCODE_B:begin
                //         $display("insert B");
                //     end
                //     `OPCODE_ARITHI:begin
                //         $display("insert ARITHI");
                //     end
                //     `OPCODE_LUI:begin
                //         $display("insert LUI");
                //     end
                //     `OPCODE_AUIPC:begin
                //         $display("insert AUIPC");
                //     end
                //     `OPCODE_JAL:begin
                //         $display("insert JAL");
                //     end
                //     `OPCODE_JALR:begin
                //         $display("insert JALR");
                //     end
                //     default:begin
                //         $display("error inst");
                //     end
                // endcase
                //

                rob_busy[tail]<=1;
                rob_can_commit[tail]<=inst_can_commit;
                rob_opcode[tail]<=inst_opcode;
                rob_rd[tail]<=inst_rd;
                rob_pc[tail]<=inst_pc;
                rob_rd_data[tail]<=0;
                rob_is_branch[tail]<=inst_is_branch;
                rob_predict_jump[tail]<=inst_predict_is_jump;
                rob_is_jump[tail]<=0;
                rob_jump_pc[tail]<=0;
            end
            if(sz>0&&rob_can_commit[head])begin

                //debug
                // case(rob_opcode[head][`OPCODE_RANGE])
                //     `OPCODE_ARITH:begin
                //         $display("commit ARITH");
                //     end
                //     `OPCODE_S:begin
                //         $display("commit S");
                //     end
                //     `OPCODE_L:begin
                //         $display("commit L");
                //     end
                //     `OPCODE_B:begin
                //         $display("commit B");
                //     end
                //     `OPCODE_ARITHI:begin
                //         $display("commit ARITHI");
                //     end
                //     `OPCODE_LUI:begin
                //         $display("commit LUI");
                //     end
                //     `OPCODE_AUIPC:begin
                //         $display("commit AUIPC");
                //     end
                //     `OPCODE_JAL:begin
                //         $display("commit JAL");
                //     end
                //     `OPCODE_JALR:begin
                //         $display("commit JALR");
                //     end
                // endcase

                //wrong at 000000d4
                //2nd d4 is not jump,but i jump
                // cnt<=cnt+1;
                // $fwrite(file,"%h\n",rob_pc[head]);

                // $fwrite(file,"commit pc = %h %h\n",rob_pc[head],head);

                rob_busy[head]<=0;
                commit_reg_pc<=rob_pc[head];
                case(rob_opcode[head])
                    `OPCODE_S:begin
                        //to LSB
                        commit_lsb_valid<=1;
                        commit_lsb_data<=rob_rd_data[head];
                        commit_lsb_rob_id<=head;
                    end
                    `OPCODE_B:begin
                        //to ifetch
                        pc<=rob_pc[head];
                        is_jump<=rob_is_jump[head];
                        is_branch<=1;
                        if(rob_predict_jump[head]!=rob_is_jump[head])begin
                            rollback<=1;
                            pc_valid<=1;
                            jump_pc<=rob_jump_pc[head];
                        end
                    end
                    `OPCODE_JALR:begin
                        //to ifetch and regfile
                        //in ifetch JALR skip by default
                        //must rollback
                        commit_reg_valid<=1;
                        commit_reg_rd<=rob_rd[head];
                        commit_reg_data<=rob_rd_data[head];
                        commit_reg_rob_id<=head;
                        rollback<=1;
                        pc_valid<=1;
                        is_jump<=1;
                        jump_pc<=rob_jump_pc[head];
                    end
                    default:begin
                        //to regfile
                        commit_reg_valid<=1;
                        commit_reg_rd<=rob_rd[head];
                        commit_reg_data<=rob_rd_data[head];
                        commit_reg_rob_id<=head;
                    end
                endcase
            end
            if(alu_chg)begin
                rob_can_commit[alu_rob_id]<=1;
                rob_rd_data[alu_rob_id]<=alu_rob_data;
                if(rob_is_branch[alu_rob_id])begin
                    rob_is_jump[alu_rob_id]<=alu_is_jump;
                    rob_jump_pc[alu_rob_id]<=alu_jump_pc;
                end
            end
            if(lsb_chg)begin
                rob_can_commit[lsb_rob_id]<=1;
                rob_rd_data[lsb_rob_id]<=lsb_rob_data;
            end
        end
    end

endmodule
`endif