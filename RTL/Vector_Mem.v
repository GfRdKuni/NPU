`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2025/06/17 16:21:00
// Design Name: 
// Module Name: Vector_Mem
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


module Vector_Mem#
(
    parameter DATA_WIDTH = 16,
    parameter ADDR_WIDTH = 10,
    parameter VMAX       = 8 ,
    parameter VMAX_WIDTH = $clog2(VMAX),
    parameter DEPTH      = 2**ADDR_WIDTH
)
(
    input wire                            clk,
    input wire                            rst_n,
    input wire [ADDR_WIDTH-1:0]           waddr_i,
    input wire [ADDR_WIDTH-1:0]           raddr_i,
    input wire                            is_working_i,
    input wire [DATA_WIDTH-1:0]           wdata_scalar_i,
    input wire [DATA_WIDTH * VMAX -1 :0]  wdata_vector_i,
    input wire                            wen_i,
    input wire                            ren_i,
    output wire [DATA_WIDTH * VMAX -1 :0]  rdata_o
);

    reg [DATA_WIDTH - 1:0] mem[DEPTH-1:0];
    integer i;
    always @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            for (i = 0; i < DEPTH; i=i+1) begin
                mem[i] <= 0;
            end
        end
        else if (wen_i & ~is_working_i)
            mem[waddr_i] <= wdata_scalar_i;
        else if (wen_i & is_working_i) begin
            mem[waddr_i] <= wdata_vector_i[DATA_WIDTH*VMAX-1:DATA_WIDTH*(VMAX-1)];
            mem[waddr_i + 1] <= wdata_vector_i[DATA_WIDTH*(VMAX-1)-1:DATA_WIDTH*(VMAX-2)];
            mem[waddr_i + 2] <= wdata_vector_i[DATA_WIDTH*(VMAX-2)-1:DATA_WIDTH*(VMAX-3)];
            mem[waddr_i + 3] <= wdata_vector_i[DATA_WIDTH*(VMAX-3)-1:DATA_WIDTH*(VMAX-4)];
            mem[waddr_i + 4] <= wdata_vector_i[DATA_WIDTH*(VMAX-4)-1:DATA_WIDTH*(VMAX-5)];
            mem[waddr_i + 5] <= wdata_vector_i[DATA_WIDTH*(VMAX-5)-1:DATA_WIDTH*(VMAX-6)];
            mem[waddr_i + 6] <= wdata_vector_i[DATA_WIDTH*(VMAX-6)-1:DATA_WIDTH*(VMAX-7)];
            mem[waddr_i + 7] <= wdata_vector_i[DATA_WIDTH*(VMAX-7)-1:0];
        end
        else begin
            for (i = 0; i < DEPTH; i=i+1) begin
                mem[i] <= mem[i];
            end
        end
    end

    assign rdata_o = (ren_i) ? {mem[raddr_i],mem[raddr_i + 1], mem[raddr_i + 2], mem[raddr_i + 3], mem[raddr_i + 4], mem[raddr_i + 5], mem[raddr_i + 6], mem[raddr_i + 7]} : {VMAX*DATA_WIDTH{1'b0}};

endmodule
