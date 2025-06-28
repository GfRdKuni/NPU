`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2025/06/17 13:55:54
// Design Name: 
// Module Name: dff
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


module dff#(
    parameter WIDTH = 16
)
(
    input clk,
    input rst_n,
    input en_i,
    input [WIDTH-1:0] d_i,
    output reg [WIDTH-1:0]q_o
);
    always@(posedge clk or negedge rst_n)
    begin
        if(!rst_n)
            q_o <= 0;
        else if(en_i)
            q_o <= d_i;
        else
            q_o <= q_o;
    end
endmodule
