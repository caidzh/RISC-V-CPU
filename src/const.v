`ifndef const
`define const 

// CPU
// MAXLEN
`define CACHE_BLK_MAXLEN 511
`define LSB_TOP 5'd16

// SZ
`define RS_SZ 16
`define ROB_SZ 8
`define REG_SZ 32
`define LSB_SZ 16
`define CACHE_BLK_SZ 512
`define CACHE_BLK_NUM_SZ 16
`define BP_BLK_NUM_SZ 256
`define INST_SZ 4

// WID
`define INST_WID 31:0
`define DATA_WID 31:0
`define ADDR_WID 31:0
`define ROB_ID_WID 2:0
`define RS_ID_WID 3:0
`define REG_ID_WID 4:0
`define LSB_ID_WID 3:0
`define ST_LEN_WID 2:0
`define BLK_NUM_WID 3:0
`define BLK_DATA_WID 5:0
`define MEMCTRL_STATUS_WID 1:0
`define CACHE_TAG_WID 21:0
`define CACHE_INDEX_WID 3:0
`define BP_INDEX_WID 7:0
`define CACHE_BLK_SZ_WID 8:0
`define CACHE_OFF_WID 3:0
`define MEMORY_RW_WID 7:0

// RANGE
`define CACHE_TAG_RANGE 31:10
`define CACHE_INDEX_RANGE 9:6
`define CACHE_OFF_RANGE 5:2
`define BP_INDEX_RANGE 9:2

// RISC-V
`define OPCODE_WID 6:0
`define OPCODE_RANGE 6:0
`define FUNC3_WID 2:0
`define RD_RANGE 11:7
`define FUNC3_RANGE 14:12
`define RS1_RANGE 19:15
`define RS2_RANGE 24:20
`define FUNC1_RANGE 30

`define OPCODE_L      7'b0000011
`define OPCODE_S      7'b0100011
`define OPCODE_ARITHI 7'b0010011
`define OPCODE_ARITH  7'b0110011
`define OPCODE_LUI    7'b0110111
`define OPCODE_AUIPC  7'b0010111
`define OPCODE_JAL    7'b1101111
`define OPCODE_JALR   7'b1100111
`define OPCODE_B      7'b1100011

`define FUNC3_ADD  3'h0
`define FUNC3_SUB  3'h0
`define FUNC3_XOR  3'h4
`define FUNC3_OR   3'h6
`define FUNC3_AND  3'h7
`define FUNC3_SLL  3'h1
`define FUNC3_SRL  3'h5
`define FUNC3_SRA  3'h5
`define FUNC3_SLT  3'h2
`define FUNC3_SLTU 3'h3

`define FUNC1_ADD 1'b0
`define FUNC1_SUB 1'b1
`define FUNC1_SRL 1'b0
`define FUNC1_SRA 1'b1

`define FUNC3_ADDI  3'h0
`define FUNC3_XORI  3'h4
`define FUNC3_ORI   3'h6
`define FUNC3_ANDI  3'h7
`define FUNC3_SLLI  3'h1
`define FUNC3_SRLI  3'h5
`define FUNC3_SRAI  3'h5
`define FUNC3_SLTI  3'h2
`define FUNC3_SLTUI 3'h3

`define FUNC1_SRLI 1'b0
`define FUNC1_SRAI 1'b1

`define FUNC3_LB  3'h0
`define FUNC3_LH  3'h1
`define FUNC3_LW  3'h2
`define FUNC3_LBU 3'h4
`define FUNC3_LHU 3'h5

`define FUNC3_SB 3'h0
`define FUNC3_SH 3'h1
`define FUNC3_SW 3'h2

`define FUNC3_BEQ  3'h0
`define FUNC3_BNE  3'h1
`define FUNC3_BLT  3'h4
`define FUNC3_BGE  3'h5
`define FUNC3_BLTU 3'h6
`define FUNC3_BGEU 3'h7

// RISC-VC
`define C_OP_RANGE 1:0
`define C_FUNC3_RANGE 15:13

`endif