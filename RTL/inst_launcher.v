`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2025/06/17 11:17:44
// Design Name: 
// Module Name: inst_launcher
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


module inst_launcher#
(
    parameter INST_LEN = 16,
    parameter PC_WIDTH = 8
)
(
    input wire clk,
    input wire rst_n,
    input wire complete,
    input wire is_working,
    output reg [PC_WIDTH-1 : 0] PC
);
    always @(posedge clk or negedge rst_n) begin
        if(!rst_n) PC <= 1'b0;
        else if (complete) PC <= 1'b0;
        else if (is_working) PC <= PC + 1;
        else PC <= PC;
    end


endmodule
