`ifndef decoder
`define decoder
`include "const.v"

module Decoder{
    input wire rst,
    input wire rdy,
    input wire rollback,

    //ifetch to decoder
    input wire inst_valid,
    input wire [`INST_WID] inst,
    input wire inst_predict_jump,
    input wire [`ADDR_WID] inst_pc,

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
    output reg is_predict_jump,
    output reg is_store,
    output reg can_commit,

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
};

    //call regfile instantly
    always @(*)begin
        is_call_regfile_rs1=0;
        is_call_regfile_rs2=0;
        if(valid)begin
            case(opcode)
                `OPCODE_ARITH,`OPCODE_S,`OPCODE_B:begin
                    is_call_regfile_rs1=1;
                    call_regfile_rs1=inst[`RS1_RANGE];
                    is_call_regfile_rs2=1;
                    call_regfile_rs2=inst[`RS2_RANGE];
                end
                `OPCODE_ARITHI,`OPCDOE_L:begin
                    is_call_regfile_rs1=1;
                    call_regfile_rs1=inst[`RS1_RANGE];
                end
            endcase
        end
    end

    //call ROB instantly
    always @(*)begin
        is_call_rob_rs1=0;
        is_call_rob_rs2=0;
        if(valid)begin
            case(opcode)
                `OPCODE_ARITH,`OPCODE_S,`OPCODE_B:begin
                    is_call_rob_rs1=1;
                    call_rob_rs1_rob_id=regfile_rs1_rob_id;
                    is_call_rob_rs2=1;
                    call_rob_rs2_rob_id=regfile_rs2_rob_id;
                end
                `OPCODE_ARITHI,`OPCDOE_L:begin
                    is_call_rob_rs1=1;
                    call_rob_rs1_rob_id=regfile_rs1_rob_id;
                end
            endcase
        end
    end

    always @(*)begin
        valid=0;
        if(!rst&&rdy&&!rollback&&inst_valid)begin
            valid=1;
            opcode=inst[`OPCODE_RANGE];
            func3=inst[`FUNC3_RANGE];
            func1=inst[`FUNC1_RANGE];
            is_predict_jump=inst_predict_jump;
            pc=inst_pc;
            case(inst[`OPCODE_RANGE])
                `OPCODE_S:begin
                    is_store=1;
                end
                default:begin
                    is_store=0;
                end
            endcase
            case(inst[`OPCODE_RANGE])
                `OPCODE_ARITH,`OPCODE_S,`OPCODE_B,`OPCODE_ARITHI,`OPCDOE_L:begin
                    rs1_valid=1;
                    rs1=inst[`RS1_RANGE];
                    rs1_depend_rob=regfile_rs1_busy;
                    rs1_rob_id=regfile_rs1_rob_id;
                end
                default:begin
                    rs1_valid=0;
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
                end
            endcase
            case(inst[`OPCODE_RANGE])
                `OPCODE_S,`OPCODE_B:begin
                    rd_valid=0;
                end
                default:begin
                    rd_valid=1;
                    rd=inst[`RD_RANGE];
                    rd_rob_id=rob_rd_rob_id;
                end
            endcase
            if(!rs1_depend_rob)begin
                rs1_data=regfile_rs1_data;
            end else if(!rob_is_rs1_depend)begin
                rs1_data=rob_rs1_data;
                rs1_depend_rob=0;
            end else if(alu_data_valid&&alu_rob_id==regfile_rs1_rob_id)begin
                rs1_data=alu_data;
                rs1_depend_rob=0;
            end else if(lsb_data_valid&&lsb_rob_id==regfile_rs1_rob_id)begin
                rs1_data=lsb_data;
                rs1_depend_rob=0;
            end
            if(!rs2_depend_rob)begin
                rs2_data=regfile_rs2_data;
            end else if(!rob_is_rs2_depend)begin
                rs2_data=rob_rs2_data;
                rs2_depend_rob=0;
            end else if(alu_data_valid&&alu_rob_id==regfile_rs2_rob_id)begin
                rs2_data=alu_data;
                rs2_depend_rob=0;
            end else if(lsb_data_valid&&lsb_rob_id==regfile_rs2_rob_id)begin
                rs2_data=lsb_data;
                rs2_depend_rob=0;
            end
            case(inst[`OPCODE_RANGE])
                `OPCODE_LUI,`OPCODE_AUIPC:begin
                    imm={inst[31:12],12'b0};
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
                `OPCODE_S,`OPCODE_L:begin
                    to_lsb=1;
                    to_rs=0;
                end
                default:begin
                    to_rs=1;
                    to_lsb=0;
                end
            endcase
        end
    end
endmodule
`endif