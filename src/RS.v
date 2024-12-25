`ifndef RS
`define RS
`include "const.v"

module RS(
    input wire clk,
    input wire rdy,
    input wire rst,
    input wire rollback,

    //out rs_full determine stall
    output reg rs_full,

    //decoder update RS
    input wire inst_valid,
    input wire [`OPCODE_WID] inst_opcode,
    input wire [`FUNC3_WID] inst_func3,
    input wire inst_func1,
    input wire inst_reg1_depend_rob,
    input wire [`DATA_WID] inst_reg1_data,
    input wire [`ROB_ID_WID] inst_reg1_rob_id,
    input wire inst_reg2_depend_rob,
    input wire [`DATA_WID] inst_reg2_data,
    input wire [`ROB_ID_WID] inst_reg2_rob_id,
    input wire [`ROB_ID_WID] inst_rd_rob_id,
    input wire [`DATA_WID] inst_imm,
    input wire [`DATA_WID] inst_off,
    input wire [`DATA_WID] inst_pc,

    //ALU update RS
    input wire alu_valid,
    input wire [`ROB_ID_WID] alu_rob_id,
    input wire [`DATA_WID] alu_data,

    //LSB update RS
    input wire lsb_valid,
    input wire [`ROB_ID_WID] lsb_rob_id,
    input wire [`DATA_WID] lsb_data,

    //execute to ALU
    output reg exe_valid,
    output reg [`OPCODE_WID] exe_opcode,
    output reg [`FUNC3_WID] exe_func3,
    output reg exe_func1,
    output reg [`DATA_WID] exe_data1,
    output reg [`DATA_WID] exe_data2,
    output reg [`DATA_WID] exe_imm,
    output reg [`DATA_WID] exe_off,
    output reg [`ADDR_WID] exe_pc,
    output reg [`ROB_ID_WID] exe_rob_target
);
    //Reservation Station
    reg busy[`RS_SZ-1:0];
    reg [`OPCODE_WID] rs_inst_opcode[`RS_SZ-1:0];
    reg [`FUNC3_WID] rs_inst_func3[`RS_SZ-1:0];
    reg rs_inst_func1[`RS_SZ-1:0];
    reg rs_inst_reg1_depend_rob[`RS_SZ-1:0];
    reg [`DATA_WID] rs_inst_reg1_data[`RS_SZ-1:0];
    reg [`ROB_ID_WID] rs_inst_reg1_rob_id[`RS_SZ-1:0];
    reg rs_inst_reg2_depend_rob[`RS_SZ-1:0];
    reg [`DATA_WID] rs_inst_reg2_data[`RS_SZ-1:0];
    reg [`ROB_ID_WID] rs_inst_reg2_rob_id[`RS_SZ-1:0];
    reg [`ROB_ID_WID] rs_inst_rd_rob_id[`RS_SZ-1:0];
    reg [`DATA_WID] rs_inst_imm[`RS_SZ-1:0];
    reg [`DATA_WID] rs_inst_off[`RS_SZ-1:0];
    reg [`DATA_WID] rs_inst_pc[`RS_SZ-1:0];

    //mark blank position 
    reg [`RS_ID_WID] blank;
    reg find_blank;

    //mark element can be executed
    reg [`RS_ID_WID] execute;
    reg find_execute;
    
    integer i;

    //find blank position and execute element
    always @(*)begin
        find_blank=0;
        find_execute=0;
        blank=0;
        execute=0;
        rs_full=1;
        for(i=0;i<`RS_SZ;i=i+1)begin
            if(busy[i])begin
                if(!rs_inst_reg1_depend_rob[i]&&!rs_inst_reg2_depend_rob[i]&&!find_execute)begin
                    find_execute=1;
                    execute=i;
                end
            end else begin
                if(find_blank)
                    rs_full=0;
                find_blank=1;
                if(!blank)
                    blank=i;
            end
        end
        // $display("execute %d",execute);
    end

    always @(posedge clk)begin
        if(rst||rollback)begin
            // $display("RS rollback");
            for(i=0;i<`RS_SZ;i=i+1)begin
                busy[i]<=0;
            end
            rs_full<=0;
            exe_valid<=0;
        end else if(rdy)begin
            exe_valid<=0;
            // for(i=0;i<`RS_SZ;i=i+1)begin
            //     if(busy[i])begin
            //         $display("%d %b %b %b",i,rs_inst_opcode[i],rs_inst_reg1_depend_rob[i],rs_inst_reg2_depend_rob[i]);
            //     end
            // end
            if(find_blank&&inst_valid)begin
                busy[blank]<=1;
                rs_inst_opcode[blank]<=inst_opcode;
                rs_inst_func3[blank]<=inst_func3;
                rs_inst_func1[blank]<=inst_func1;
                rs_inst_reg1_depend_rob[blank]<=inst_reg1_depend_rob;
                rs_inst_reg1_data[blank]<=inst_reg1_data;
                rs_inst_reg1_rob_id[blank]<=inst_reg1_rob_id;
                rs_inst_reg2_depend_rob[blank]<=inst_reg2_depend_rob;
                rs_inst_reg2_data[blank]<=inst_reg2_data;
                rs_inst_reg2_rob_id[blank]<=inst_reg2_rob_id;
                rs_inst_rd_rob_id[blank]<=inst_rd_rob_id;
                rs_inst_imm[blank]<=inst_imm;
                rs_inst_off[blank]<=inst_off;
                rs_inst_pc[blank]<=inst_pc;
                // if(inst_pc==1176)begin
                //     $display("%b %h %h",inst_reg1_depend_rob,inst_reg1_data,inst_reg1_rob_id);
                // end
            end
            if(find_execute)begin
                exe_valid<=1;
                busy[execute]<=0;
                exe_opcode<=rs_inst_opcode[execute];
                exe_func3<=rs_inst_func3[execute];
                exe_func1<=rs_inst_func1[execute];
                exe_data1<=rs_inst_reg1_data[execute];
                exe_data2<=rs_inst_reg2_data[execute];
                exe_imm<=rs_inst_imm[execute];
                exe_off<=rs_inst_off[execute];
                exe_pc<=rs_inst_pc[execute];
                exe_rob_target<=rs_inst_rd_rob_id[execute];
            end
            if(alu_valid)begin
                for(i=0;i<`RS_SZ;i=i+1)begin
                    if(busy[i])begin
                        if(rs_inst_reg1_depend_rob[i]&&rs_inst_reg1_rob_id[i]==alu_rob_id)begin
                            rs_inst_reg1_data[i]<=alu_data;
                            rs_inst_reg1_depend_rob[i]<=0;
                        end
                        if(rs_inst_reg2_depend_rob[i]&&rs_inst_reg2_rob_id[i]==alu_rob_id)begin
                            rs_inst_reg2_data[i]<=alu_data;
                            rs_inst_reg2_depend_rob[i]<=0;
                        end
                    end
                end
            end
            if(lsb_valid)begin
                for(i=0;i<`RS_SZ;i=i+1)begin
                    if(busy[i])begin
                        if(rs_inst_reg1_depend_rob[i]&&rs_inst_reg1_rob_id[i]==lsb_rob_id)begin
                            rs_inst_reg1_data[i]<=lsb_data;
                            rs_inst_reg1_depend_rob[i]<=0;
                        end
                        if(rs_inst_reg2_depend_rob[i]&&rs_inst_reg2_rob_id[i]==lsb_rob_id)begin
                            rs_inst_reg2_data[i]<=lsb_data;
                            rs_inst_reg2_depend_rob[i]<=0;
                        end
                    end
                end
            end
        end
    end

endmodule
`endif