// RISCV32 CPU top module
// port modification allowed for debugging purposes

`include "const.v"
`include "ALU.v"
`include "decoder.v"
`include "ifetch.v"
`include "LSB.v"
`include "memctrl.v"
`include "regfile.v"
`include "ROB.v"
`include "RS.v"

module cpu(
  input  wire                 clk_in,			// system clock signal
  input  wire                 rst_in,			// reset signal
	input  wire					        rdy_in,			// ready signal, pause cpu when low

  input  wire [ 7:0]          mem_din,		// data input bus
  output wire [ 7:0]          mem_dout,		// data output bus
  output wire [31:0]          mem_a,			// address bus (only 17:0 is used)
  output wire                 mem_wr,			// write/read signal (1 for write)
	
	input  wire                 io_buffer_full, // 1 if uart buffer is full
	
	output wire [31:0]			dbgreg_dout		// cpu register output (debugging demo)
);

// implementation goes here

// Specifications:
// - Pause cpu(freeze pc, registers, etc.) when rdy_in is low
// - Memory read result will be returned in the next cycle. Write takes 1 cycle(no need to wait)
// - Memory is of size 128KB, with valid address ranging from 0x0 to 0x20000
// - I/O port is mapped to address higher than 0x30000 (mem_a[17:16]==2'b11)
// - 0x30000 read: read a byte from input
// - 0x30000 write: write a byte to output (write 0x00 is ignored)
// - 0x30004 read: read clocks passed since cpu starts (in dword, 4 bytes)
// - 0x30004 write: indicates program stop (will output '\0' through uart tx)

//  always @(posedge clk_in)begin
//   $display("new cycle");
//  end

//ALU output
wire ALU_out_is_data;
wire [`DATA_WID] ALU_out_data;
wire ALU_out_is_jump;
wire [`ADDR_WID] ALU_out_pc;
wire [`ROB_ID_WID] ALU_out_rob_target;

//cdecoder output
wire cdecoder_out_inst_valid;
wire [`INST_WID] cdecoder_out_inst;
wire cdecoder_out_inst_predict_jump;
wire [`ADDR_WID] cdecoder_out_inst_pc;
wire cdecoder_out_is_c_extend;

//decoder output
wire decoder_valid;
wire [`OPCODE_WID] decoder_opcode;
wire [`FUNC3_WID] decoder_func3;
wire decoder_func1;
wire decoder_rs1_valid;
wire [`REG_ID_WID] decoder_rs1;
wire decoder_rs1_depend_rob;
wire [`ROB_ID_WID] decoder_rs1_rob_id;
wire [`DATA_WID] decoder_rs1_data;
wire decoder_rs2_valid;
wire [`REG_ID_WID] decoder_rs2;
wire decoder_rs2_depend_rob;
wire [`ROB_ID_WID] decoder_rs2_rob_id;
wire [`DATA_WID] decoder_rs2_data;
wire decoder_rd_valid;
wire [`REG_ID_WID] decoder_rd;
wire [`ROB_ID_WID] decoder_rd_rob_id;
wire [`DATA_WID] decoder_imm;
wire [`DATA_WID] decoder_off;
wire [`ADDR_WID] decoder_pc;
wire decoder_is_c_extend;
wire decoder_is_branch;
wire decoder_is_predict_jump;
wire decoder_is_store;
wire decoder_can_commit;
wire decoder_is_call_rob_rs1;
wire [`ROB_ID_WID] decoder_call_rob_rs1_rob_id;
wire decoder_is_call_rob_rs2;
wire [`ROB_ID_WID] decoder_call_rob_rs2_rob_id;
wire decoder_is_call_regfile_rs1;
wire [`REG_ID_WID] decoder_call_regfile_rs1;
wire decoder_is_call_regfile_rs2;
wire [`REG_ID_WID] decoder_call_regfile_rs2;
wire [`ADDR_WID] decoder_call_regfile_pc;
wire decoder_to_rs;
wire decoder_to_lsb;

//ifetch output
wire ifetch_out_inst_valid;
wire [`INST_WID] ifetch_out_inst;
wire ifetch_out_inst_predict_jump;
wire [`ADDR_WID] ifetch_out_inst_pc;
wire ifetch_mem_find_valid;
wire [`ADDR_WID] ifetch_mem_find_addr;

//LSB output
wire lsb_full;
wire LSB_call_valid;
wire LSB_call_is_store;
wire [`ADDR_WID] LSB_call_addr;
wire [`ST_LEN_WID] LSB_call_len;
wire [`DATA_WID] LSB_call_data;
wire LSB_out_valid;
wire [`ROB_ID_WID] LSB_out_rob_id;
wire [`DATA_WID] LSB_out_data;

//memctrl output
wire memctrl_respond_valid;
wire [`DATA_WID] memctrl_respond_data;
wire memctrl_mem_data_valid;
wire [`CACHE_BLK_MAXLEN:0] memctrl_mem_data;

//regfile output
wire regfile_rs1_busy;
wire [`DATA_WID] regfile_answer_rs1_data;
wire [`ROB_ID_WID] regfile_rs1_rob_id;
wire regfile_rs2_busy;
wire [`DATA_WID] regfile_answer_rs2_data;
wire [`ROB_ID_WID] regfile_rs2_rob_id;

//ROB output
wire rollback;
wire rob_full;
wire ROB_pc_valid;
wire [`ADDR_WID] ROB_pc;
wire ROB_is_branch;
wire ROB_is_jump;
wire [`ADDR_WID] ROB_jump_pc;
wire ROB_commit_reg_valid;
wire [`REG_ID_WID] ROB_commit_reg_rd;
wire [`DATA_WID] ROB_commit_reg_data; 
wire [`ROB_ID_WID] ROB_commit_reg_rob_id;
wire [`ADDR_WID] ROB_commit_reg_pc;
wire ROB_commit_lsb_valid;
wire [`ROB_ID_WID] ROB_commit_lsb_rob_id;
wire [`DATA_WID] ROB_commit_lsb_data;
wire ROB_is_rs1_depend;
wire [`DATA_WID] ROB_rs1_data;
wire ROB_is_rs2_depend;
wire [`DATA_WID] ROB_rs2_data;
wire [`ROB_ID_WID] ROB_rd_rob_id;

//RS output
wire rs_full;
wire RS_exe_valid;
wire [`OPCODE_WID] RS_exe_opcode;
wire [`FUNC3_WID] RS_exe_func3;
wire RS_exe_func1;
wire [`DATA_WID] RS_exe_data1;
wire [`DATA_WID] RS_exe_data2;
wire [`DATA_WID] RS_exe_imm;
wire [`DATA_WID] RS_exe_off;
wire [`ADDR_WID] RS_exe_pc;
wire [`ROB_ID_WID] RS_exe_rob_target;
wire RS_is_c_extend;

ALU t_ALU(
  .clk(clk_in),
  .rdy(rdy_in),
  .rst(rst_in),
  .rollback(rollback),
  .inst_valid(RS_exe_valid),
  .opcode(RS_exe_opcode),
  .func3(RS_exe_func3),
  .func1(RS_exe_func1),
  .data1(RS_exe_data1),
  .data2(RS_exe_data2),
  .imm(RS_exe_imm),
  .off(RS_exe_off),
  .pc(RS_exe_pc),
  .rob_target(RS_exe_rob_target),
  .out_is_data(ALU_out_is_data),
  .out_data(ALU_out_data),
  .out_is_jump(ALU_out_is_jump),
  .out_pc(ALU_out_pc),
  .out_rob_target(ALU_out_rob_target),
  .is_c_extend(RS_is_c_extend)
);

cDecoder t_cDecoder(
  .rst(rst_in),
  .rdy(rdy_in),
  .clk(clk_in),
  .rollback(rollback),
  .inst_valid(ifetch_out_inst_valid),
  .inst(ifetch_out_inst),
  .inst_predict_jump(ifetch_out_inst_predict_jump),
  .inst_pc(ifetch_out_inst_pc),
  .out_inst_valid(cdecoder_out_inst_valid),
  .out_inst(cdecoder_out_inst),
  .out_inst_predict_jump(cdecoder_out_inst_predict_jump),
  .out_inst_pc(cdecoder_out_inst_pc),
  .is_c_extend(cdecoder_out_is_c_extend)
);

Decoder t_Decoder(
  .rst(rst_in),
  .rdy(rdy_in),
  .rollback(rollback),
  .inst_valid(cdecoder_out_inst_valid),
  .inst(cdecoder_out_inst),
  .inst_predict_jump(cdecoder_out_inst_predict_jump),
  .inst_pc(cdecoder_out_inst_pc),
  .inst_is_c_extend(cdecoder_out_is_c_extend),
  .valid(decoder_valid),
  .opcode(decoder_opcode),
  .func3(decoder_func3),
  .func1(decoder_func1),
  .rs1_valid(decoder_rs1_valid),
  .rs1(decoder_rs1),
  .rs1_depend_rob(decoder_rs1_depend_rob),
  .rs1_rob_id(decoder_rs1_rob_id),
  .rs1_data(decoder_rs1_data),
  .rs2_valid(decoder_rs2_valid),
  .rs2(decoder_rs2),
  .rs2_depend_rob(decoder_rs2_depend_rob),
  .rs2_rob_id(decoder_rs2_rob_id),
  .rs2_data(decoder_rs2_data),
  .rd_valid(decoder_rd_valid),
  .rd(decoder_rd),
  .rd_rob_id(decoder_rd_rob_id),
  .imm(decoder_imm),
  .off(decoder_off),
  .pc(decoder_pc),
  .is_c_extend(decoder_is_c_extend),
  .is_branch(decoder_is_branch),
  .is_predict_jump(decoder_is_predict_jump),
  .is_store(decoder_is_store),
  .can_commit(decoder_can_commit),
  .alu_data_valid(ALU_out_is_data),
  .alu_data(ALU_out_data),
  .alu_rob_id(ALU_out_rob_target),
  .lsb_data_valid(LSB_out_valid),
  .lsb_data(LSB_out_data),
  .lsb_rob_id(LSB_out_rob_id),
  .is_call_rob_rs1(decoder_is_call_rob_rs1),
  .call_rob_rs1_rob_id(decoder_call_rob_rs1_rob_id),
  .is_call_rob_rs2(decoder_is_call_rob_rs2),
  .call_rob_rs2_rob_id(decoder_call_rob_rs2_rob_id),
  .rob_is_rs1_depend(ROB_is_rs1_depend),
  .rob_rs1_data(ROB_rs1_data),
  .rob_is_rs2_depend(ROB_is_rs2_depend),
  .rob_rs2_data(ROB_rs2_data),
  .rob_rd_rob_id(ROB_rd_rob_id),
  .is_call_regfile_rs1(decoder_is_call_regfile_rs1),
  .call_regfile_rs1(decoder_call_regfile_rs1),
  .is_call_regfile_rs2(decoder_is_call_regfile_rs2),
  .call_regfile_rs2(decoder_call_regfile_rs2),
  .call_regfile_pc(decoder_call_regfile_pc),
  .regfile_rs1_data(regfile_answer_rs1_data),
  .regfile_rs1_busy(regfile_rs1_busy),
  .regfile_rs1_rob_id(regfile_rs1_rob_id),
  .regfile_rs2_data(regfile_answer_rs2_data),
  .regfile_rs2_busy(regfile_rs2_busy),
  .regfile_rs2_rob_id(regfile_rs2_rob_id),
  .to_rs(decoder_to_rs),
  .to_lsb(decoder_to_lsb)
);

IFetch t_IFetch(
  .clk(clk_in),
  .rst(rst_in),
  .rdy(rdy_in),
  .rollback(rollback),
  .rs_full(rs_full),
  .rob_full(rob_full),
  .lsb_full(lsb_full),
  .pc_valid(ROB_pc_valid),
  .pc(ROB_pc),
  .is_branch(ROB_is_branch),
  .is_jump(ROB_is_jump),
  .jump_pc(ROB_jump_pc),
  .out_inst_valid(ifetch_out_inst_valid),
  .out_inst(ifetch_out_inst),
  .out_inst_predict_jump(ifetch_out_inst_predict_jump),
  .out_inst_pc(ifetch_out_inst_pc),
  .mem_data_valid(memctrl_mem_data_valid),
  .mem_data(memctrl_mem_data),
  .mem_find_valid(ifetch_mem_find_valid),
  .mem_find_addr(ifetch_mem_find_addr)
);

LSB t_LSB(
  .clk(clk_in),
  .rst(rst_in),
  .rdy(rdy_in),
  .rollback(rollback),
  .lsb_full(lsb_full),
  .inst_valid(decoder_to_lsb),
  .opcode(decoder_opcode),
  .is_store(decoder_is_store),
  .func3(decoder_func3),
  .rs1_busy(decoder_rs1_depend_rob),
  .rs1_id(decoder_rs1),
  .rs1_data(decoder_rs1_data),
  .rs1_rob_id(decoder_rs1_rob_id),
  .rs2_busy(decoder_rs2_depend_rob),
  .rs2_id(decoder_rs2),
  .rs2_data(decoder_rs2_data),
  .rs2_rob_id(decoder_rs2_rob_id),
  .imm(decoder_imm),
  .rd_id(decoder_rd),
  .rob_target(decoder_rd_rob_id),
  .pc(decoder_pc),
  .alu_valid(ALU_out_is_data),
  .alu_rob_id(ALU_out_rob_target),
  .alu_data(ALU_out_data),
  .lsb_valid(LSB_out_valid),
  .lsb_rob_id(LSB_out_rob_id),
  .lsb_data(LSB_out_data),
  .commit_valid(ROB_commit_lsb_valid),
  .commit_rob_id(ROB_commit_lsb_rob_id),
  .commit_data(ROB_commit_lsb_data),
  .call_valid(LSB_call_valid),
  .call_is_store(LSB_call_is_store),
  .call_addr(LSB_call_addr),
  .call_len(LSB_call_len),
  .call_data(LSB_call_data),
  .respond_valid(memctrl_respond_valid),
  .respond_data(memctrl_respond_data),
  .out_valid(LSB_out_valid),
  .out_rob_id(LSB_out_rob_id),
  .out_data(LSB_out_data)
);

MemCtrl t_MemCtrl(
  .clk(clk_in),
  .rst(rst_in),
  .rdy(rdy_in),
  .rollback(rollback),
  .ret_data(mem_din),
  .call_addr(mem_a),
  .is_write(mem_wr),
  .write_data(mem_dout),
  .lsb_call_valid(LSB_call_valid),
  .lsb_call_is_store(LSB_call_is_store),
  .lsb_call_addr(LSB_call_addr),
  .lsb_call_len(LSB_call_len),
  .lsb_call_data(LSB_call_data),
  .respond_valid(memctrl_respond_valid),
  .respond_data(memctrl_respond_data),
  .mem_find_valid(ifetch_mem_find_valid),
  .mem_find_addr(ifetch_mem_find_addr),
  .io_buffer_full(io_buffer_full),
  .mem_data_valid(memctrl_mem_data_valid),
  .mem_data(memctrl_mem_data)
);

RegFile t_RegFile(
  .clk(clk_in),
  .rst(rst_in),
  .rdy(rdy_in),
  .rollback(rollback),
  .is_call_rs1(decoder_is_call_regfile_rs1),
  .call_rs1(decoder_call_regfile_rs1),
  .is_call_rs2(decoder_is_call_regfile_rs2),
  .call_rs2(decoder_call_regfile_rs2),
  .decoder_call_pc(decoder_pc),
  .rs1_busy(regfile_rs1_busy),
  .answer_rs1_data(regfile_answer_rs1_data),
  .rs1_rob_id(regfile_rs1_rob_id),
  .rs2_busy(regfile_rs2_busy),
  .answer_rs2_data(regfile_answer_rs2_data),
  .rs2_rob_id(regfile_rs2_rob_id),
  .chg_dependency(decoder_rd_valid),//maybe wrong
  .chg_rs1(decoder_rd),//maybe wrong
  .dependent_rob_id(decoder_rd_rob_id),//maybe wrong
  .chg_pc(decoder_pc),
  .is_commit(ROB_commit_reg_valid),
  .commit_rd(ROB_commit_reg_rd),
  .commit_data(ROB_commit_reg_data),
  .commit_rob_id(ROB_commit_reg_rob_id),
  .commit_pc(ROB_commit_reg_pc)
);

ROB t_ROB(
  .clk(clk_in),
  .rst(rst_in),
  .rdy(rdy_in),
  .rollback(rollback),
  .rob_full(rob_full),
  .inst_valid(decoder_valid),
  .inst_opcode(decoder_opcode),
  .inst_rd(decoder_rd),
  .inst_pc(decoder_pc),
  .inst_is_branch(decoder_is_branch),
  .inst_predict_is_jump(decoder_is_predict_jump),
  .inst_can_commit(decoder_can_commit),
  .lsb_chg(LSB_out_valid),
  .lsb_rob_id(LSB_out_rob_id),
  .lsb_rob_data(LSB_out_data),
  .alu_chg(ALU_out_is_data),
  .alu_rob_id(ALU_out_rob_target),
  .alu_rob_data(ALU_out_data),
  .alu_is_jump(ALU_out_is_jump),
  .alu_jump_pc(ALU_out_pc),
  .is_call_rs1(decoder_is_call_rob_rs1),
  .call_rs1_rob_id(decoder_call_rob_rs1_rob_id),
  .is_call_rs2(decoder_is_call_rob_rs2),
  .call_rs2_rob_id(decoder_call_rob_rs2_rob_id),
  .pc_valid(ROB_pc_valid),
  .pc(ROB_pc),
  .is_branch(ROB_is_branch),
  .is_jump(ROB_is_jump),
  .jump_pc(ROB_jump_pc),
  .commit_reg_valid(ROB_commit_reg_valid),
  .commit_reg_rd(ROB_commit_reg_rd),
  .commit_reg_data(ROB_commit_reg_data),
  .commit_reg_rob_id(ROB_commit_reg_rob_id),
  .commit_reg_pc(ROB_commit_reg_pc),
  .commit_lsb_valid(ROB_commit_lsb_valid),
  .commit_lsb_rob_id(ROB_commit_lsb_rob_id),
  .commit_lsb_data(ROB_commit_lsb_data),
  .is_rs1_depend(ROB_is_rs1_depend),
  .rs1_data(ROB_rs1_data),
  .is_rs2_depend(ROB_is_rs2_depend),
  .rs2_data(ROB_rs2_data),
  .rd_rob_id(ROB_rd_rob_id)
);

RS t_RS(
  .clk(clk_in),
  .rdy(rdy_in),
  .rst(rst_in),
  .rollback(rollback),
  .rs_full(rs_full),
  .inst_valid(decoder_to_rs),
  .inst_opcode(decoder_opcode),
  .inst_func3(decoder_func3),
  .inst_func1(decoder_func1),
  .inst_reg1_depend_rob(decoder_rs1_depend_rob),
  .inst_reg1_data(decoder_rs1_data),
  .inst_reg1_rob_id(decoder_rs1_rob_id),
  .inst_reg2_depend_rob(decoder_rs2_depend_rob),
  .inst_reg2_data(decoder_rs2_data),
  .inst_reg2_rob_id(decoder_rs2_rob_id),
  .inst_rd_rob_id(decoder_rd_rob_id),
  .inst_imm(decoder_imm),
  .inst_off(decoder_off),
  .inst_pc(decoder_pc),
  .inst_is_c_extend(decoder_is_c_extend),
  .alu_valid(ALU_out_is_data),
  .alu_rob_id(ALU_out_rob_target),
  .alu_data(ALU_out_data),
  .lsb_valid(LSB_out_valid),
  .lsb_rob_id(LSB_out_rob_id),
  .lsb_data(LSB_out_data),
  .exe_valid(RS_exe_valid),
  .exe_opcode(RS_exe_opcode),
  .exe_func3(RS_exe_func3),
  .exe_func1(RS_exe_func1),
  .exe_data1(RS_exe_data1),
  .exe_data2(RS_exe_data2),
  .exe_imm(RS_exe_imm),
  .exe_off(RS_exe_off),
  .exe_pc(RS_exe_pc),
  .exe_rob_target(RS_exe_rob_target),
  .exe_is_c_extend(RS_is_c_extend)
);

endmodule