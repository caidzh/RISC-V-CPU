`ifndef memctrl
`define memctrl
`include "const.v"

module MemCtrl(
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

    input wire io_buffer_full,

    //MemCtrl respond ifetch
    output reg mem_data_valid,
    output wire [`CACHE_BLK_SZ-1:0] mem_data
);
    localparam IDLE=0,IFETCH=1,LOAD=2,STORE=3;
    reg [`MEMCTRL_STATUS_WID] status;

    reg [6:0] ready_sz;
    reg [6:0] target_sz;
    reg [`DATA_WID] store_data;
    reg [`ADDR_WID] store_addr;
    reg [7:0] load_data[63:0];
    wire [`CACHE_BLK_SZ_WID] selected_ready_sz;

    genvar _i;
    generate
        for(_i=0;_i<64;_i=_i+1)begin
            assign mem_data[(_i+1)*8-1:_i*8]=load_data[_i];
        end
    endgenerate

    //1 cycle delay
    always @(posedge clk)begin
        if(rst)begin
            status<=IDLE;
            ready_sz<=0;
            target_sz<=0;
            store_data<=0;
            store_addr<=0;
            respond_valid<=0;
            mem_data_valid<=0;
            is_write<=0;
        end else if(rdy)begin
            respond_valid<=0;
            mem_data_valid<=0;
            is_write<=0;
            case(status)
                IDLE:begin
                    if(mem_data_valid||respond_valid||rollback)begin
                        mem_data_valid<=0;
                        respond_valid<=0;
                    end else if(mem_find_valid)begin
                        status<=IFETCH;
                        call_addr<=mem_find_addr;
                        ready_sz<=0;
                        target_sz<=64;
                        // $display("Execute ifetch %h",mem_find_addr);
                    end else if(lsb_call_valid) begin
                        if(lsb_call_is_store)begin
                            // $display("execute store %h %h %h",lsb_call_data,lsb_call_addr,lsb_call_len);
                            status<=STORE;
                            store_data<=lsb_call_data;
                            // call_addr<=lsb_call_addr;
                            ready_sz<=0;
                            target_sz<=lsb_call_len;
                            store_addr<=lsb_call_addr;
                        end else begin
                            // $display("execute load %h",lsb_call_addr);
                            status<=LOAD;
                            call_addr<=lsb_call_addr;
                            ready_sz<=0;
                            target_sz<={4'b0,lsb_call_len};
                            respond_data<=0;
                        end
                    end
                end
                IFETCH:begin
                    if(rollback)begin
                        // $display("memctrl rollback");
                        call_addr<=0;
                        status<=IDLE;
                        ready_sz<=0;
                        target_sz<=0;
                        store_data<=0;
                    end else begin
                        // $display("execute ifetch %h",call_addr);
                        load_data[ready_sz-1]=ret_data;
                        if(ready_sz+1==target_sz)begin
                            ready_sz<=ready_sz+1;
                            call_addr<=0;
                        end else if(ready_sz==target_sz)begin
                            status<=IDLE;
                            call_addr<=0;
                            ready_sz<=0;
                            target_sz<=0;
                            mem_data_valid<=1;
                        end else begin
                            ready_sz<=ready_sz+1;
                            call_addr<=call_addr+1;
                        end
                    end
                end
                LOAD:begin
                    if(rollback)begin
                        // $display("memctrl rollback");
                        call_addr<=0;
                        status<=IDLE;
                        ready_sz<=0;
                        target_sz<=0;
                        store_data<=0;
                    end else begin
                        case(ready_sz)
                            1:begin
                                respond_data[7:0]<=ret_data;
                            end
                            2:begin
                                respond_data[15:8]<=ret_data;
                            end
                            3:begin
                                respond_data[23:16]<=ret_data;
                            end
                            4:begin
                                respond_data[31:24]<=ret_data;
                            end
                        endcase
                        if(ready_sz+1==target_sz)begin
                            ready_sz<=ready_sz+1;
                            call_addr<=0;
                        end else if(ready_sz==target_sz)begin
                            status<=IDLE;
                            call_addr<=0;
                            ready_sz<=0;
                            target_sz<=0;
                            respond_valid<=1;
                        end else begin
                            ready_sz<=ready_sz+1;
                            call_addr<=call_addr+1;
                        end
                    end
                end
                STORE:begin
                    if(store_addr[17:16]!=2'b11||!io_buffer_full)begin
                        is_write<=1;
                        case(ready_sz)
                            0:begin
                                write_data<=store_data[7:0];
                            end
                            1:begin
                                write_data<=store_data[15:8];
                            end
                            2:begin
                                write_data<=store_data[23:16];
                            end
                            3:begin
                                write_data<=store_data[31:24];
                            end
                        endcase
                        // $display("write %h %h %h",call_addr,write_data,ready_sz);
                        if(ready_sz==target_sz)begin
                            // $display("finish");
                            status<=IDLE;
                            is_write<=0;
                            call_addr<=0;
                            ready_sz<=0;
                            target_sz<=0;
                            respond_valid<=1;
                        end else begin
                            ready_sz<=ready_sz+1;
                            if(ready_sz>0)begin
                                call_addr<=call_addr+1;
                            end else begin
                                call_addr<=store_addr;
                            end
                        end
                    end
                end
            endcase
        end else begin
            respond_valid<=0;
            mem_data_valid<=0;
            is_write<=0;
            call_addr<=0;
        end
    end

endmodule
`endif