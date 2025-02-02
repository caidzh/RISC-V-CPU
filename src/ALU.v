`ifndef ALU
`define ALU
`include "const.v"

module ALU(
    input wire clk,
    input wire rdy,
    input wire rst,
    input wire rollback,

    //RS to ALU
    input wire inst_valid,
    input wire [`OPCODE_WID] opcode,
    input wire [`FUNC3_WID] func3,
    input wire func1,
    input wire [`DATA_WID] data1,
    input wire [`DATA_WID] data2,
    input wire [`DATA_WID] imm,
    input wire [`DATA_WID] off,
    input wire [`ADDR_WID] pc,
    input wire [`ROB_ID_WID] rob_target,
    input wire is_c_extend,
    
    output reg out_is_data,
    output reg [`DATA_WID] out_data,
    output reg out_is_jump,
    output reg [`ADDR_WID] out_pc,
    output reg [`ROB_ID_WID] out_rob_target
);
    wire [`DATA_WID] operand1=data1;
    wire [`DATA_WID] operand2=(opcode==`OPCODE_ARITHI)?imm:data2;

    reg [`DATA_WID] data;
    reg is_jump;

    always @(*)begin
        if(opcode==`OPCODE_ARITH||opcode==`OPCODE_ARITHI)begin
            is_jump=0;
            case(func3)
                `FUNC3_ADD:data=(func1&&opcode==`OPCODE_ARITH)?operand1-operand2:operand1+operand2;
                `FUNC3_XOR:data=operand1^operand2;
                `FUNC3_OR:data=operand1|operand2;
                `FUNC3_AND:data=operand1&operand2;
                `FUNC3_SLL:data=operand1<<operand2;
                `FUNC3_SRL:data=func1?$signed(operand1)>>operand2[5:0]:operand1>>operand2[5:0];
                `FUNC3_SLT:data=$signed(operand1)<$signed(operand2);
                `FUNC3_SLTU:data=operand1<operand2;
            endcase
        end else begin
            data=0;
            case(func3)
                `FUNC3_BEQ:is_jump=operand1==operand2;
                `FUNC3_BNE:is_jump=operand1!=operand2;
                `FUNC3_BLT:is_jump=$signed(operand1)<$signed(operand2);
                `FUNC3_BGE:is_jump=$signed(operand1)>=$signed(operand2);
                `FUNC3_BLTU:is_jump=operand1<operand2;
                `FUNC3_BGEU:is_jump=operand1>=operand2;
                default:is_jump=0;
            endcase
        end
    end

    always @(posedge clk)begin
        if(rst||rollback)begin
            // $display("ALU rollback");
            out_is_data<=0;
            out_data<=0;
            out_is_jump<=0;
            out_pc<=0;
            out_rob_target<=0;
        end else if(rdy)begin
            out_is_data<=0;
            out_is_jump<=0;
            if(inst_valid)begin
                out_is_data<=1;
                out_rob_target<=rob_target;
                case(opcode)
                    `OPCODE_ARITH,`OPCODE_ARITHI:begin
                        out_data<=data;
                    end
                    `OPCODE_AUIPC:begin
                        out_is_jump<=1;
                        out_data<=pc+(imm<<12);
                    end
                    `OPCODE_LUI:begin
                        out_is_jump<=1;
                        out_data<=(imm<<12);
                    end
                    `OPCODE_B:begin
                        out_is_jump<=is_jump;
                        if(!is_c_extend)
                            out_pc<=is_jump?pc+off:pc+4;
                        else
                            out_pc<=is_jump?pc+off:pc+2;
                    end
                    `OPCODE_JAL:begin
                        if(!is_c_extend)
                            out_data<=pc+4;
                        else
                            out_data<=pc+2;
                        out_is_jump<=1;
                        out_pc<=pc+off;
                    end
                    `OPCODE_JALR:begin 
                        if(!is_c_extend)
                            out_data<=pc+4;
                        else
                            out_data<=pc+2;
                        out_is_jump<=1;
                        out_pc<=(data1+imm)&(~1);
                    end
                endcase
                
            end
            // $display("ALU broadcast %h %h",rob_target,out_data);
        end
    end

endmodule
`endif