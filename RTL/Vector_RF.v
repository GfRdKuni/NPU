`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2025/06/17 21:25:51
// Design Name: 
// Module Name: Vector_RF
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


module Vector_RF#
(
    parameter DATA_WIDTH = 16,
    parameter REG_WIDTH = 4,
    parameter VMAX = 8
)
(
    input wire                               clk,
    input wire                               rst_n,
    input wire  [REG_WIDTH-1:0]              rs_i,
    input wire  [REG_WIDTH-1:0]              rd_i,
    input wire                               wen_i,
    input wire  [DATA_WIDTH * VMAX - 1 : 0]  rd_data_i,
    output wire [DATA_WIDTH * VMAX - 1 : 0]  rs_data_o
   
    );

    integer i;
    reg [DATA_WIDTH * VMAX - 1 : 0] regfile[2**REG_WIDTH-1:0];
    assign rs_data_o = (rs_i == 0) ? {VMAX * DATA_WIDTH{1'b0}} : regfile[rs_i];
    

    always @(negedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (i = 0; i < 2**REG_WIDTH; i=i+1) begin
                regfile[i] <= {VMAX * DATA_WIDTH{1'b0}};
            end
        end
        else if (~rd_i && wen_i) begin
            regfile[rd_i] <= rd_data_i;
        end
        else begin
            for (i = 0; i < 2**REG_WIDTH; i=i+1) begin
                regfile[i] <= regfile[i];
            end
        end
    end

endmodule
