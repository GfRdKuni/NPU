`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2025/06/17 11:46:12
// Design Name: 
// Module Name: NPU_top
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


module NPU_top#
(
    parameter DATA_WIDTH  = 16,
    parameter INST_LEN    = 16,
    parameter ADDR_WIDTH  = 16,
    parameter PC_WIDTH    = 8,
    parameter ACTUAL_ADDR = 8,
    parameter VMAX        = 8,
    parameter VMAX_WIDTH  = $clog2(VMAX),
    parameter SCALAR_BASE = 16'h0100, // 256
    parameter VECTOR_BASE = 16'h0200, // 512
    parameter OPCODE_LEN = 3,
    parameter REG_LEN  = 4,
    parameter SIMM_LEN = 5,
    parameter LIMM_LEN = 8
)
(
    input wire                   clk,
    input wire                   rst_n,

    // Input Side Interface
    input wire                   valid_i,
    input wire                   sop_i,
    input wire                   eop_i,
    output wire                  ready_o,
    input wire [DATA_WIDTH-1:0]  data_in_i,
    input wire [ADDR_WIDTH-1:0]  addr_in_i, // Address Mapping!

    // Output Side Interface

    output wire                       valid_o,
    input wire                        ready_i,
    output wire                       sop_o,
    output wire                       eop_o,
    output wire                       result_is_OK_o
    );
    localparam OPCODE_LOAD = 3'b000;
    localparam OPCODE_STORE = 3'b001;
    localparam OPCODE_MOV = 3'b010;
    localparam OPCODE_VLOAD = 3'b100;
    localparam OPCODE_VSTORE = 3'b101;
    localparam OPCODE_VMAC = 3'b110;
    wire [PC_WIDTH-1:0]          PC;
    wire                         complete;
    wire                         is_working;
    wire [ADDR_WIDTH-1:0]        w_addr_init;
    wire                         icm_wen_init, scalar_mem_wen_init, vector_mem_wen_init;
    wire [INST_LEN-1:0]          current_inst;
    wire [DATA_WIDTH/2-1:0]      vlen;
    reg  [DATA_WIDTH-1:0]        result_addr[VMAX-1:0];
    reg  [VMAX_WIDTH  :0]        result_cnt;
    wire [VMAX_WIDTH-1:0]        result_raddr_cnt;
    wire                         result_ren;
    wire                         trans_complete;
    wire [DATA_WIDTH-1:0]        stage_4_Scalar_Mem_rdata;
    wire [DATA_WIDTH*VMAX-1:0]   stage_4_Vector_Mem_rdata;
    wire [DATA_WIDTH*VMAX-1:0]   stage_4_vrd_data_result;
    wire [OPCODE_LEN-1:0]        stage_4_opcode;
    wire [LIMM_LEN-1:0]          stage_4_long_imm;
    wire                         stage_4_is_working;
    wire                         stage_4_func;
    wire [REG_LEN-1:0]           stage_4_rd;
    wire [VMAX-1:0]              vmask;
    (* DONT_TOUCH = "TRUE" *) reg  [DATA_WIDTH*VMAX-1:0]   data_out_o;

    
    CU u_CU
    (
        .clk              (clk),
        .rst_n            (rst_n),
        .valid_i          (valid_i),
        .sop_i            (sop_i),
        .eop_i            (eop_i),
        .ready_i          (ready_i),
        .addr_in_i        (addr_in_i),
        .pc_current_i     (PC),
        .result_cnt_i     (result_cnt),
        .result_is_OK_o   (result_is_OK_o),
        .valid_o          (valid_o),
        .ready_o          (ready_o),
        .sop_o            (sop_o),
        .eop_o            (eop_o),
        .addr_out_o       (w_addr_init),
        .wen_init_o       ({vector_mem_wen_init,scalar_mem_wen_init,icm_wen_init}), // {Vector_wen, Scalar_wen, Inst_wen} 
        .is_working_o     (is_working),
        .complete_o       (complete),
        .result_raddr_o   (result_raddr_cnt),
        .result_ren_o     (result_ren),
        .trans_complete_o (trans_complete)
    );
    // Stage 1 instruction fetch
    inst_launcher u_inst_launcher
    (
        .clk        (clk),
        .rst_n      (rst_n),
        .complete   (complete),
        .is_working (is_working),
        .PC         (PC)
    );
    
    Mem#(
        .MEM_ADDR_WIDTH (PC_WIDTH)
    )
    ICM 
    (
        .clk        (clk),
        .rst_n      (rst_n),
        .raddr_i    (PC),
        .waddr_i    (w_addr_init[PC_WIDTH-1:0]),
        .wen_i      (icm_wen_init),
        .ren_i      (is_working),
        .wdata_i    (data_in_i),
        .rdata_o    (current_inst)
    );
    // Registers between stage1 & stage2
    wire [INST_LEN-1:0] stage_2_inst;
    wire stage_2_is_working;

    dff #(
        .WIDTH(INST_LEN)
    ) 
    dff_between_stage1_2
    (
        .clk(clk),
        .rst_n(rst_n),
        .en_i(is_working),
        .d_i(current_inst),
        .q_o(stage_2_inst)
    );

    dff #(
        .WIDTH(1)
    )
    dff_between_stage1_3(
        .clk(clk),
        .rst_n(rst_n),
        .en_i(is_working),
        .d_i(is_working), 
        .q_o(stage_2_is_working)  
    );
    // Stage 2 instruction decoding & Oprands fetch & imm generation
    wire [OPCODE_LEN-1:0] opcode;
    wire [REG_LEN-1:0] rd, rs1, rs2;
    wire [SIMM_LEN-1:0] short_imm;
    wire [LIMM_LEN-1:0] long_imm;
    wire func;
    wire [DATA_WIDTH-1:0] rs1_data, rs2_data;
    wire [DATA_WIDTH*VMAX-1:0] rs2_vector;
    wire [2:0]forward_flag;

    decoder u_decoder
    (
        .clk(clk),
        .rst_n(rst_n),
        .inst_i(stage_2_inst),
        .opcode_o(opcode),
        .rd_o(rd),
        .rs1_o(rs1),
        .rs2_o(rs2),
        .short_imm_o(short_imm),
        .long_imm_o(long_imm),
        .func_o(func),
        .forward_flag_o(forward_flag)
    );
    wire [DATA_WIDTH-1:0]Scalar_WB;
    Scalar_RF u_Scalar_RF(
        .clk(clk),
        .rst_n(rst_n),
        .rs1_i(rs1),
        .rs2_i(rs2),
        .rd_i(stage_4_rd),
        .wen_i(stage_4_opcode == OPCODE_MOV || stage_4_opcode == OPCODE_LOAD), // TODO: the expression is incomplete
        .rd_data_i(Scalar_WB), // TODO: the expression is incomplete
        .func_i({stage_4_opcode == OPCODE_MOV, stage_4_func}),
        .rs1_data_o(rs1_data),
        .rs2_data_o(rs2_data),
        .vlen(vlen),
        .vmask_o(vmask)
    );

    assign Scalar_WB = (stage_4_opcode == OPCODE_LOAD) ? stage_4_Scalar_Mem_rdata : (stage_4_func ? {stage_4_long_imm, {8{1'b0}}} : {{8{1'b0}}, stage_4_long_imm});
    
    wire [DATA_WIDTH*VMAX-1:0] Vector_WB;
    Vector_RF u_vector_RF(
        .clk(clk),
        .rst_n(rst_n),
        .rs_i(rs2),
        .rd_i(stage_4_rd),  
        .wen_i(stage_4_opcode == OPCODE_VLOAD || stage_4_opcode == OPCODE_VMAC), // TODO: the expression is incomplete
        .rd_data_i(Vector_WB), // TODO: the expression is incomplete
        .rs_data_o(rs2_vector)
    );
    assign Vector_WB = (stage_4_opcode == OPCODE_VLOAD) ? stage_4_Vector_Mem_rdata : stage_4_vrd_data_result;

    // Registers between stage2 & stage3
    wire [OPCODE_LEN-1:0] stage_3_opcode;
    wire [DATA_WIDTH-1:0] stage_3_rs1_data, stage_3_rs2_data;
    wire [DATA_WIDTH*VMAX-1:0] stage_3_rs2_vector;
    wire [LIMM_LEN-1:0] stage_3_long_imm;
    wire [SIMM_LEN-1:0] stage_3_short_imm;
    wire stage_3_func;
    wire stage_3_is_working;
    wire [REG_LEN-1:0]stage_3_rd;
    wire [2:0] stage_3_forward_flag;

    dff#(
        .WIDTH(OPCODE_LEN)
    ) dff_between_stage2_3_1(
        .clk(clk),
        .rst_n(rst_n),
        .en_i(stage_2_is_working),
        .d_i(opcode), 
        .q_o(stage_3_opcode)  
    );

    dff#(
        .WIDTH(DATA_WIDTH)
    ) dff_between_stage2_3_2(
        .clk(clk),
        .rst_n(rst_n),
        .en_i(stage_2_is_working),
        .d_i(rs1_data), 
        .q_o(stage_3_rs1_data)  
    );

    dff#(
        .WIDTH(DATA_WIDTH)
    ) dff_between_stage2_3_3(
        .clk(clk),
        .rst_n(rst_n),
        .en_i(stage_2_is_working),
        .d_i(rs2_data),
        .q_o(stage_3_rs2_data)  
    );

    dff#(
        .WIDTH(DATA_WIDTH*VMAX)
    ) dff_between_stage2_3_4(
        .clk(clk),
        .rst_n(rst_n),
        .en_i(stage_2_is_working),
        .d_i(rs2_vector), 
        .q_o(stage_3_rs2_vector)  
    );

    dff#(
        .WIDTH(LIMM_LEN)
    ) dff_between_stage2_3_5(
        .clk(clk),
        .rst_n(rst_n),
        .en_i(stage_2_is_working),
        .d_i(long_imm), 
        .q_o(stage_3_long_imm)  
    );

    dff#(
        .WIDTH(SIMM_LEN)
    ) dff_between_stage2_3_6(
        .clk(clk),
        .rst_n(rst_n),
        .en_i(stage_2_is_working),
        .d_i(short_imm), 
        .q_o(stage_3_short_imm)  
    );

    dff#(
        .WIDTH(1)
    ) dff_between_stage2_3_7(
        .clk(clk),
        .rst_n(rst_n),
        .en_i(stage_2_is_working),
        .d_i(func), 
        .q_o(stage_3_func)
    );

    dff#(
        .WIDTH(1)
    ) dff_between_stage2_3_8(
        .clk(clk),
        .rst_n(rst_n),
        .en_i(stage_2_is_working),
        .d_i(1'b1), 
        .q_o(stage_3_is_working)  
    );

    dff#(
        .WIDTH(REG_LEN)
    ) dff_between_stage2_3_9(
        .clk(clk),
        .rst_n(rst_n),
        .en_i(stage_2_is_working),
        .d_i(rd), 
        .q_o(stage_3_rd)  
    );

    dff#(
        .WIDTH(3)
    ) dff_between_stage2_3_10(
        .clk(clk),
        .rst_n(rst_n),
        .en_i(stage_2_is_working),
        .d_i(forward_flag), 
        .q_o(stage_3_forward_flag)  
    );

    // Stage 3 Memory Access / MAC
    wire [DATA_WIDTH-1:0] modified_rs1_data;
    wire [DATA_WIDTH-1:0] modified_rs2_data;
    wire [DATA_WIDTH*VMAX-1:0] modified_rs2_vector;
    assign modified_rs1_data = (stage_3_forward_flag[1:0] == 2'b11) ? (stage_3_forward_flag[2] ? stage_4_long_imm : stage_4_Scalar_Mem_rdata) : stage_3_rs1_data;
    assign modified_rs2_data = (stage_3_forward_flag[1:0] == 2'b01) ? (stage_3_forward_flag[2] ? stage_4_long_imm : stage_4_Scalar_Mem_rdata) : stage_3_rs2_data;
    assign modified_rs2_vector = (stage_3_forward_flag[1:0] == 2'b01) ? (stage_3_forward_flag[2] ? stage_4_vrd_data_result : stage_4_Vector_Mem_rdata) : stage_3_rs2_vector;
    // Scalar Memory
    wire [ADDR_WIDTH-1:0] Scalar_Mem_waddr;
    wire [ADDR_WIDTH-1:0] Scalar_Mem_raddr;
    wire [DATA_WIDTH-1:0] Scalar_Mem_wdata;
    wire [DATA_WIDTH-1:0] Scalar_Mem_rdata;
    wire Scalar_Mem_wen,  Scalar_Mem_ren;
    wire [ADDR_WIDTH-1:0] Modified_Scalar_Mem_waddr;
    wire [ADDR_WIDTH-1:0] Modified_Scalar_Mem_raddr;
    Mem#(
        .MEM_ADDR_WIDTH(ACTUAL_ADDR)
    )
     scalar_mem
    (
        .clk(clk),
        .rst_n(rst_n),
        .raddr_i(Modified_Scalar_Mem_raddr[ACTUAL_ADDR-1:0]),
        .waddr_i(Modified_Scalar_Mem_waddr[ACTUAL_ADDR-1:0]),
        .wen_i(Scalar_Mem_wen),
        .ren_i(Scalar_Mem_ren), // Read is pure
        .wdata_i(Scalar_Mem_wdata),
        .rdata_o(Scalar_Mem_rdata)
    );
    assign Scalar_Mem_wen = scalar_mem_wen_init || (stage_3_opcode == 3'b001); // TODO: the expression is incomplete
    assign Scalar_Mem_ren = (stage_3_opcode[1:0] == 2'b00);                 // TODO: the expression is incomplete
    assign Scalar_Mem_waddr = scalar_mem_wen_init ? w_addr_init : modified_rs1_data; 
    assign Modified_Scalar_Mem_waddr = Scalar_Mem_waddr - SCALAR_BASE;
    assign Modified_Scalar_Mem_raddr = Scalar_Mem_raddr - SCALAR_BASE;
    assign Scalar_Mem_raddr = modified_rs1_data + stage_3_short_imm;
    assign Scalar_Mem_wdata = w_addr_init ? data_in_i : modified_rs2_data;
    
    // Vector Memory
    wire [ADDR_WIDTH-1:0]        Vector_Mem_waddr;
    wire [ADDR_WIDTH-1:0]        Vector_Mem_raddr;
    wire [DATA_WIDTH-1:0]        Vector_Mem_wdata;
    wire [DATA_WIDTH * VMAX-1:0] Vector_Mem_rdata;
    wire Vector_Mem_wen,  Vector_Mem_ren;
    wire [ADDR_WIDTH-1:0]        Modified_Vector_Mem_waddr;
    wire [ADDR_WIDTH-1:0]        Modified_Vector_Mem_raddr;
    Vector_Mem#(
        .ADDR_WIDTH(ACTUAL_ADDR)
    ) vector_mem(
        .clk(clk),
        .rst_n(rst_n),
        .raddr_i(Modified_Vector_Mem_raddr[ACTUAL_ADDR-1:0]), // read is pure
        .waddr_i(Modified_Vector_Mem_waddr[ACTUAL_ADDR-1:0]),
        .wen_i(Vector_Mem_wen),
        .ren_i(Vector_Mem_ren),
        .is_working_i(stage_3_is_working),
        .wdata_scalar_i(data_in_i),
        .wdata_vector_i(modified_rs2_vector),
        .rdata_o(Vector_Mem_rdata)
    );
    assign Modified_Vector_Mem_raddr = Vector_Mem_raddr - VECTOR_BASE;
    assign Modified_Vector_Mem_waddr = Vector_Mem_waddr - VECTOR_BASE;
    always @(posedge clk or negedge rst_n) begin
        if (~rst_n) data_out_o <= 0;
        else if (result_ren) data_out_o <= Vector_Mem_rdata & {{16{vmask[7]}}, {16{vmask[6]}}, {16{vmask[5]}}, {16{vmask[4]}}, {16{vmask[3]}}, {16{vmask[2]}}, {16{vmask[1]}}, {16{vmask[0]}}};
        else data_out_o <= 0;
    end
    integer i;
    always @ (posedge clk or negedge rst_n)
    begin
        if (~rst_n) begin
            for (i = 0; i < VMAX; i = i + 1) begin
                result_addr[i] <= 0;
            end
        end
        else if (stage_3_is_working && (stage_3_opcode == 3'b101)) begin
            result_addr[result_cnt[2:0]] <= Vector_Mem_waddr;
        end
        else begin
            for (i = 0; i < VMAX; i = i + 1) begin
                result_addr[i] <= result_addr[i];
            end
        end     
    end

    always @ (posedge clk or negedge rst_n)
    begin
        if (~rst_n) begin
            result_cnt <= 4'b0000;
        end
        else if (stage_3_is_working && (stage_3_opcode == 3'b101)) begin
            result_cnt <= result_cnt + 1;
        end
        else if (trans_complete) begin
            result_cnt <= 4'b0000;
        end 
        else begin
            result_cnt <= result_cnt;
        end     
    end

    assign Vector_Mem_wen = vector_mem_wen_init || (stage_3_opcode == 3'b101); // TODO: the expression is incomplete
    assign Vector_Mem_ren = (stage_3_opcode[1:0] == 2'b00) || result_ren;                                              // TODO: the expression is incomplete
    assign Vector_Mem_waddr = vector_mem_wen_init ? w_addr_init : modified_rs1_data;
    assign Vector_Mem_raddr = (result_ren) ? result_addr[result_raddr_cnt] : modified_rs1_data + stage_3_short_imm;
    

    // Stage 3 MAC
    wire [DATA_WIDTH*VMAX-1:0]vrd_data_result;
    wire activated;
    assign activated = (stage_3_opcode == OPCODE_VMAC) && (stage_3_is_working);
    MAC mac_0
    (
        .clk(clk),
        .rst_n(rst_n),
        .rs1_i(modified_rs1_data),
        .rs2_i(modified_rs2_vector[DATA_WIDTH-1:0]),
        .func_i(stage_3_func),
        .activated_i(activated),
        .vrd_data_o(vrd_data_result[DATA_WIDTH-1:0])
    );

    MAC mac_1
    (
        .clk(clk),
        .rst_n(rst_n),
        .rs1_i(modified_rs1_data),
        .rs2_i(modified_rs2_vector[DATA_WIDTH*2-1:DATA_WIDTH]),
        .func_i(stage_3_func),
        .activated_i(activated),
        .vrd_data_o(vrd_data_result[DATA_WIDTH*2-1:DATA_WIDTH])
    );

    MAC mac_2
    (
        .clk(clk),
        .rst_n(rst_n),
        .rs1_i(modified_rs1_data),
        .rs2_i(modified_rs2_vector[DATA_WIDTH*3-1:DATA_WIDTH*2]),
        .func_i(stage_3_func),
        .activated_i(activated),
        .vrd_data_o(vrd_data_result[DATA_WIDTH*3-1:DATA_WIDTH*2])
    );

    MAC mac_3
    (
        .clk(clk),
        .rst_n(rst_n),
        .rs1_i(modified_rs1_data),
        .rs2_i(modified_rs2_vector[DATA_WIDTH*4-1:DATA_WIDTH*3]),
        .func_i(stage_3_func),
        .activated_i(activated),
        .vrd_data_o(vrd_data_result[DATA_WIDTH*4-1:DATA_WIDTH*3])
    );

    MAC mac_4
    (
        .clk(clk),
        .rst_n(rst_n),
        .rs1_i(modified_rs1_data),
        .rs2_i(modified_rs2_vector[DATA_WIDTH*5-1:DATA_WIDTH*4]),
        .func_i(stage_3_func),
        .activated_i(activated),
        .vrd_data_o(vrd_data_result[DATA_WIDTH*5-1:DATA_WIDTH*4])
    );

    MAC mac_5
    (
        .clk(clk),
        .rst_n(rst_n),
        .rs1_i(modified_rs1_data),
        .rs2_i(modified_rs2_vector[DATA_WIDTH*6-1:DATA_WIDTH*5]),
        .func_i(stage_3_func),
        .activated_i(activated),
        .vrd_data_o(vrd_data_result[DATA_WIDTH*6-1:DATA_WIDTH*5])
    );

    MAC mac_6
    (
        .clk(clk),
        .rst_n(rst_n),
        .rs1_i(modified_rs1_data),
        .rs2_i(modified_rs2_vector[DATA_WIDTH*7-1:DATA_WIDTH*6]),
        .func_i(stage_3_func),
        .activated_i(activated),
        .vrd_data_o(vrd_data_result[DATA_WIDTH*7-1:DATA_WIDTH*6])
    );

    MAC mac_7
    (
        .clk(clk),
        .rst_n(rst_n),
        .rs1_i(modified_rs1_data),
        .rs2_i(modified_rs2_vector[DATA_WIDTH*8-1:DATA_WIDTH*7]),
        .func_i(stage_3_func),
        .activated_i(activated),
        .vrd_data_o(vrd_data_result[DATA_WIDTH*8-1:DATA_WIDTH*7])
    );
    
    // register between stage 3 and stage 4
    

    dff#(
        .WIDTH(DATA_WIDTH) 
    ) dff_between_stage3_4_1(
        .clk(clk),
        .rst_n(rst_n),
        .en_i(stage_3_is_working),
        .d_i(Scalar_Mem_rdata), 
        .q_o(stage_4_Scalar_Mem_rdata)  
    );

    dff#(
        .WIDTH(DATA_WIDTH * VMAX) 
    ) dff_between_stage3_4_2(
        .clk(clk),
        .rst_n(rst_n),
        .en_i(stage_3_is_working),
        .d_i(Vector_Mem_rdata), 
        .q_o(stage_4_Vector_Mem_rdata)  
    );

    dff#(
        .WIDTH(DATA_WIDTH * VMAX)
    ) dff_between_stage3_4_3(
        .clk(clk),
        .rst_n(rst_n),
        .en_i(stage_3_is_working),
        .d_i(vrd_data_result),
        .q_o(stage_4_vrd_data_result)  
    );

    dff#(
        .WIDTH(OPCODE_LEN)
    ) dff_between_stage3_4_4(
        .clk(clk),
        .rst_n(rst_n),
        .en_i(stage_3_is_working),
        .d_i(stage_3_opcode),
        .q_o(stage_4_opcode)  
    );

    dff#(
        .WIDTH(LIMM_LEN)
    ) dff_between_stage3_4_5(
        .clk(clk),
        .rst_n(rst_n),
        .en_i(stage_3_is_working),
        .d_i(stage_3_long_imm),
        .q_o(stage_4_long_imm)  
    );

    dff#(
        .WIDTH(1)
    ) dff_between_stage3_4_6(
        .clk(clk),
        .rst_n(rst_n),
        .en_i(stage_3_is_working),
        .d_i(stage_3_func),
        .q_o(stage_4_func)  
    );

    dff#(
        .WIDTH(1)
    ) dff_between_stage3_4_7(
        .clk(clk),
        .rst_n(rst_n),
        .en_i(stage_3_is_working),
        .d_i(stage_3_is_working),
        .q_o(stage_4_is_working)  
    );

    dff#(
        .WIDTH(REG_LEN)
    )
    dff_between_stage3_4_8(
        .clk(clk),
        .rst_n(rst_n),
        .en_i(stage_3_is_working),
        .d_i(stage_3_rd),
        .q_o(stage_4_rd)  
    );

    // Stage 4 Result WB
    // This part is merged with the Stage 2




endmodule
