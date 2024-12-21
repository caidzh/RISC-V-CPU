`ifndef LSB
`define LSB
`include "const.v"

module LSB{
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
    output wire call_valid,
    output wire call_is_store,
    output wire [`ADDR_WID] call_addr,
    output wire [`ST_LEN_WID] call_len,
    output wire [`DATA_WID] call_data,
    
    //MemCtrl respond
    input wire respond_valid,
    input wire [`DATA_WID] respond_data,

    //LSB out (load)
    output wire out_valid,
    output wire [`ROB_ID_WID] out_rob_id,
    output wire [`DATA_WID] out_data
};
    localparam IDLE=0,WAIT=1;
    reg status;

    reg [`LSB_ID_WID] head;
    reg [`LSB_ID_WID] tail;
    reg [`LSB_ID_WID] sz;

    reg [`LSB_ID_WID] nxt_head;
    reg [`LSB_ID_WID] nxt_tail;
    reg [`LSB_ID_WID] nxt_sz;

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
    reg executed[`LSB_SZ-1:0];

    integer i;

    wire head_can_executed;
    wire is_responded;

    always @(*)begin
        head_can_executed=(!is_empty&&!lsb_rs1_busy[head]&&!lsb_rs2_busy[head]&&executed[head]);
        nxt_head=head+(status==WAIT&&respond_valid);
        nxt_tail=tail+inst_valid;
        nxt_sz=sz;
        if(is_responded)begin
            nxt_sz=nxt_sz-1;
        end
        if(inst_valid)begin
            nxt_sz=nxt_sz+1;
        end
        lsb_full=(head==tail)&&(nxt_sz!=0);
    end

    always @(posedge clk)begin
        head<=nxt_head;
        tail<=nxt_tail;
        sz<=nxt_sz;
        out_valid<=0;
        if(rst||rollback)begin
            status<=IDLE;
            head<=0;
            tail<=0;
            sz<=0;
            is_empty<=1;
            call_valid<=0;
            out_valid<=0;
            lsb_full<=0;
            for(i=0;i<`LSB_SZ;i=i+1)begin
                busy[i]<=0;
            end
        end else if(rdy)begin
            //LSB call MemCtrl
            //LSB out (load)
            //MemCtrl respond
            if(status==IDLE)begin
                call_valid<=0;
                if(head_can_executed)begin
                    status<=WAIT;
                    call_valid<=1;
                    call_is_store<=lsb_is_store[head];
                    call_addr<=call;
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
                    if(!lsb_is_store[head])begin
                        out_valid<=1;
                        out_rob_id<=lsb_rob_target[head];
                        case(lsb_func3[head])
                            `FUNC3_LB:out_data<={{24{respond_data[7]}},respond_data[7:0]};
                            `FUNC3_LBU:out_data<={24'b0, respond_data[7:0]};
                            `FUNC3_LH:out_data<={{16{respond_data[15]}},respond_data[15:0]};
                            `FUNC3_LHU:out_data<={16'b0, respond_data[15:0]};
                            `FUNC3_LW:out_data<=respond_data; 
                        endcase
                    end
                end
            end
            //ROB update LSB
            if(commit_valid)begin
                for(i=0;i<`LSB_SZ;i=i+1)begin
                    if(busy[i]&&!executed[i]&&lsb_rob_id[i]==commit_rob_id)begin
                        execute[i]<=1;
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
            //decoder to LSB
            if(inst_valid)begin
                busy[tail]<=1;
                lsb_opcode[tail]<=opcode;
                lsb_is_store[tail]<=is_store;
                lsb_func3[tail]<=func3;
                lsb_rs1_busy[tail]<=rs1_busy;
                lsb_rs1_data[tail]<=rs1_data;
                lsb_rs1_rob_id[tail]<=rs1_rob_id;
                lsb_rs2_busy[tail]<=rs2_busy;
                lsb_rs2_data[tail]<=rs2_data;
                lsb_rs2_rob_id[tail]<=rs2_rob_id;
                lsb_imm[tail]<=imm;
                lsb_rd_id[tail]<=rd_id;
                lsb_rob_target<=rob_target;
            end
        end
    end

endmodule
`endif