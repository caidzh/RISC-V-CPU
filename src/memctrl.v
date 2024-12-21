`ifndef memctrl
`define memctrl
`include "const.v"

module MemCtrl{
    input wire clk,
    input wire rst,
    input wire rdy,
    input wire rollback,

    //interact with memory
    input wire [`MEMORY_RW_WID] ret_data,
    output reg [`ADDR_WID] call_addr,			
    output reg is_write,
    output reg [`MEMORY_RW_WID] write_data,

    //LSB call MemCtrl
    input wire lsb_call_valid,
    input wire lsb_call_is_store,
    input wire [`ADDR_WID] lsb_call_addr,

    //for store
    input wire [`ST_LEN_WID] lsb_call_len,
    input wire [`DATA_WID] lsb_call_data,

    //MemCtrl respond LSB
    output reg respond_valid,
    output reg [`DATA_WID] respond_data,

    //ifetch call MemCtrl
    input wire mem_find_valid,
    input wire [`ADDR_WID] mem_find_addr,

    //MemCtrl respond ifetch
    output reg mem_data_valid,
    output reg [`CACHE_BLK_SZ_WID] mem_data
};
    localparam IDLE=1,IFETCH=1,LOAD=2,STORE=3;
    reg [`MEMCTRL_STATUS_WID] status;

    reg [`CACHE_BLK_SZ_WID] ready_sz;
    reg [`CACHE_BLK_SZ_WID] target_sz;
    reg [`DATA_WID] store_data;
    reg [`CACHE_BLK_SZ_WID] load_data;

    //1 cycle delay
    always @(posedge clk)begin
        respond_valid<=0;
        mem_data_valid<=0;
        is_write<=0;
        if(rst)begin
            status<=IDLE;
            ready_sz<=0;
            target_sz<=0;
            store_data<=0;
            load_data<=0;
        end else if(rdy)begin
            case(status)
                IDLE:begin
                    if(mem_find_valid)begin
                        status<=IFETCH;
                        load_data<=0;
                        call_addr<=mem_find_addr;
                        ready_sz<=0;
                        target_sz<=`CACHE_BLK_MAXLEN;
                    end else if(lsb_call_valid) begin
                        if(lsb_call_is_store)begin
                            status<=STORE;
                            store_data<=lsb_call_data;
                            call_addr<=lsb_call_addr;
                            ready_sz<=0;
                            target_sz<=lsb_call_len*8-1;
                        end else begin
                            status<=LOAD;
                            load_data<=0;
                            call_addr<=lsb_call_addr;
                            ready_sz<=0;
                            target_sz<=lsb_call_len*8-1;
                        end
                    end
                end
                IFETCH:begin
                    if(rollback)begin
                        call_addr<=0;
                        status<=IDLE;
                        ready_sz<=0;
                        target_sz<=0;
                        store_data<=0;
                        load_data<=0;
                    end else begin
                        load_data[ready_sz+7:ready_sz]<=ret_data;
                        if(ready_sz+7==target_sz)begin
                            status<=IDLE;
                            call_addr<=0;
                            ready_sz<=0;
                            target_sz<=0;
                            load_data<=0;
                            mem_data_valid<=1;
                            mem_data<=load_data[target_sz:0];
                        end else begin
                            ready_sz=ready+8;
                            call_addr=call_addr+1;
                        end
                    end
                end
                LOAD:begin
                    if(rollback)begin
                        call_addr<=0;
                        status<=IDLE;
                        ready_sz<=0;
                        target_sz<=0;
                        store_data<=0;
                        load_data<=0;
                    end else begin
                        load_data[ready_sz+7:ready_sz]<=ret_data;
                        if(ready_sz+7==target_sz)begin
                            status<=IDLE;
                            call_addr<=0;
                            ready_sz<=0;
                            target_sz<=0;
                            load_data<=0;
                            respond_valid<=1;
                            respond_data=load_data[target_sz:0];
                        end else begin
                            ready_sz=ready_sz+8;
                            call_addr=call_addr+1;
                        end
                    end
                end
                STORE:begin
                    is_write<=1;
                    write_data<=store_data[ready_sz+7:ready_sz];
                    if(ready_sz+7==target_sz)begin
                        status<=IDLE;
                        is_write<=0;
                        call_addr<=0;
                        ready_sz<=0;
                        target_sz<=0;
                    end else begin
                        ready_sz=ready_sz+8;
                        call_addr=call_addr+1;
                    end
                end
            endcase
        end
    end

endmodule
`endif