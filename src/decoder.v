`ifndef decoder
`define decoder
`include "const.v"

module Decoder{
    input wire rdy,
    input wire rst,
    input wire rollback,

    

}
    always @(posedge clk)begin
        if(rst||rollback)begin
            
        end else begin

        end
    end
endmodule
`endif