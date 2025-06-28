`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2025/06/17 23:06:26
// Design Name: 
// Module Name: MAC
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


module MAC#(
    parameter DATA_WIDTH = 16,
    parameter ACC_WIDTH  = 36,
    parameter VMAX = 8
)

(
    input                   clk,
    input                   rst_n,
    input [DATA_WIDTH-1:0]  rs1_i,
    input [DATA_WIDTH-1:0]  rs2_i,
    input                   func_i,
    input                   activated_i,
    output [DATA_WIDTH-1:0] vrd_data_o
);
    wire [ACC_WIDTH-1:0]    prod_data;
    wire [ACC_WIDTH-1:0]    vrd_data_int;
    reg  [ACC_WIDTH-1:0]    vrd_prev;
    assign prod_data = rs1_i * rs2_i;
    assign vrd_data_int = (func_i == 1'b1) ? rs2_i : prod_data + vrd_prev;
    
    always @(posedge clk or negedge rst_n) begin
        if(!rst_n)
            vrd_prev <= 0;
        else if (activated_i)
            vrd_prev <= vrd_data_int;
        else
            vrd_prev <= vrd_prev;
    end

    assign vrd_data_o = vrd_data_int[35:20];



endmodule
