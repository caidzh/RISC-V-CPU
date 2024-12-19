`ifndef memctrl
`define memctrl
`include "const.v"

module MemCtrl{
    input wire clk,
    input wire rst,
    input wire rdy,
    input wire rollback,

    //
    input  wire [ 7:0] mem_in,
    output reg  [ 7:0] mem_out,
    output reg  [31:0] mem_addr,			
    output reg         mem_rw,
}

endmodule
`endif