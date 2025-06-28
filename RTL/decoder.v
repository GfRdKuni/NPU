`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2025/06/17 21:19:01
// Design Name: 
// Module Name: decoder
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


module decoder #
(
    parameter INST_LEN = 16,
    parameter OPCODE_LEN = 3,
    parameter REG_LEN = 4,
    parameter SIMM_LEN = 5,
    parameter LIMM_LEN = 8

)
(
    input wire clk,
    input wire rst_n,
    input wire [INST_LEN-1:0] inst_i,
    output wire [OPCODE_LEN-1:0] opcode_o,
    output wire [REG_LEN-1:0] rs1_o,
    output wire [REG_LEN-1:0] rs2_o,
    output wire [REG_LEN-1:0] rd_o,
    output wire [SIMM_LEN-1:0] short_imm_o,
    output wire [LIMM_LEN-1:0] long_imm_o,
    output wire func_o,
    output reg [2:0]forward_flag_o
    );
    localparam OPCODE_LOAD = 3'b000;
    localparam OPCODE_STORE = 3'b001;
    localparam OPCODE_MOV = 3'b010;
    localparam OPCODE_VLOAD = 3'b100;
    localparam OPCODE_VSTORE = 3'b101;
    localparam OPCODE_VMAC = 3'b110;
    assign opcode_o = inst_i[15:13];
    // load 000 store 001 mov 010 vload 100 vstore 101 vmac 110
    assign rd_o = inst_i[12:9];
    assign rs1_o = inst_i[8:5];
    assign rs2_o = inst_i[4:1];
    assign func_o = inst_i[0];
    assign short_imm_o = inst_i[4:0];
    assign long_imm_o = inst_i[8:1];
    reg [INST_LEN-1:0] inst_last;
    always @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            inst_last <= 0;
        end else begin
            inst_last <= inst_i;
        end
    end
    wire [OPCODE_LEN-1:0] last_opcode;
    wire [REG_LEN-1:0]    last_rs1;
    wire [REG_LEN-1:0]    last_rs2;
    wire [REG_LEN-1:0]    last_rd;

    assign last_opcode = inst_last[15:13];
    assign last_rd = inst_last[12:9];
    assign last_rs1 = inst_last[8:5];
    assign last_rs2 = inst_last[4:1];

    // load 000 store 001 mov 010 vload 100 vstore 101 vmac 110
    always @(*) begin
        if (last_opcode == OPCODE_LOAD || last_opcode == OPCODE_MOV) begin
            if (opcode_o == OPCODE_STORE && ((rs1_o == last_rd) || (rs2_o == last_rd))) 
                forward_flag_o = {last_opcode == OPCODE_MOV, last_rd == rs1_o, 1'b1};
            else if ((opcode_o == OPCODE_VLOAD || opcode_o == OPCODE_LOAD || opcode_o == OPCODE_VSTORE || opcode_o == OPCODE_VMAC) && (rs1_o == last_rd))
                forward_flag_o = {(last_opcode == OPCODE_MOV),2'b11};
            else
                forward_flag_o = 3'b000;
        end
        else if (last_opcode == OPCODE_VLOAD || last_opcode == OPCODE_VMAC) begin
            if ((opcode_o == OPCODE_VSTORE || opcode_o == OPCODE_VMAC) && (rs2_o == last_rd))
                forward_flag_o = {last_opcode == OPCODE_VMAC, 2'b01};
            else
                forward_flag_o = 3'b000;
        end    
        else begin
            forward_flag_o = 3'b000;
        end
    end

endmodule
