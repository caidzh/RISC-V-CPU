`ifndef cdecoder
`define cdecoder
`include "const.v"

module cDecoder(
    input wire rst,
    input wire rdy,
    input wire clk,
    input wire rollback,

    //ifetch to cdecoder
    input wire inst_valid,
    input wire [`INST_WID] inst,
    input wire inst_predict_jump,
    input wire [`ADDR_WID] inst_pc,

    //to decoder
    output reg out_inst_valid,
    output reg [`INST_WID] out_inst,
    output reg out_inst_predict_jump,
    output reg [`ADDR_WID] out_inst_pc,
    output reg is_c_extend
);

    reg [`REG_ID_WID] rs1;
    reg [`REG_ID_WID] rs2;
    reg [`REG_ID_WID] rd;
    reg [`DATA_WID] imm;
    always @(*)begin
        // decode
        rs1=0;
        rs2=0;
        rd=0;
        imm=0;
        if(inst_valid&&inst[`C_OP_RANGE]!=2'b11)begin
            // add(ok)
            if(inst[15:12]==4'b1001&&inst[`C_OP_RANGE]==2'b10)begin
                rs1=inst[11:7];
                rs2=inst[6:2];
                rd=inst[11:7];
            end
            // addi(ok)
            if(inst[`C_FUNC3_RANGE]==3'b000&&inst[`C_OP_RANGE]==2'b01)begin
                rs1=inst[11:7];
                rd=inst[11:7];
                imm={inst[12],inst[6:2]};
            end
            // arith except add(ok)
            if(inst[15:10]==6'b100011&&inst[`C_OP_RANGE]==2'b01)begin
                rs1=inst[9:7]+8;
                rs2=inst[4:2]+8;
                rd=inst[9:7]+8;
            end
            // jr(ok)
            if(inst[`C_FUNC3_RANGE]==3'b100&&inst[12]==0&&inst[11:7]!=0&&inst[6:2]==0&&inst[`C_OP_RANGE]==2'b10)begin
                rs1=inst[11:7];
                rd=0;
                imm=0;
            end
            // mv(ok)
            if(inst[`C_FUNC3_RANGE]==3'b100&&inst[12]==0&&inst[6:2]!=0&&inst[`C_OP_RANGE]==2'b10)begin
                rs1=inst[6:2];
                rd=inst[11:7];
                imm=0;
            end
            // jalr
            if(inst[`C_FUNC3_RANGE]==3'b100&&inst[12]==1&&inst[6:2]==0&&inst[`C_OP_RANGE]==2'b10)begin
                rs1=inst[11:7];
                rd=1;
                imm=0;
            end
            // swsp(ok)
            if(inst[`C_FUNC3_RANGE]==3'b110&&inst[`C_OP_RANGE]==2'b10)begin
                rs1=2;
                rs2=inst[6:2];
                imm={inst[8:7],inst[12:9],2'b00};//*
            end
            // li(ok)
            if(inst[`C_FUNC3_RANGE]==3'b010&&inst[`C_OP_RANGE]==2'b01)begin
                rs1=0;
                rd=inst[11:7];
                imm={inst[12],inst[6:2]};//*
            end
            // addi16sp(ok)
            if(inst[`C_FUNC3_RANGE]==3'b011&&inst[`C_OP_RANGE]==2'b01&&inst[11:7]==2)begin
                rs1=2;
                rd=2;
                imm={inst[12],inst[4:3],inst[5],inst[2],inst[6],4'b0000};//*
            end
            // lui
            if(inst[`C_FUNC3_RANGE]==3'b011&&inst[`C_OP_RANGE]==2'b01&&inst[11:7]!=2)begin
                rd=inst[11:7];
                imm={inst[12],inst[6:2],12'b0};
            end
            // srli
            if(inst[`C_FUNC3_RANGE]==3'b100&&inst[`C_OP_RANGE]==2'b01&&inst[11:10]==2'b00)begin
                rs1=inst[9:7]+8;
                rd=inst[9:7]+8;
                imm={inst[12],inst[6:2]};
            end
            // srai
            if(inst[`C_FUNC3_RANGE]==3'b100&&inst[`C_OP_RANGE]==2'b01&&inst[11:10]==2'b01)begin
                rs1=inst[9:7]+8;
                rd=inst[9:7]+8;
                imm={inst[12],inst[6:2]};
            end
            // andi
            if(inst[`C_FUNC3_RANGE]==3'b100&&inst[`C_OP_RANGE]==2'b01&&inst[11:10]==2'b10)begin
                rs1=inst[9:7]+8;
                rd=inst[9:7]+8;
                imm={inst[12],inst[6:2]};
            end
            // slli(ok)
            if(inst[`C_FUNC3_RANGE]==3'b000&&inst[`C_OP_RANGE]==2'b10)begin
                rs1=inst[11:7];
                rd=inst[11:7];
                imm={inst[12],inst[6:2]};
            end
            // lwsp(ok)
            if(inst[`C_FUNC3_RANGE]==3'b010&&inst[`C_OP_RANGE]==2'b10)begin
                rs1=2;
                rd=inst[11:7];
                imm={inst[3:2],inst[12],inst[6:4],2'b00};
            end
            // addi4spn(ok)
            if(inst[`C_FUNC3_RANGE]==3'b000&&inst[`C_OP_RANGE]==2'b00)begin
                rs1=2;
                rd=inst[4:2]+8;
                imm={inst[10:7],inst[12:11],inst[5],inst[6],2'b00};//*
            end
            // lw(ok)
            if(inst[`C_FUNC3_RANGE]==3'b010&&inst[`C_OP_RANGE]==2'b00)begin
                rs1=inst[9:7]+8;
                rd=inst[4:2]+8;
                imm={inst[5],inst[12:10],inst[6],2'b00};//*
            end
            // sw(ok)
            if(inst[`C_FUNC3_RANGE]==3'b110&&inst[`C_OP_RANGE]==2'b00)begin
                //04e7a023
                //c3b8 1100 0011 1001 1000
                //sw	a4,64(a5)
                //rs1'=7,rs2'=6
                rs1=inst[9:7]+8;
                rs2=inst[4:2]+8;
                imm={inst[5],inst[12:10],inst[6],2'b00};//*
            end
            // beqz(ok)
            if(inst[`C_FUNC3_RANGE]==3'b110&&inst[`C_OP_RANGE]==2'b01)begin
                rs1=inst[9:7]+8;
                rs2=0;
                imm={inst[12],inst[6:5],inst[2],inst[11:10],inst[4:3],1'b0};//*
            end
            // bnez(ok)
            if(inst[`C_FUNC3_RANGE]==3'b111&&inst[`C_OP_RANGE]==2'b01)begin
                rs1=inst[9:7]+8;
                rs2=0;
                imm={inst[12],inst[6:5],inst[2],inst[11:10],inst[4:3],1'b0};//*
            end
            // jal(ok)
            if(inst[`C_FUNC3_RANGE]==3'b001&&inst[`C_OP_RANGE]==2'b01)begin
                rd=1;
                imm={inst[12],inst[8],inst[10:9],inst[6],inst[7],inst[2],inst[11],inst[5:3],1'b0};//*
            end
            // j(ok)
            if(inst[`C_FUNC3_RANGE]==3'b101&&inst[`C_OP_RANGE]==2'b01)begin
                rd=0;
                imm={inst[12],inst[8],inst[10:9],inst[6],inst[7],inst[2],inst[11],inst[5:3],1'b0};//*
            end
        end
    end

    // integer file;
    // initial begin
    //     file=$fopen("cdecoder.txt", "w");
    // end

    always @(*)begin
        out_inst_valid=0;
        out_inst_predict_jump=0;
        out_inst_pc=0;
        out_inst=0;
        is_c_extend=0;
        if(!rst&&rdy&&!rollback&&inst_valid)begin
            out_inst_valid=inst_valid;
            out_inst_predict_jump=inst_predict_jump;
            out_inst_pc=inst_pc;
            if(inst[`C_OP_RANGE]==2'b11)begin
                // $fwrite(file,"no need to encode %h %h\n",inst,inst_pc);
                // $fwrite(file,"%h\n",inst);
                is_c_extend=0;
                out_inst=inst;
            end else begin
                is_c_extend=1;
                out_inst=0;
                // $fwrite(file,"decode and encode %h %h\n",inst[15:0],inst_pc);
                // encode
                // add(ok)
                if(inst[15:12]==4'b1001&&inst[`C_OP_RANGE]==2'b10)begin
                    //add
                    // $fwrite(file,"add\n");
                    out_inst={7'b0,rs2,rs1,`FUNC3_ADD,rd,`OPCODE_ARITH};
                    // $fwrite(file,"%h\n",{7'b0,rs2,rs1,`FUNC3_ADD,rd,`OPCODE_ARITH});
                end
                // addi
                if(inst[`C_FUNC3_RANGE]==3'b000&&inst[`C_OP_RANGE]==2'b01)begin
                    // $fwrite(file,"addi\n");
                    out_inst={{7{imm[5]}},imm[4:0],rs1,`FUNC3_ADD,rd,`OPCODE_ARITHI};
                    //00040d13
                    // $fwrite(file,"%h\n",{{7{imm[5]}},imm[4:0],rs1,`FUNC3_ADD,rd,`OPCODE_ARITHI});
                end
                // arith except add(ok)
                if(inst[15:10]==6'b100011&&inst[`C_OP_RANGE]==2'b01)begin
                    //sub/xor/or/and
                    // $fwrite(file,"arith except add\n");
                    //40d70733
                    case(inst[6:5])
                        2'b00:begin
                            out_inst={7'b0100000,rs2,rs1,`FUNC3_SUB,rd,`OPCODE_ARITH};
                            // $fwrite(file,"%h\n",{7'b0100000,rs2,rs1,`FUNC3_SUB,rd,`OPCODE_ARITH});
                        end
                        2'b01:begin
                            out_inst={7'b0,rs2,rs1,`FUNC3_XOR,rd,`OPCODE_ARITH};
                            // $fwrite(file,"%h\n",{7'b0,rs2,rs1,`FUNC3_XOR,rd,`OPCODE_ARITH});
                        end
                        2'b10:begin
                            out_inst={7'b0,rs2,rs1,`FUNC3_OR,rd,`OPCODE_ARITH};
                            // $fwrite(file,"%h\n",{7'b0,rs2,rs1,`FUNC3_OR,rd,`OPCODE_ARITH});
                        end
                        2'b11:begin
                            out_inst={7'b0,rs2,rs1,`FUNC3_AND,rd,`OPCODE_ARITH};
                            // $fwrite(file,"%h\n",{7'b0,rs2,rs1,`FUNC3_AND,rd,`OPCODE_ARITH});
                        end
                    endcase
                end
                // jr(ok)
                if(inst[`C_FUNC3_RANGE]==3'b100&&inst[12]==0&&inst[11:7]!=0&&inst[6:2]==0&&inst[`C_OP_RANGE]==2'b10)begin
                    //jalr
                    // $fwrite(file,"jr\n");
                    out_inst={imm[11:0],rs1,3'b000,rd,`OPCODE_JALR};
                    // $fwrite(file,"%h\n",{imm[11:0],rs1,3'b000,rd,`OPCODE_JALR});
                end
                // mv(ok)
                if(inst[`C_FUNC3_RANGE]==3'b100&&inst[12]==0&&inst[6:2]!=0&&inst[`C_OP_RANGE]==2'b10)begin
                    //addi
                    // $fwrite(file,"mv\n");
                    out_inst={11'b0,rs1,`FUNC3_ADD,rd,`OPCODE_ARITHI};
                    // $fwrite(file,"%h\n",{7'b0,rs2,rs1,`FUNC3_ADD,rd,`OPCODE_ARITHI});
                end
                // jalr(ok)
                if(inst[`C_FUNC3_RANGE]==3'b100&&inst[12]==1&&inst[6:2]==0&&inst[`C_OP_RANGE]==2'b10)begin
                    //jalr
                    // $fwrite(file,"jalr\n");
                    out_inst={imm[11:0],rs1,3'b000,rd,`OPCODE_JALR};
                    // $fwrite(file,"%h\n",{imm[11:0],rs1,3'b000,rd,`OPCODE_JALR});
                end
                // swsp
                if(inst[`C_FUNC3_RANGE]==3'b110&&inst[`C_OP_RANGE]==2'b10)begin
                    //sw
                    // $fwrite(file,"swsp\n");
                    out_inst={imm[11:5],rs2,rs1,3'b010,imm[4:0],`OPCODE_S};//unsigned
                    // $fwrite(file,"%h\n",{imm[11:5],rs2,rs1,3'b010,imm[4:0],`OPCODE_S});
                end
                // li(ok)
                if(inst[`C_FUNC3_RANGE]==3'b010&&inst[`C_OP_RANGE]==2'b01)begin
                    //addi
                    // $fwrite(file,"li\n");
                    out_inst={{6{imm[5]}},imm[5:0],rs1,3'b000,rd,`OPCODE_ARITHI};//sext
                    // $fwrite(file,"%h\n",{{6{imm[5]}},imm[5:0],rs1,3'b000,rd,`OPCODE_ARITHI});
                end
                // addi16sp(ok)
                if(inst[`C_FUNC3_RANGE]==3'b011&&inst[`C_OP_RANGE]==2'b01&&inst[11:7]==2)begin
                    //addi
                    // $fwrite(file,"addi16sp\n");
                    out_inst={{2{imm[9]}},imm[9:0],rs1,3'b000,rd,`OPCODE_ARITHI};//sext
                    // $fwrite(file,"%h\n",{{2{imm[9]}},imm[9:0],rs1,3'b000,rd,`OPCODE_ARITHI});
                end
                // lui(ok)
                if(inst[`C_FUNC3_RANGE]==3'b011&&inst[`C_OP_RANGE]==2'b01&&inst[11:7]!=2)begin
                    //lui
                    // $fwrite(file,"lui\n");
                    out_inst={{14{imm[17]}},imm[17:12],rd,`OPCODE_LUI};//sext
                    // $fwrite(file,"%h\n",{{14{imm[17]}},imm[17:12],rd,`OPCODE_LUI});
                end
                // srli
                if(inst[`C_FUNC3_RANGE]==3'b100&&inst[`C_OP_RANGE]==2'b01&&inst[11:10]==2'b00)begin
                    //srli
                    // $fwrite(file,"srli\n");
                    out_inst={7'b0,imm[4:0],rs1,3'b101,rd,`OPCODE_ARITHI};//unsigned
                    // $fwrite(file,"%h\n",{7'b0,imm[4:0],rs1,3'b101,rd,`OPCODE_ARITHI});
                end
                // srai
                if(inst[`C_FUNC3_RANGE]==3'b100&&inst[`C_OP_RANGE]==2'b01&&inst[11:10]==2'b01)begin
                    //srai
                    // $fwrite(file,"srai\n");
                    out_inst={7'b0100000,imm[4:0],rs1,3'b101,rd,`OPCODE_ARITHI};//unsigned
                    // $fwrite(file,"%h\n",{7'b0100000,imm[4:0],rs1,3'b101,rd,`OPCODE_ARITHI});
                end
                // andi(ok)
                if(inst[`C_FUNC3_RANGE]==3'b100&&inst[`C_OP_RANGE]==2'b01&&inst[11:10]==2'b10)begin
                    //andi
                    // $fwrite(file,"andi\n");
                    out_inst={{6{imm[5]}},imm[5:0],rs1,3'b111,rd,`OPCODE_ARITHI};//sext
                    // $fwrite(file,"%h\n",{{6{imm[5]}},imm[5:0],rs1,3'b111,rd,`OPCODE_ARITHI});
                end
                // slli
                if(inst[`C_FUNC3_RANGE]==3'b000&&inst[`C_OP_RANGE]==2'b10)begin
                    // $fwrite(file,"slli\n");
                    out_inst={7'b0,imm[4:0],rs1,3'b001,rd,`OPCODE_ARITHI};//unsigned
                    // $fwrite(file,"%h\n",{7'b0,imm[4:0],rs1,3'b001,rd,`OPCODE_ARITHI});
                end
                // lwsp
                if(inst[`C_FUNC3_RANGE]==3'b010&&inst[`C_OP_RANGE]==2'b10)begin
                    //lw
                    // $fwrite(file,"lwsp\n");
                    //04c12083
                    out_inst={imm[11:0],rs1,3'b010,rd,`OPCODE_L};//unsigned
                    // $fwrite(file,"%h\n",{imm[11:0],rs1,3'b010,rd,`OPCODE_L});
                end
                // addi4spn(ok)
                if(inst[`C_FUNC3_RANGE]==3'b000&&inst[`C_OP_RANGE]==2'b00)begin
                    //addi
                    // $fwrite(file,"addi4spn\n");
                    //02010793
                    out_inst={{3{imm[9]}},imm[8:0],rs1,3'b000,rd,`OPCODE_ARITHI};//sext
                    // $fwrite(file,"%h\n",{{3{imm[9]}},imm[8:0],rs1,3'b000,rd,`OPCODE_ARITHI});
                end
                // lw
                if(inst[`C_FUNC3_RANGE]==3'b010&&inst[`C_OP_RANGE]==2'b00)begin
                    //lw
                    // $fwrite(file,"lw\n");
                    out_inst={imm[11:0],rs1,3'b010,rd,`OPCODE_L};//unsigned
                    // $fwrite(file,"%h\n",{imm[11:0],rs1,3'b010,rd,`OPCODE_L});
                end
                // sw
                if(inst[`C_FUNC3_RANGE]==3'b110&&inst[`C_OP_RANGE]==2'b00)begin
                    //sw
                    // $fwrite(file,"sw\n");
                    //0007a403
                    out_inst={imm[11:5],rs2,rs1,3'b010,imm[4:0],`OPCODE_S};//unsigned
                    // $fwrite(file,"%h\n",{imm[11:5],rs2,rs1,3'b010,imm[4:0],`OPCODE_S});
                end
                // beqz
                if(inst[`C_FUNC3_RANGE]==3'b110&&inst[`C_OP_RANGE]==2'b01)begin
                    //beq
                    // $fwrite(file,"beqz\n");
                    out_inst={{4{imm[8]}},imm[7:5],rs2,rs1,3'b0,imm[4:1],imm[8],`OPCODE_B};//sext
                    // $fwrite(file,"%h\n",{{4{imm[8]}},imm[7:5],rs2,rs1,3'b0,imm[4:1],imm[8],`OPCODE_B});
                end
                // bnez(ok)
                if(inst[`C_FUNC3_RANGE]==3'b111&&inst[`C_OP_RANGE]==2'b01)begin
                    //bne
                    // $fwrite(file,"bnez\n");
                    out_inst={{4{imm[8]}},imm[7:5],rs2,rs1,3'b001,imm[4:1],imm[8],`OPCODE_B};//sext
                    // $fwrite(file,"%h\n",{{4{imm[8]}},imm[7:5],rs2,rs1,3'b001,imm[4:1],imm[8],`OPCODE_B});
                end
                // jal(ok)
                if(inst[`C_FUNC3_RANGE]==3'b001&&inst[`C_OP_RANGE]==2'b01)begin
                    //jal
                    // $fwrite(file,"jal\n");
                    out_inst={imm[11],imm[10:1],imm[11],{8{imm[11]}},rd,`OPCODE_JAL};//sext
                    // $fwrite(file,"%h\n",{imm[11],imm[10:1],imm[11],{8{imm[11]}},rd,`OPCODE_JAL});
                end
                // j(ok)
                if(inst[`C_FUNC3_RANGE]==3'b101&&inst[`C_OP_RANGE]==2'b01)begin
                    //jal
                    // $fwrite(file,"j\n");
                    out_inst={imm[11],imm[10:1],imm[11],{8{imm[11]}},rd,`OPCODE_JAL};//sext
                    // $fwrite(file,"%h\n",{imm[11],imm[10:1],imm[11],{8{imm[11]}},rd,`OPCODE_JAL});
                end 
            end
        end
    end

endmodule
`endif

//CR: c.add | c.sub | c.xor | c.or | c.and | c.jr | c.mv | c.jalr
//CSS: c.swsp
//CI: c.li | c.addi16sp | c.lui | c.srli | c.srai | c.andi | c.addi | c.slli | c.lwsp
//CIW: c.addi4spn
//CL: c.lw
//CS: c.sw
//CB: c.beqz | c.bnez
//CJ: c.jal | c.j

// CR
// funct4(15:12) | rd/rs1(11:7) | rs2(6:2) | op(1:0)
// c.add rd rs2 = add rd rd rs2 (funct4=1001,op=10)

// c.sub rd' rs2' = sub rd rd rs2 (inst[15:10]=100011,rd'=inst[9:7],inst[6:5]=00,rs2'=(4:2),rd=rd'+8,rs2=rs2'+8,op=01)
// c.xor rd' rs2' = xor rd rd rs2 (inst[15:10]=100011,rd'=inst[9:7],inst[6:5]=01,rs2'=(4:2),rd=rd'+8,rs2=rs2'+8,op=01)
// c.or rd' rs2' = or rd rd rs2 (inst[15:10]=100011,rd'=inst[9:7],inst[6:5]=10,rs2'=(4:2),rd=rd'+8,rs2=rs2'+8,op=01)
// c.and rd' rs2' = and rd rd rs2 (inst[15:10]=100011,rd'=inst[9:7],inst[6:5]=11,rs2'=(4:2),rd=rd'+8,rs2=rs2'+8,op=01)

// c.jr rs1 = jalr x0 rs1 0 (inst[15:13]=100,inst[12]=0,rs1=inst[11:7]!=0,inst[6:2]=00000,op=10)
// c.mv rd rs2 = add rd rs2 x0 (inst[15:13]=100,inst[12]=0,rd=inst[11:7],rs2=inst[6:2]!=0,op=10)
// c.jalr rs1 = jalr x1 rs1 0 (inst[15:13]=100,inst[12]=1,rs1=inst[11:7],inst[6:2]=00000,op=10) x1=pc+2

// CSS
// funct3(15:13) | imm(12:7) | rs2(6:2) | op(1:0)
// c.swsp rs2 uimm = sw rs2 x2 uimm (funct3=110,op=10,uimm[5:2|7:6]=inst[12:7])

// CI
// funct3(15:13) | imm(12) | rd/rs1(11:7) | imm(6:2) | op(1:0)
// c.li rd imm = addi rd x0 imm (funct3=010,op=01,imm[5]=inst[12],imm[4:0]=inst(6:2))

// c.addi16sp x0 imm = addi x2 x2 imm*16 (rd=x2,funct3=011,op=01,imm[9]=inst(12),imm[4|6|8:7|5]=inst(6:2))
// c.lui rd imm = lui rd imm (rd!=x2,funct3=011,op=01,imm[17]=inst(12),imm[16:12]=inst(6:2))

// c.slli rd uimm = slli rd rd uimm (funct3=000,op=10,uimm[5]=inst(12),uimm[4:0]=inst(6:2))
// c.lwsp rd uimm = lw rd x2 uimm (funct3=010,op=10,uimm[5]=inst(12),uimm[4:2|7:6]=inst(6:2))

// CIW
// funct3(15:13) | imm(12:5) | rd'(4:2) | op(1:0)
// c.addi4spn rd' uimm = addi rd x2 uimm*4 (funct3=000,uimm[5:4|9:6|2|3]=inst(12:5)!=0,rd=rd'+8,op=00)

// CL
// funct3(15:13) | imm(12:10) | rs1'(9:7) | imm(6:5) | rd'(4:2) | op(1:0)
// c.lw rd' rs1' uimm = lw rd rs1 uimm (funct3=010,rd=rd'+8,rs1=rs1'+8,uimm[5:3]=inst(12:10),uimm[2|6]=inst(6:5),op=00)

// CS
// funct3(15:13) | imm(12:10) | rs1'(9:7) | imm(6:5) | rs2'(4:2) | op(1:0)
// c.sw rs1' rs2' imm = sw rs1 rs2 imm*4 (funct3=110,rs1=rs1'+8,rs2=rs2'+8,uimm[5:3]=inst(12:10),uimm[2|6]=inst(6:5),op=00)

// CB
// funct3(15:13) | offset(12:10) | rs1'(9:7) | offset(6:2) | op(1:0)
// c.beqz rs1' offset = beq rs1 x0 offset*2 (funct3=110,op=01)
// c.bnez rs1' offset = bne rs1 x0 offset*2 (funct3=111,op=01)
// offset[8|4:3]=offset(12:10),offset[7:6|2:1|5]=offset(6:2),rs1=rs1'+8

// c.srli rd' uimm = srli rd rd uimm (funct3=100,op=01,inst(11:10)=00,rd'=inst(9:7),uimm[5]=inst(12),uimm[4:0]=inst(6:2),rd=rd'+8)
// c.srai rd' uimm =  srai rd rd uimm (funct3=100,op=01,inst(11:10)=01,rd'=inst(9:7),uimm[5]=inst(12),uimm[4:0]=inst(6:2),rd=rd'+8)
// c.andi rd' imm = andi rd rd imm (funct3=100,op=01,inst(11:10)=10,rd'=inst(9:7),imm[5]=inst(12),imm[4:0]=inst(6:2),rd=rd'+8)

// CJ
// funct3(15:13) | jump_target(12:2) | op(1:0)
// c.jal offset = jal x1 offset*2 (funct3=001,op=01,offset[11|4|9:8|10|6|7|3:1|5]=inst[12:2]) x1=pc+2
// c.j imm = jal x0 imm*2 (funct3=101,op=01,offset[11|4|9:8|10|6|7|3:1|5]=inst[12:2])