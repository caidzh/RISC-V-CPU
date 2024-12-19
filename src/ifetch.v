`ifndef ifetch
`define ifetch
`include "const.v"

module IFetch{
    input wire clk,
    input wire rst,
    input wire rdy,
    input wire rollback,

    //ready
    input wire rs_full;
    input wire rob_full;
    input wire lsb_full;

    //ROB call ifetch change pc
    input wire pc_valid;
    input wire [`ADDR_WID] pc;
    input wire is_branch;
    input wire is_jump;
    input wire [`ADDR_WID] jump_pc;

    //to decoder
    output reg out_inst_valid;
    output reg [`INST_WID] out_inst;
    output reg out_inst_predict_jump;
    output reg [`ADDR_WID] out_inst_pc;

    //to Memory
    input wire mem_data_valid;
    input wire [`DATA_WID] mem_data;
    output reg mem_find_valid;
    output reg [`ADDR_WID] mem_find_addr;
}
    localparam IDLE=0,IFetch=1,LOAD=2,STORE=3;
    reg [`IFETCH_STATUS_WID] status;
    reg [`ADDR_WID] pc;

    //iCache
    //tag [31:10]
    //index [9:6] -> 16 blocks
    //pc with same tag and index share the same block
    //offset [5:0] 64 bytes per block
    //instruction -> 4 bytes -> 16 instructions per block
    reg busy[`BLK_NUM_WID];
    reg [`BLK_TAG_WID] blk_tag[`CACHE_BLK_NUM_SZ-1:0];
    reg [`CACHE_BLK_SZ_WID] blk_data[`CACHE_BLK_NUM_SZ-1:0];
    wire [`CACHE_INDEX_WID] pc_index;
    wire [`CACHE_TAG_WID] pc_tag;
    wire hit;
    wire [`BP_INDEX_WID] bp_index;

    always @(*)begin
        pc_tag=pc[`CACHE_TAG_RANGE];
        pc_index=pc[`CACHE_INDEX_RANGE];
        bp_index=pc[`BP_INDEX_RANGE];
        hit=(busy[pc_index]&&blk_tag[pc_index]==pc_tag);
    end

    //Branch Predictor
    //index [9:2] -> 256 blocks
    //pc with same index share the same result of branch predict
    //method : if instructions in one block jumped more than 2 times -> jump
    reg [2:0] tracker[`BP_BLK_NUM_SZ-1:0];

    integer i;

    always @(posedge clk)begin
        if(rst)begin
            pc<=0;
            status<=IDLE;
            out_inst_valid<=0;
            out_inst_predict_jump<=0;
            mem_find_valid<=0;
            for(i=0;i<`BP_BLK_NUM_SZ;i=i+1)begin
                tracker[i]<=0;
            end
            for(i=0;i<`CACHE_BLK_NUM_SZ;i=i+1)begin
                busy[i]<=0;
            end
        end else if(rdy)begin
            //update branch history
            if(is_branch)begin
                if(is_jump)begin

                end

            end
            //whether jump or not

            //transport instruction to decoder

            //fetch instruction to memory
        end
    end

endmodule
`endif