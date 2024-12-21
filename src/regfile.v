`ifndef regfile
`define regfile
`include "const.v"

module RegFile{
    input wire clk,
    input wire rst,
    input wire rdy,
    input wire rollback,

    //decoder call information of register
    input wire [`REG_ID_WID] call_rs1;
    input wire [`REG_ID_WID] call_rs2;

    //answer decoder
    output wire rs1_busy;
    output wire [`DATA_WID] answer_rs1_data;
    output wire [`ROB_ID_WID] rs1_rob_id;
    output wire rs2_busy;
    output wire [`DATA_WID] answer_rs2_data;
    output wire [`ROB_ID_WID] rs2_rob_id;

    //decoder update register dependecies
    input wire chg_dependency;
    input wire [`REG_ID_WID] chg_rs1;
    input wire [`ROB_ID_WID] dependent_rob_id;

    //ROB commit update regfile
    input wire is_commit;
    input wire[`REG_ID_WID] commit_rd;
    input wire[`DATA_WID] commit_data;
    input wire[`ROB_ID_WID] commit_rob_id;
};
    reg [`DATA_WID] reg_data[`REG_SZ-1:0];
    reg [`ROB_ID_WID] reg_rob_id[`REG_SZ-1:0];
    reg busy[`REG_SZ-1:0];

    integer i;

    //answer decoder (consider ROB commit and register store)
    always @(*)begin
        if(is_commit)begin
            if(commit_rd==call_rs1&&reg_rob_id[call_rs1]==commit_rob_id)begin
                rs1_busy=0;
                answer_rs1_data=commit_data;
                rs1_rob_id=0;
            end else begin
                rs1_busy=1;
                answer_rs1_data=0;
                rs1_rob_id=reg_rob_id[call_rs1];
            end
            if(commit_rd==call_rs2&&reg_rob_id[call_rs2]==commit_rob_id)begin
                rs2_busy=0;
                answer_rs2_data=commit_data;
                rs2_rob_id=0;
            end else begin
                rs2_busy=1;
                answer_rs2_data=0;
                rs2_rob_id=reg_rob_id[call_rs2];
            end
        end
    end

    //change dependecies
    always @(posedge clk)begin
        if(rst)begin
            for(i=0;i<`REG_SZ;i=i+1)begin
                reg_data[i]<=0;
                reg_rob_id[i]<=0;
                busy[i]<=0;
            end
        end else if(rdy)begin
            if(is_commit)begin
                if(reg_rob_id[commit_rd]==commit_rob_id)begin
                    busy[commit_rd]<=0;
                    reg_data[commit_rd]<=commit_data;
                end
            end
            if(chg_dependency)begin
                reg_rob_id[chg_rs1]<=dependent_rob_id;
            end
            if(rollback)begin
                for(i=0;i<`REG_SZ;i=i+1)begin
                    busy[i]<=0;
                end
            end
        end
    end

endmodule
`endif