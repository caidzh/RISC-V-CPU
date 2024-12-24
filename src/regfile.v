`ifndef regfile
`define regfile
`include "const.v"

module RegFile(
    input wire clk,
    input wire rst,
    input wire rdy,
    input wire rollback,

    //decoder call information of register
    input wire is_call_rs1,
    input wire [`REG_ID_WID] call_rs1,
    input wire is_call_rs2,
    input wire [`REG_ID_WID] call_rs2,

    //answer decoder
    output reg rs1_busy,
    output reg [`DATA_WID] answer_rs1_data,
    output reg [`ROB_ID_WID] rs1_rob_id,
    output reg rs2_busy,
    output reg [`DATA_WID] answer_rs2_data,
    output reg [`ROB_ID_WID] rs2_rob_id,

    //decoder update register dependecies
    input wire chg_dependency,
    input wire [`REG_ID_WID] chg_rs1,
    input wire [`ROB_ID_WID] dependent_rob_id,

    //ROB commit update regfile
    input wire is_commit,
    input wire[`REG_ID_WID] commit_rd,
    input wire[`DATA_WID] commit_data,
    input wire[`ROB_ID_WID] commit_rob_id
);
    reg [`DATA_WID] reg_data[`REG_SZ-1:0];
    reg [`ROB_ID_WID] reg_rob_id[`REG_SZ-1:0];
    reg busy[`REG_SZ-1:0];

    integer i;

    //answer decoder (consider ROB commit and register store)
    // assign rs1_busy=(is_commit?((commit_rd==call_rs1&&reg_rob_id[call_rs1]==commit_rob_id)?0:1):0);
    // assign answer_rs1_data=(is_commit?((commit_rd==call_rs1&&reg_rob_id[call_rs1]==commit_rob_id)?commit_data:0):0);
    // assign rs1_rob_id=(is_commit?((commit_rd==call_rs1&&reg_rob_id[call_rs1]==commit_rob_id)?0:reg_rob_id[call_rs1]):0);
    // assign rs2_busy=(is_commit?((commit_rd==call_rs1&&reg_rob_id[call_rs2]==commit_rob_id)?0:1):0);
    // assign answer_rs2_data=(is_commit?((commit_rd==call_rs1&&reg_rob_id[call_rs2]==commit_rob_id)?commit_data:0):0);
    // assign rs2_rob_id=(is_commit?((commit_rd==call_rs1&&reg_rob_id[call_rs2]==commit_rob_id)?0:reg_rob_id[call_rs2]):0);
    always @(*)begin
        if(is_commit&&commit_rd==call_rs1&&reg_rob_id[call_rs1]==commit_rob_id)begin
            rs1_busy=0;
            answer_rs1_data=commit_data;
            rs1_rob_id=0;
        end else begin
            rs1_busy=busy[call_rs1];
            answer_rs1_data=reg_data[call_rs1];
            rs1_rob_id=reg_rob_id[call_rs1];
        end
        if(is_commit&&commit_rd==call_rs2&&reg_rob_id[call_rs2]==commit_rob_id)begin
            rs2_busy=0;
            answer_rs2_data=commit_data;
            rs2_rob_id=0;
        end else begin
            rs2_busy=busy[call_rs2];
            answer_rs2_data=reg_data[call_rs2];
            rs2_rob_id=reg_rob_id[call_rs2];
        end
        // $display("query %h %h",call_rs1,call_rs2);
        // $display("answer %h %h %h",rs1_busy,answer_rs1_data,rs1_rob_id);
        // $display("answer %h %h %h",rs2_busy,answer_rs2_data,rs2_rob_id);
    end
    integer file;
    initial begin
        file=$fopen("verilog.txt", "w");
    end
    //change dependecies

    always @(posedge clk)begin
        for(i=13;i<14;i=i+1)begin
            $fwrite(file, "(%b,%h,%h)|",busy[i],reg_data[i],reg_rob_id[i]);
        end
        $fwrite(file,"\n\n");
        if(rst)begin
            for(i=0;i<`REG_SZ;i=i+1)begin
                reg_data[i]<=0;
                reg_rob_id[i]<=0;
                busy[i]<=0;
            end
        end else if(rdy)begin
            if(is_commit)begin
                if(busy[commit_rd]&&reg_rob_id[commit_rd]==commit_rob_id&&commit_rd!=0)begin
                    busy[commit_rd]<=0;
                    reg_data[commit_rd]<=commit_data;
                    // $display("assign reg.%h %h",commit_rd,commit_data);
                end
            end
            if(chg_dependency&&chg_rs1!=0)begin
                busy[chg_rs1]<=1;
                reg_rob_id[chg_rs1]<=dependent_rob_id;
                // $display("change reg.%h dependency to %h",chg_rs1,dependent_rob_id);
            end
            if(rollback)begin
                // $display("regfile rollback");
                for(i=0;i<`REG_SZ;i=i+1)begin
                    busy[i]<=0;
                end
            end
        end
    end

endmodule
`endif