`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2025/06/17 11:21:21
// Design Name: 
// Module Name: Mem
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


module Mem#
(
    parameter MEM_ADDR_WIDTH = 10,
    parameter MEM_DATA_WIDTH = 16,
    parameter MEM_DEPTH = 1 << MEM_ADDR_WIDTH
)

(
    input wire                       clk,
    input wire                       rst_n,
    input wire  [MEM_ADDR_WIDTH-1:0] waddr_i,
    input wire  [MEM_ADDR_WIDTH-1:0] raddr_i,
    input wire                       wen_i,
    input wire                       ren_i,
    input wire  [MEM_DATA_WIDTH-1:0] wdata_i,
    output wire [MEM_DATA_WIDTH-1:0] rdata_o
);
    integer i;
    
    reg [MEM_DATA_WIDTH-1:0] Mem[MEM_DEPTH-1:0];
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            
            for (i = 0; i < MEM_DEPTH; i = i + 1) begin
                Mem[i] <= {MEM_DATA_WIDTH{1'b0}};
            end
        end
        else if (wen_i) begin
            Mem[waddr_i] <= wdata_i;
        end
        else begin
            for (i = 0; i < MEM_DEPTH; i = i + 1) begin
                Mem[i] <= Mem[i];
            end
        end
    end

    assign rdata_o = (ren_i) ? Mem[raddr_i] : {MEM_DATA_WIDTH{1'b0}};
endmodule
