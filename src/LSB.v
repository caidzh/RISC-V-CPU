`ifndef LSB
`define LSB
`include "const.v"

module LSB(
    input wire clk,
    input wire rst,
    input wire rdy,
    input wire rollback,

    output reg lsb_full,

    //decoder to LSB
    input wire inst_valid,
    input wire [`OPCODE_WID] opcode,
    input wire is_store,
    input wire [`FUNC3_WID] func3,
    input wire rs1_busy,
    input wire [`REG_ID_WID] rs1_id,
    input wire [`DATA_WID] rs1_data,
    input wire [`ROB_ID_WID] rs1_rob_id,
    input wire rs2_busy,
    input wire [`REG_ID_WID] rs2_id,
    input wire [`DATA_WID] rs2_data,
    input wire [`ROB_ID_WID] rs2_rob_id,
    input wire [`DATA_WID] imm,
    input wire [`REG_ID_WID] rd_id,
    input wire [`ROB_ID_WID] rob_target,
    input wire [`ADDR_WID] pc,

    //ALU update LSB
    input wire alu_valid,
    input wire [`ROB_ID_WID] alu_rob_id,
    input wire [`DATA_WID] alu_data,

    //LSB update LSB
    input wire lsb_valid,
    input wire [`ROB_ID_WID] lsb_rob_id,
    input wire [`DATA_WID] lsb_data,

    //ROB update LSB
    input wire commit_valid,
    input wire [`ROB_ID_WID] commit_rob_id,
    input wire [`DATA_WID] commit_data,

    //LSB call MemCtrl
    output reg call_valid,
    output reg call_is_store,
    output reg [`ADDR_WID] call_addr,
    output reg [`ST_LEN_WID] call_len,
    output reg [`DATA_WID] call_data,
    
    //MemCtrl respond
    input wire respond_valid,
    input wire [`DATA_WID] respond_data,

    //LSB out (load)
    output reg out_valid,
    output reg [`ROB_ID_WID] out_rob_id,
    output reg [`DATA_WID] out_data
);
    localparam IDLE=0,WAIT=1;
    reg status;

    reg [`LSB_ID_WID] head;
    reg [`LSB_ID_WID] tail;
    reg [4:0] execute_pointer;
    reg [4:0] empty;

    reg [`LSB_ID_WID] nxt_head;
    reg [`LSB_ID_WID] nxt_tail;
    reg [4:0] nxt_empty;

    //LSB information
    reg busy[`LSB_SZ-1:0];
    reg [`OPCODE_WID] lsb_opcode[`LSB_SZ-1:0];
    reg lsb_is_store[`LSB_SZ-1:0];
    reg [`FUNC3_WID] lsb_func3[`LSB_SZ-1:0];
    reg lsb_rs1_busy[`LSB_SZ-1:0];
    reg [`REG_ID_WID] lsb_rs1_id[`LSB_SZ-1:0];
    reg [`DATA_WID] lsb_rs1_data[`LSB_SZ-1:0];
    reg [`ROB_ID_WID] lsb_rs1_rob_id[`LSB_SZ-1:0];
    reg lsb_rs2_busy[`LSB_SZ-1:0];
    reg [`REG_ID_WID] lsb_rs2_id[`LSB_SZ-1:0];
    reg [`DATA_WID] lsb_rs2_data[`LSB_SZ-1:0];
    reg [`ROB_ID_WID] lsb_rs2_rob_id[`LSB_SZ-1:0];
    reg [`DATA_WID] lsb_imm[`LSB_SZ-1:0];
    reg [`REG_ID_WID] lsb_rd_id[`LSB_SZ-1:0];
    reg [`ROB_ID_WID] lsb_rob_target[`LSB_SZ-1:0];
    reg [`ADDR_WID] lsb_pc[`LSB_SZ-1:0];
    reg executed[`LSB_SZ-1:0];

    integer i;

    wire head_can_executed;

    wire [`DATA_WID] head_addr=rs1_data[head]+imm[head];

    assign head_can_executed=(!empty&&!lsb_rs1_busy[head]&&!lsb_rs2_busy[head]&&(executed[head]||(!lsb_is_store[head]&&!rollback&&head_addr[17:16]!=2'b11)));

    always @(*)begin
        nxt_head=head+(status==WAIT&&respond_valid);
        nxt_tail=tail+inst_valid;
        nxt_empty=(nxt_head==nxt_tail)&&(empty||((status==WAIT&&respond_valid)&&!inst_valid));
        lsb_full=(nxt_head==nxt_tail)&&!nxt_empty;
    end

    // integer file;
    // initial begin
    //     file=$fopen("LSB.txt", "w");
    // end

    always @(posedge clk)begin
        head<=nxt_head;
        tail<=nxt_tail;
        empty<=nxt_empty;
        out_valid<=0;
        if(rst||(rollback&&execute_pointer==`LSB_TOP))begin
            // $display("LSB rollback");
            status<=IDLE;
            head<=0;
            tail<=0;
            empty<=1;
            call_valid<=0;
            out_valid<=0;
            execute_pointer<=`LSB_TOP;
            for(i=0;i<`LSB_SZ;i=i+1)begin
                busy[i]<=0;
                lsb_opcode[i]<=0;
                lsb_is_store[i]<=0;
                lsb_func3[i]<=0;
                lsb_rs1_busy[i]<=0;
                lsb_rs1_id[i]<=0;
                lsb_rs1_data[i]<=0;
                lsb_rs1_rob_id[i]<=0;
                lsb_rs2_busy[i]<=0;
                lsb_rs2_id[i]<=0;
                lsb_rs2_data[i]<=0;
                lsb_rs2_rob_id[i]<=0;
                lsb_imm[i]<=0;
                lsb_rd_id[i]<=0;
                lsb_rob_target[i]<=0;
                executed[i]<=0;
            end
        end else if(rollback)begin
            // $display("LSB rollback");
            tail<=execute_pointer+1;
            for(i=0;i<`LSB_SZ;i=i+1)begin
                if(!executed[i])
                    busy[i]<=0;
            end
            // $fwrite(file,"rollback\n");
            if(status==WAIT&&respond_valid)begin
                status<=IDLE;
                call_valid<=0;
                busy[head]<=0;
                executed[head]<=0;
                if(execute_pointer[`LSB_ID_WID]==head)begin
                    execute_pointer<=`LSB_TOP;
                    empty<=1;
                end
            end
        end else if(rdy)begin
            //LSB call MemCtrl
            //LSB out (load)
            //MemCtrl respond
            // if(!empty)begin
            //     $fwrite(file,"LSB ------\n");
            //     $fwrite(file,"head=%d tail=%d empty=%d\n",head,tail,empty);
            //     for(i=0;i<`LSB_SZ;i=i+1)begin
            //         if(busy[i])begin
            //             $fwrite(file,"%h %b %h %h\n",i,lsb_opcode[i],lsb_rd_id[i],lsb_pc[i]);
            //         end
            //     end
            //     $fwrite(file,"------\n");
            // end
            //decoder to LSB
            if(inst_valid)begin
                busy[tail]<=1;
                lsb_opcode[tail]<=opcode;
                lsb_is_store[tail]<=is_store;
                lsb_func3[tail]<=func3;
                lsb_rs1_busy[tail]<=rs1_busy;
                lsb_rs1_id[tail]<=rs1_id;
                lsb_rs1_data[tail]<=rs1_data;
                lsb_rs1_rob_id[tail]<=rs1_rob_id;
                lsb_rs2_busy[tail]<=rs2_busy;
                lsb_rs2_id[tail]<=rs2_id;
                lsb_rs2_data[tail]<=rs2_data;
                lsb_rs2_rob_id[tail]<=rs2_rob_id;
                lsb_imm[tail]<=imm;
                lsb_rd_id[tail]<=rd_id;
                lsb_rob_target[tail]<=rob_target;
                lsb_pc[tail]<=pc;
                executed[tail]<=0;
                // if(is_store)
                //     $display("insert %h %h %h %h %h %h",rs1_busy,rs1_id,rs1_rob_id,rs2_busy,rs2_id,rs2_rob_id);
            end
            if(status==IDLE)begin
                call_valid<=0;
                if(head_can_executed)begin
                    status<=WAIT;
                    call_valid<=1;
                    call_is_store<=lsb_is_store[head];
                    call_addr<=lsb_rs1_data[head]+lsb_imm[head];
                    // $fwrite(file,"%h execute %b %h->%h\n",lsb_pc[head],lsb_is_store[head],lsb_rs1_data[head]+lsb_imm[head],lsb_rs2_data[head]);
                    case(lsb_func3[head])
                        `FUNC3_LB,`FUNC3_LBU:call_len<=1;
                        `FUNC3_LH,`FUNC3_LHU:call_len<=2;
                        `FUNC3_LW:call_len<=4;
                    endcase
                    if(lsb_is_store[head])
                        call_data<=lsb_rs2_data[head];
                end
            end else begin
                if(respond_valid)begin
                    status<=IDLE;
                    call_valid<=0;
                    busy[head]<=0;
                    executed[head]<=0;
                    if(execute_pointer=={1'b0,head})
                        execute_pointer<=`LSB_TOP;
                    if(!lsb_is_store[head])begin
                        // $fwrite(file,"execute done %h\n",lsb_pc[head]);
                        out_valid<=1;
                        out_rob_id<=lsb_rob_target[head];
                        case(lsb_func3[head])
                            `FUNC3_LB:begin
                                out_data<={{24{respond_data[7]}},respond_data[7:0]};
                                // $fwrite(file,"respond %h\n",{{24{respond_data[7]}},respond_data[7:0]});
                            end
                            `FUNC3_LBU:begin
                                out_data<={24'b0,respond_data[7:0]};
                                // $fwrite(file,"respond %h\n",{24'b0,respond_data[7:0]});
                            end
                            `FUNC3_LH:begin
                                out_data<={{16{respond_data[15]}},respond_data[15:0]};
                                // $fwrite(file,"respond %h\n",{{16{respond_data[15]}}});
                            end
                            `FUNC3_LHU:begin
                                out_data<={16'b0,respond_data[15:0]};
                                // $fwrite(file,"respond %h\n",{16'b0,respond_data[15:0]});
                            end
                            `FUNC3_LW:begin
                                out_data<=respond_data;
                                // $fwrite(file,"respond %h\n",respond_data); 
                            end
                        endcase

                    end
                end
            end
            //ROB update LSB
            if(commit_valid)begin
                for(i=0;i<`LSB_SZ;i=i+1)begin
                    if(busy[i]&&!executed[i]&&lsb_rob_target[i]==commit_rob_id)begin
                        executed[i]<=1;
                        execute_pointer<={1'b0,i[`LSB_ID_WID]};
                    end
                end
            end
            //ALU update LSB
            if(alu_valid)begin
                for(i=0;i<`LSB_SZ;i=i+1)begin
                    if(busy[i]&&lsb_rs1_busy[i]&&lsb_rs1_rob_id[i]==alu_rob_id)begin
                        lsb_rs1_data[i]<=alu_data;
                        lsb_rs1_busy[i]<=0;
                    end
                    if(busy[i]&&lsb_rs2_busy[i]&&lsb_rs2_rob_id[i]==alu_rob_id)begin
                        lsb_rs2_data[i]<=alu_data;
                        lsb_rs2_busy[i]<=0;
                    end
                end
            end
            //LSB update LSB
            if(lsb_valid)begin
                for(i=0;i<`LSB_SZ;i=i+1)begin
                    if(busy[i]&&lsb_rs1_busy[i]&&lsb_rs1_rob_id[i]==lsb_rob_id)begin
                        lsb_rs1_data[i]<=lsb_data;
                        lsb_rs1_busy[i]<=0;
                    end
                    if(busy[i]&&lsb_rs2_busy[i]&&lsb_rs2_rob_id[i]==lsb_rob_id)begin
                        lsb_rs2_data[i]<=lsb_data;
                        lsb_rs2_busy[i]<=0;
                    end
                end
            end 
        end
    end

endmodule
`endif