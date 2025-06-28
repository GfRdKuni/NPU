`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2025/06/17 13:59:10
// Design Name: 
// Module Name: CU
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


module CU
#(
    parameter ADDR_WIDTH   = 16,
    parameter DATA_WIDTH   = 16,
    parameter PC_WIDTH     = 8,
    parameter SCALAR_BASE  = 16'h0100, // 256
    parameter VECTOR_BASE  = 16'h0200, // 512
    parameter VECTOR_UPPER = 16'h0300, // 768
    parameter VMAX         = 8,
    parameter VMAX_WIDTH   = $clog2(VMAX)
    /****
    *   ICM : 16'h0000 - 16'h00FF  Capacity : 256 * 16bit
    *   Scalar : 16'h0100 - 16'h04FF Capacity : 1024 * 16bit
    *   Vector : 16'h0500 - 16'h08FF Capacity : 1024 * 16bit
    *****/
)
(
    input wire                      clk,
    input wire                      rst_n,
    input wire                      valid_i,
    input wire                      sop_i,
    input wire                      eop_i,
    input wire                      ready_i,
    input wire  [ADDR_WIDTH-1:0]    addr_in_i,
    input wire  [PC_WIDTH-1:0]      pc_current_i,
    input wire  [VMAX_WIDTH:0]      result_cnt_i,
    output wire                     result_is_OK_o,
    output reg                      valid_o,
    output wire                     ready_o,
    output reg                      sop_o,
    output reg                      eop_o,
    output wire [ADDR_WIDTH-1:0]    addr_out_o,
    output reg [2:0]                wen_init_o, // {Vector_wen, Scalar_wen, Inst_wen} 
    output wire                     is_working_o,
    output wire                     complete_o,
    output reg [VMAX_WIDTH-1:0]     result_raddr_o,
    output wire                     result_ren_o,
    output wire                     trans_complete_o
    );

    localparam                    IDLE = 3'b000,
                                  INIT = 3'b001,
                                  COMP = 3'b010,
                                  DONE = 3'b011,
                                  TRAN = 3'b100;
    reg        [2:0]              state;
    reg        [2:0]              next_state;
    reg        [PC_WIDTH-1:0]     inst_counter;
    
    // FSM
    // state update
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
        end else begin
            state <= next_state;
        end
    end 

    // next state logic
    always @(*)
    begin
        case (state)
            IDLE: begin
                if (ready_o && sop_i) begin
                    next_state = INIT;
                end
                else begin
                    next_state = IDLE;
                end
            end

            INIT: begin
                if (eop_i) begin
                    next_state = COMP;
                end
                else begin
                    next_state = INIT;
                end
            end

            COMP: begin
                if (complete_o) begin
                    next_state = DONE;
                end
                else begin
                    next_state = COMP;
                end
            end

            DONE: begin
                if (result_is_OK_o && ready_i)
                    next_state = TRAN;
                else begin
                    next_state = DONE;
                end
            end

            TRAN: begin
                if (trans_complete_o)
                    next_state = IDLE;
                else
                    next_state = TRAN;        
            end

            default: begin
                next_state = IDLE;
            end
        endcase
    end

    // output logic

    assign ready_o = (state == IDLE);
    assign is_working_o = (state == COMP);
    assign complete_o = (pc_current_i == inst_counter - 1) && (state == COMP);
    assign result_is_OK_o = (state == DONE);
    assign addr_out_o = addr_in_i;
    always @(*)
    begin
        if (state == INIT && valid_i) begin
            if(addr_in_i < SCALAR_BASE) begin
                wen_init_o = 3'b001;
            end
            else if (addr_in_i < VECTOR_BASE) begin
                wen_init_o = 3'b010;
            end
            else if (addr_in_i < VECTOR_UPPER) begin
                wen_init_o = 3'b100;
            end
            else begin
                wen_init_o = 3'b000;
            end
        end
        else begin
            wen_init_o = 3'b000;
        end
    end

    always@ (posedge clk or negedge rst_n)
    begin
        if(!rst_n) begin
            inst_counter <= 0;
        end
        else if (valid_i && state == INIT && wen_init_o[0]) begin
            inst_counter <= inst_counter + 1;
        end
        else if (complete_o) begin
            inst_counter <= 0;
        end
        else begin
            inst_counter <= inst_counter;
        end
    end

    always @(posedge clk or negedge rst_n)
    begin
        if (!rst_n) begin
            sop_o <= 0;
        end
        else if (sop_o == 0 && result_is_OK_o && ready_i) begin
            sop_o <= 1;
        end
        else if (sop_o == 1)
            sop_o <= 0;
        else begin
            sop_o <= sop_o;
        end
    end

    assign result_ren_o = (state == TRAN);

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) valid_o <= 0;
        else valid_o <= result_ren_o;
    end

    always @(posedge clk or negedge rst_n) begin
        if (~rst_n) result_raddr_o <= 0;
        else if (complete_o) result_raddr_o <= 0;
        else if (({1'b0,result_raddr_o} < result_cnt_i - 1) && (state == TRAN))  result_raddr_o <= result_raddr_o + 1;
        else if ({1'b0,result_raddr_o} == result_cnt_i - 1) result_raddr_o <= 0;
        else result_raddr_o <= result_raddr_o; 
    end

    assign trans_complete_o = ({1'b0,result_raddr_o} == (result_cnt_i - 1)) && (state == TRAN);
    reg eop_o_d;
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) eop_o_d <= 1'b0;
        else eop_o_d <= trans_complete_o;
    end

    always @(posedge clk or negedge rst_n) begin
        if (~rst_n) eop_o <= 1'b0;
        else eop_o <= eop_o_d;
    end

     


    


    
endmodule
