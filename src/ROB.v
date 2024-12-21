`ifndef ROB
`define ROB
`include "const.v"

module ROB{
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

    //ROB update LSB
    output reg commit_lsb_valid,
    output reg [`ROB_ID_WID] commit_lsb_rob_id,
    output reg [`DATA_WID] commit_lsb_data,

    //ROB answer decoder call
    output wire is_rs1_depend,
    output wire [`DATA_WID] rs1_data,
    output wire is_rs2_depend,
    output wire [`DATA_WID] rs2_data
    output wire [`ROB_POS_WID] rd_rob_id,
};

    reg [`ROB_ID_WID] head;
    reg [`ROB_ID_WID] tail;
    reg [`ROB_ID_WID] sz;

    reg [`ROB_ID_WID] nxt_head;
    reg [`ROB_ID_WID] nxt_tail;
    reg [`ROB_ID_WID] nxt_sz;

    reg rob_busy[`ROB_SZ-1:0];
    reg rob_can_commit[`ROB_SZ-1:0];
    reg [`OPCODE_WID] rob_opcode[`ROB_SZ-1:0];
    reg [`REG_ID_WID] rob_rd[`ROB_SZ-1:0];
    reg [`ADDR_WID] rob_pc[`ROB_SZ-1:0];
    reg [`DATA_WID] rob_rd_data[`ROB_SZ-1:0];
    reg rob_predict_jump[`ROB_SZ-1:0];//predict
    reg rob_is_jump[`ROB_SZ-1:0];//real
    reg [`ADDR_WID] rob_jump_pc[`ROB_SZ-1:0];//real jump pc

    integer i;

    //ROB queue
    always @(*)begin
        nxt_head=head+(rob_can_commit[head]&&sz>0);
        nxt_tail=tail+inst_valid;
        nxt_sz=sz;
        if(rob_can_commit[head]&&sz>0)
            nxt_sz=nxt_sz-1;
        if(inst_valid)
            nxt_sz=nxt_sz+1;
        rob_full=(nxt_head==nxt_tail&&nxt_sz>0);
    end

    //answer decoder call after any update
    always @(*)begin
        if(is_call_rs1)begin
            if(busy[call_rs1_rob_id])begin
                is_rs1_depend=rob_can_commit[call_rs1_rob_id];
                rs1_data=rob_rd_data[call_rs1_rob_id];
            end else begin
                is_rs1_depend=0;
            end
        end
        if(is_call_rs2)begin
            if(busy[call_rs2_rob_id])begin
                is_rs2_depend=rob_can_commit[call_rs2_rob_id];
                rs2_data=rob_rd_data[call_rs2_rob_id];
            end else begin
                is_rs2_depend=0;
            end
        end
        rd_rob_id=tail;
    end

    always @(posedge clk)begin
        if(rst)begin
            for(i=0;i<`ROB_SZ;i=i+1)begin
                rob_busy[i]<=0;
                head<=0;
                tail<=0;
                nxt_head<=0;
                nxt_tail<=0;
                sz<=0;
            end
        end else if(rdy)begin
            head<=nxt_head;
            tail<=nxt_tail;
            sz<=nxt_sz;
            commit_reg_valid<=0;
            commit_lsb_valid<=0;
            pc_valid<=0;
            if(inst_valid)begin
                rob_busy[tail]<=1;
                rob_can_commit[tail]<=inst_can_commit;
                rob_opcode[tail]<=inst_opcode;
                rob_rd[tail]<=inst_rd;
                rob_pc[tail]<=inst_pc;
                rob_rd_data[tail]<=0;
                rob_predict_jump[tail]<=inst_predict_is_jump;
                rob_is_jump[tail]<=0;
                rob_jump_pc[tail]<=0;
            end
            if(sz>0&&rob_can_commit[head])begin
                case(rob_opcode[head])
                    `OPCODE_S:begin
                        //to LSB
                        commit_lsb_valid<=1;
                        commit_lsb_data<=rob_rd_data[head];
                        commit_lsb_rob_id<=head;
                    end
                    `OPCODE_B:begin
                        //to ifetch
                        pc_valid<=1;
                        pc<=rob_pc[head];
                        is_branch<=1;
                        if(rob_predict_jump[head]!=rob_is_jump[head])begin
                            rollback<=1;
                            is_jump<=rob_is_jump[head];
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