`ifndef decoder
`define decoder
`include "const.v"

module Decoder(
    input wire rst,
    input wire rdy,
    input wire rollback,

    //ifetch to decoder
    input wire inst_valid,
    input wire [`INST_WID] inst,
    input wire inst_predict_jump,
    input wire [`ADDR_WID] inst_pc,
    input wire inst_is_c_extend,

    //decode
    output reg valid,
    output reg [`OPCODE_WID] opcode,
    output reg [`FUNC3_WID] func3,
    output reg func1,
    output reg rs1_valid,
    output reg [`REG_ID_WID] rs1,
    output reg rs1_depend_rob,
    output reg [`ROB_ID_WID] rs1_rob_id,
    output reg [`DATA_WID] rs1_data,
    output reg rs2_valid,
    output reg [`REG_ID_WID] rs2,
    output reg rs2_depend_rob,
    output reg [`ROB_ID_WID] rs2_rob_id,
    output reg [`DATA_WID] rs2_data,
    output reg rd_valid,
    output reg [`REG_ID_WID] rd,
    output reg [`ROB_ID_WID] rd_rob_id,
    output reg [`DATA_WID] imm,
    output reg [`DATA_WID] off,
    output reg [`ADDR_WID] pc,
    output reg is_branch,
    output reg is_predict_jump,
    output reg is_store,
    output reg can_commit,
    output reg is_c_extend,

    //ALU provide register information
    input wire alu_data_valid,
    input wire [`DATA_WID] alu_data,
    input wire [`ROB_ID_WID] alu_rob_id,

    //LSB provide register information
    input wire lsb_data_valid,
    input wire [`DATA_WID] lsb_data,
    input wire [`ROB_ID_WID] lsb_rob_id,

    //output wire -> answer instantly
    //decoder call ROB dependencies
    output wire is_call_rob_rs1,
    output wire [`ROB_ID_WID] call_rob_rs1_rob_id,
    output wire is_call_rob_rs2,
    output wire [`ROB_ID_WID] call_rob_rs2_rob_id,

    //ROB answer decoder call
    input wire rob_is_rs1_depend,
    input wire [`DATA_WID] rob_rs1_data,
    input wire rob_is_rs2_depend,
    input wire [`DATA_WID] rob_rs2_data,
    input wire [`ROB_ID_WID] rob_rd_rob_id,

    //output wire -> answer instantly
    //decoder call regfile
    output wire is_call_regfile_rs1,
    output wire [`REG_ID_WID] call_regfile_rs1,
    output wire is_call_regfile_rs2,
    output wire [`REG_ID_WID] call_regfile_rs2,
    output wire [`ADDR_WID] call_regfile_pc,

    //regfile answer decoder
    input wire [`DATA_WID] regfile_rs1_data,
    input wire regfile_rs1_busy,
    input wire [`ROB_ID_WID] regfile_rs1_rob_id,
    input wire [`DATA_WID] regfile_rs2_data,
    input wire regfile_rs2_busy,
    input wire [`ROB_ID_WID] regfile_rs2_rob_id,

    //to RS
    output reg to_rs,

    //to LSB
    output reg to_lsb
);
    //call regfile instantly
    assign is_call_regfile_rs1=(valid&&(opcode==`OPCODE_ARITH||opcode==`OPCODE_S||opcode==`OPCODE_B||opcode==`OPCODE_ARITHI||opcode==`OPCODE_L))?1:0;
    assign is_call_regfile_rs2=(valid&&(opcode==`OPCODE_ARITH||opcode==`OPCODE_S||opcode==`OPCODE_B))?1:0;
    assign call_regfile_rs1=inst[`RS1_RANGE];
    assign call_regfile_rs2=inst[`RS2_RANGE];
    assign call_regfile_pc=inst_pc;

    //call ROB instantly
    assign is_call_rob_rs1=(valid&&(opcode==`OPCODE_ARITH||opcode==`OPCODE_S||opcode==`OPCODE_B||opcode==`OPCODE_ARITHI||opcode==`OPCODE_L))?1:0;
    assign is_call_rob_rs2=(valid&&(opcode==`OPCODE_ARITH||opcode==`OPCODE_S||opcode==`OPCODE_B))?1:0;
    assign call_rob_rs1_rob_id=regfile_rs1_rob_id;
    assign call_rob_rs2_rob_id=regfile_rs2_rob_id;

    always @(*)begin
        valid=0;
        opcode=inst[`OPCODE_RANGE];
        func3=inst[`FUNC3_RANGE];
        func1=inst[`FUNC1_RANGE];
        is_predict_jump=inst_predict_jump;
        pc=inst_pc;
        rd_rob_id=rob_rd_rob_id;
        is_c_extend=inst_is_c_extend;
        rs1_depend_rob=0;
        rs2_depend_rob=0;
        to_rs=0;
        to_lsb=0;
        can_commit=0;
        is_store=0;
        rd_valid=0;
        rs1_valid=0;
        rs2_valid=0;
        rs1=0;
        rs2=0;
        rs1_rob_id=0;
        rs2_rob_id=0;
        rs1_data=0;
        rs2_data=0;
        rd=0;
        off=0;
        imm=0;
        is_branch=0;
        if(!rst&&rdy&&!rollback&&inst_valid)begin
            valid=1;
            // debug
            // case(inst[`OPCODE_RANGE])
            //     `OPCODE_ARITH:begin
            //         $display("decode ARITH %d",rd_rob_id);
            //     end
            //     `OPCODE_S:begin
            //         $display("decode S %d",rd_rob_id);
            //     end
            //     `OPCODE_L:begin
            //         $display("decode L %d",rd_rob_id);
            //     end
            //     `OPCODE_B:begin
            //         $display("decode B %d",rd_rob_id);
            //     end
            //     `OPCODE_ARITHI:begin
            //         $display("decode ARITHI %d",rd_rob_id);
            //     end
            //     `OPCODE_LUI:begin
            //         $display("decode LUI %d",rd_rob_id);
            //     end
            //     `OPCODE_AUIPC:begin
            //         $display("decode AUIPC %d",rd_rob_id);
            //     end
            //     `OPCODE_JAL:begin
            //         $display("decode JAL %d",rd_rob_id);
            //     end
            //     `OPCODE_JALR:begin
            //         $display("decode JALR %d",rd_rob_id);
            //     end
            // endcase
            //
            case(inst[`OPCODE_RANGE])
                `OPCODE_S:begin
                    is_store=1;
                    can_commit=1;
                end
                default:begin
                    is_store=0;
                end
            endcase
            case(inst[`OPCODE_RANGE])
                `OPCODE_ARITH,`OPCODE_S,`OPCODE_B,`OPCODE_ARITHI,`OPCODE_L,`OPCODE_JALR:begin
                    rs1_valid=1;
                    rs1=inst[`RS1_RANGE];
                    rs1_depend_rob=regfile_rs1_busy;
                    rs1_rob_id=regfile_rs1_rob_id;
                end
                default:begin
                    rs1_valid=0;
                    rs1=0;
                    rs1_depend_rob=0;
                    rs1_rob_id=0;
                end
            endcase
            case(inst[`OPCODE_RANGE])
                `OPCODE_ARITH,`OPCODE_S,`OPCODE_B:begin
                    rs2_valid=1;
                    rs2=inst[`RS2_RANGE];
                    rs2_depend_rob=regfile_rs2_busy;
                    rs2_rob_id=regfile_rs2_rob_id;
                end
                default:begin
                    rs2_valid=0;
                    rs2=0;
                    rs2_depend_rob=0;
                    rs2_rob_id=0;
                end
            endcase
            case(inst[`OPCODE_RANGE])
                `OPCODE_S,`OPCODE_B:begin
                    rd_valid=0;
                    rd=0;
                end
                default:begin
                    rd_valid=1;
                    rd=inst[`RD_RANGE];
                end
            endcase
            if(!rs1_depend_rob)begin
                rs1_data=regfile_rs1_data;
            end else if(rob_is_rs1_depend)begin
                rs1_data=rob_rs1_data;
                rs1_depend_rob=0;
            end else if(alu_data_valid&&alu_rob_id==regfile_rs1_rob_id)begin
                rs1_data=alu_data;
                rs1_depend_rob=0;
            end else if(lsb_data_valid&&lsb_rob_id==regfile_rs1_rob_id)begin
                rs1_data=lsb_data;
                rs1_depend_rob=0;
            end else begin
                rs1_data=0;
                rs1_rob_id=regfile_rs1_rob_id;
            end
            if(!rs2_depend_rob)begin
                rs2_data=regfile_rs2_data;
            end else if(rob_is_rs2_depend)begin
                rs2_data=rob_rs2_data;
                rs2_depend_rob=0;
            end else if(alu_data_valid&&alu_rob_id==regfile_rs2_rob_id)begin
                rs2_data=alu_data;
                rs2_depend_rob=0;
            end else if(lsb_data_valid&&lsb_rob_id==regfile_rs2_rob_id)begin
                rs2_data=lsb_data;
                rs2_depend_rob=0;
            end else begin
                rs2_data=0;
                rs2_rob_id=regfile_rs2_rob_id;
            end
            // if(inst[`OPCODE_RANGE]==`OPCODE_S)begin
            //     $display("%h",inst_pc);
            //     $display("decode %b %h %h %b %h %h",rs1_depend_rob,rs1_data,rs1_rob_id,rs2_depend_rob,rs2_data,rs2_rob_id);
            // end
            case(inst[`OPCODE_RANGE])
                `OPCODE_LUI,`OPCODE_AUIPC:begin
                    imm=inst[31:12];
                end
                `OPCODE_JAL:begin
                    off={inst[31],inst[19:12],inst[20],inst[30:21],1'b0};
                end
                `OPCODE_JALR,`OPCODE_ARITHI:begin
                    imm={{20{inst[31]}},inst[31:20]};
                end
                `OPCODE_B:begin
                    off={{19{inst[31]}},inst[31],inst[7],inst[30:25],inst[11:8],1'b0};
                end
                `OPCODE_L:begin
                    imm={{20{inst[31]}},inst[31:20]};
                end
                `OPCODE_S:begin
                    imm={{20{inst[31]}},inst[31:25],inst[11:7]};
                end
            endcase
            case(inst[`OPCODE_RANGE])
                `OPCODE_JAL,`OPCODE_B,`OPCODE_JALR:begin
                    is_branch=1;
                end
                default:begin
                    is_branch=0;
                end
            endcase
            case(inst[`OPCODE_RANGE])
                `OPCODE_S,`OPCODE_L:begin
                    to_lsb=1;
                    to_rs=0;
                end
                default:begin
                    to_rs=1;
                    to_lsb=0;
                    // if(pc==1176)begin
                    //     $display("%b %h %h",rs1_depend_rob,rs1_data,rs1_rob_id);
                    // end
                end
            endcase
        end
    end
endmodule
`endif