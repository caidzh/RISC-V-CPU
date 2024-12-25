`ifndef ifetch
`define ifetch
`include "const.v"

module IFetch(
    input wire clk,
    input wire rst,
    input wire rdy,
    input wire rollback,

    //ready
    input wire rs_full,
    input wire rob_full,
    input wire lsb_full,

    //ROB call ifetch change pc
    input wire pc_valid,
    input wire [`ADDR_WID] pc,
    input wire is_branch,
    input wire is_jump,
    input wire [`ADDR_WID] jump_pc,

    //to decoder
    output reg out_inst_valid,
    output reg [`INST_WID] out_inst,
    output reg out_inst_predict_jump,
    output reg [`ADDR_WID] out_inst_pc,

    //to memctrl
    input wire mem_data_valid,
    input wire [`CACHE_BLK_MAXLEN:0] mem_data,
    output reg mem_find_valid,
    output reg [`ADDR_WID] mem_find_addr
);
    localparam IDLE=0,IFetch=1;
    reg status;
    reg [`ADDR_WID] ifetch_pc;

    //iCache
    //tag [31:10]
    //index [9:6] -> 16 blocks
    //pc with same tag and index share the same block
    //offset [5:0] 64 bytes per block
    //instruction -> 4 bytes -> 16 instructions per block
    reg busy[`CACHE_BLK_NUM_SZ-1:0];
    reg [`CACHE_TAG_WID] blk_tag[`CACHE_BLK_NUM_SZ-1:0];
    reg [`CACHE_BLK_MAXLEN:0] blk_data[`CACHE_BLK_NUM_SZ-1:0];

    reg ifetch_predict_jump;

    wire [`CACHE_INDEX_WID] pc_index;
    wire [`CACHE_TAG_WID] pc_tag;
    wire [`CACHE_OFF_WID] pc_off;
    wire [`CACHE_BLK_MAXLEN:0] pc_blk;
    wire hit;
    wire [`INST_WID] fetch_inst;
    wire [`OPCODE_WID] fetch_inst_opcode;
    wire fetch_inst_is_branch;
    wire [`BP_INDEX_WID] bp_index;
    wire [`CACHE_INDEX_WID] mem_find_addr_index;
    wire [`CACHE_TAG_WID] mem_find_addr_tag;
    wire [`INST_WID] cur_block[15:0];
    wire can_transport_to_decoder;
    reg [`ADDR_WID] predict_pc;
    assign pc_tag=ifetch_pc[`CACHE_TAG_RANGE];
    assign pc_index=ifetch_pc[`CACHE_INDEX_RANGE];
    assign pc_off=ifetch_pc[`CACHE_OFF_RANGE];
    assign pc_blk=blk_data[pc_index];
    assign bp_index=ifetch_pc[`BP_INDEX_RANGE];
    assign hit=(busy[pc_index]&&blk_tag[pc_index]==pc_tag);
    assign fetch_inst=cur_block[pc_off];
    assign fetch_inst_is_branch=(fetch_inst[`OPCODE_RANGE]==`OPCODE_JAL||fetch_inst[`OPCODE_RANGE]==`OPCODE_B);
    assign mem_find_addr_index=mem_find_addr[`CACHE_INDEX_RANGE];
    assign mem_find_addr_tag=mem_find_addr[`CACHE_TAG_RANGE];

    genvar _i;
    generate
        for (_i=0;_i<16;_i=_i+1)begin
            assign cur_block[_i]=pc_blk[_i*32+31:_i*32];
        end
    endgenerate

    //predict before transport in one cycle
    //must in combinational logic
    //whether jump or not
    //J imm[20|10:1|11|19:12] rd opcode
    //B imm[12|10:5] rs2 rs1 funct3 imm[4:1|11] opcode
    always @(*)begin
        predict_pc=ifetch_pc+4;
        ifetch_predict_jump=0;
        if(fetch_inst_is_branch)begin
            case(fetch_inst[`OPCODE_RANGE])
                `OPCODE_JAL:begin
                    predict_pc=ifetch_pc+{{12{fetch_inst[31]}},fetch_inst[19:12],fetch_inst[20],fetch_inst[30:21],1'b0};
                    ifetch_predict_jump=1;
                end
                `OPCODE_B:begin
                    if(tracker[bp_index]>=2'd2)begin
                        predict_pc=ifetch_pc+{{20{fetch_inst[31]}},fetch_inst[7],fetch_inst[30:25],fetch_inst[11:8],1'b0};
                        ifetch_predict_jump=1;
                    end else begin
                        predict_pc=ifetch_pc+4;
                        ifetch_predict_jump=0;
                    end
                end
            endcase
        end
    end

    //Branch Predictor
    //index [9:2] -> 256 blocks
    //pc with same index share the same result of branch predict
    //method : if instructions in one block jumped more than 2 times -> jump
    reg [2:0] tracker[`BP_BLK_NUM_SZ-1:0];

    wire [`CACHE_INDEX_WID] rob_bp_index=pc[`CACHE_INDEX_RANGE];

    integer i;

    always @(posedge clk)begin
        // $display("%h %b %h %h",ifetch_pc,busy[pc_index],blk_tag[pc_index],pc_tag);
        if(rst)begin
            ifetch_pc<=0;
            status<=IDLE;
            out_inst_valid<=0;
            out_inst_predict_jump<=0;
            mem_find_valid<=0;
            for(i=0;i<`BP_BLK_NUM_SZ;i=i+1)begin
                tracker[i]<=0;
            end
            for(i=0;i<`CACHE_BLK_NUM_SZ;i=i+1)begin
                busy[i]<=0;
                blk_tag[i]<=0;
            end
        end else if(rdy)begin
            out_inst_valid<=0;
            if(pc_valid)begin
                // $display("jump_pc to %h",jump_pc);
                ifetch_pc<=jump_pc;
            end else begin
                //transport instruction to decoder
                if(hit&&!rs_full&&!rob_full&&!lsb_full)begin
                    out_inst_valid<=1;
                    out_inst<=fetch_inst;
                    out_inst_pc<=ifetch_pc;
                    ifetch_pc<=predict_pc;
                    out_inst_predict_jump<=ifetch_predict_jump;
                end
            end
            //update branch history
            if(is_branch)begin
                if(is_jump)begin
                    if(tracker[rob_bp_index]<3)begin
                        tracker[rob_bp_index]<=tracker[rob_bp_index]+1;
                    end
                end else begin
                    if(tracker[rob_bp_index]>0)begin
                        tracker[rob_bp_index]<=tracker[rob_bp_index]-1;
                    end
                end
            end
            //fetch instruction from memory
            if(status==IDLE)begin
                mem_find_valid<=0;
                if(!hit)begin
                    status<=IFetch;
                    mem_find_valid<=1;
                    // $display("mem_find_addr=%h",{ifetch_pc[31:6],6'b0});
                    mem_find_addr<={ifetch_pc[31:6],6'b0};
                end
            end else begin
                if(mem_data_valid)begin
                    status<=IDLE;
                    mem_find_valid<=0;
                    blk_data[mem_find_addr_index]<=mem_data;
                    blk_tag[mem_find_addr_index]<=mem_find_addr_tag;
                    // $display("change tag[%h] %h",mem_find_addr_index,mem_find_addr_tag);
                    // $display("%h",mem_data);
                    busy[mem_find_addr_index]<=1;
                end
            end
        end
    end

endmodule
`endif