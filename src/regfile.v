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
    input wire [`ADDR_WID] decoder_call_pc,

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
    input wire [`ADDR_WID] chg_pc,

    //ROB commit update regfile
    input wire is_commit,
    input wire [`REG_ID_WID] commit_rd,
    input wire [`DATA_WID] commit_data,
    input wire [`ROB_ID_WID] commit_rob_id,
    input wire [`ADDR_WID] commit_pc
);
    reg [`DATA_WID] reg_data[`REG_SZ-1:0];
    reg [`ROB_ID_WID] reg_rob_id[`REG_SZ-1:0];
    reg busy[`REG_SZ-1:0];

    integer i;

    // integer file;
    // initial begin
    //     file=$fopen("regfile.txt", "w");
    // end

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
        // $fwrite(file,"answer inst=%h rs1=%h busy=%h data=%h rob_id=%h\n",decoder_call_pc,call_rs1,busy[call_rs1],reg_data[call_rs1],reg_rob_id[call_rs1]);
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
    //change dependecies

    always @(posedge clk)begin
        // if(is_commit)begin
        //     $fwrite(file, "%h\n",commit_pc);
        //     for(i=13;i<14;i=i+1)begin
        //         $fwrite(file, "(%b,%h,%h)|",busy[i],reg_data[i],reg_rob_id[i]);
        //     end
        //     $fwrite(file,"\n");
        // end
        if(rst)begin
            for(i=0;i<`REG_SZ;i=i+1)begin
                reg_data[i]<=0;
                reg_rob_id[i]<=0;
                busy[i]<=0;
            end
        end else if(rdy)begin
            if(is_commit)begin
                if(commit_rd!=0)begin
                    reg_data[commit_rd]<=commit_data;
                    // $fwrite(file, "inst %h assign reg.%h %h\n",commit_pc,commit_rd,commit_data);
                end
                if(commit_rd!=0&&busy[commit_rd]&&reg_rob_id[commit_rd]==commit_rob_id)begin
                    busy[commit_rd]<=0;
                    reg_rob_id[commit_rd]<=0;
                    // $display("assign reg.%h %h",commit_rd,commit_data);
                    // $fwrite(file, "inst %h assign reg.%h %h finish rob_id\n",commit_pc,commit_rd,commit_data);
                end
            end
            if(chg_dependency&&chg_rs1!=0)begin
                busy[chg_rs1]<=1;
                reg_rob_id[chg_rs1]<=dependent_rob_id;
                // $fwrite(file,"%h change reg.%h dependency to %h\n",chg_pc,chg_rs1,dependent_rob_id);
            end
            if(rollback)begin
                // $display("regfile rollback");
                for(i=0;i<`REG_SZ;i=i+1)begin
                    busy[i]<=0;
                    reg_rob_id[i]<=0;
                end
            end
        end
    end

endmodule
`endif