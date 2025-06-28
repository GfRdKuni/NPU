`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2025/06/17 21:26:55
// Design Name: 
// Module Name: Scalar_RF
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module Scalar_RF#
(
    parameter DATA_WIDTH = 16,
    parameter REG_WIDTH = 4
)
(
    input wire                                clk,
    input wire                                rst_n,
    input wire [REG_WIDTH-1:0]                rs1_i,
    input wire [REG_WIDTH-1:0]                rs2_i,
    input wire [REG_WIDTH-1:0]                rd_i,
    input wire                                wen_i,
    input wire [DATA_WIDTH-1:0]               rd_data_i,
    input wire [1:0]                          func_i,
    output wire [DATA_WIDTH-1:0]              rs1_data_o,
    output wire [DATA_WIDTH-1:0]              rs2_data_o,
    output wire [DATA_WIDTH/2-1:0]            vlen,
    output wire [7:0]                         vmask_o
);
    integer i;
    reg [DATA_WIDTH-1:0] regfile[2**REG_WIDTH - 1:0];
    assign rs1_data_o = (rs1_i == 0) ? {DATA_WIDTH{1'b0}} : regfile[rs1_i];
    assign rs2_data_o = (rs2_i == 0) ? {DATA_WIDTH{1'b0}} : regfile[rs2_i];
    assign vlen = regfile[2**REG_WIDTH - 1][DATA_WIDTH/2-1:0];
    assign vmask_o = regfile[2**REG_WIDTH - 1][DATA_WIDTH-1:DATA_WIDTH/2];

    always @(negedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (i = 0; i < 2**REG_WIDTH; i = i+1) begin
                regfile[i] <= {DATA_WIDTH{1'b0}};
            end
        end 
        else if (rd_i != 0 && wen_i && func_i[1] == 0) begin
            regfile[rd_i] <= rd_data_i;
        end
        else if (rd_i != 0 && wen_i && func_i[1] == 1) begin
            if (func_i[0] == 0) begin // LOAD Lower Immediate Byte
                regfile[rd_i][7:0] <= rd_data_i[7:0];
            end
            else begin // LOAD Upper Immediate Byte
                regfile[rd_i][15:8] <= rd_data_i[15:8];
            end
        end
        else begin
            for (i = 0; i < 2**REG_WIDTH; i = i+1) begin
                regfile[i] <= regfile[i];
            end
        end   
    end

endmodule
