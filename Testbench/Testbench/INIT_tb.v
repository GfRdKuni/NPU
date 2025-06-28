`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2025/06/17 19:04:48
// Module Name: INIT_tb
//////////////////////////////////////////////////////////////////////////////////

module INIT_tb();

parameter DATA_WIDTH = 16;
parameter ADDR_WIDTH = 16;
parameter NUM_CYCLES = 440; // opt:384 old:440

reg clk;
reg rst_n;
reg valid_i;
reg sop_i;
reg eop_i;
wire ready_o;
reg [15:0] data_in_i;
reg [15:0] addr_in_i;
wire valid_o;
reg ready_i;
wire sop_o;
wire eop_o;
wire result_is_OK_o;


reg [0:0]             valid_mem [0:NUM_CYCLES-1];
reg [DATA_WIDTH-1:0]  data_mem  [0:NUM_CYCLES-1];
reg [ADDR_WIDTH-1:0]  addr_mem  [0:NUM_CYCLES-1];
integer i;
integer file, r;

integer log_file;

real CYCLE_100MHz = 10; 

always begin
    clk = 0; #(CYCLE_100MHz/2);
    clk = 1; #(CYCLE_100MHz/2);
end

initial begin
    rst_n = 0;
    #(2 * CYCLE_100MHz);
    rst_n = 1;
end

initial begin
    file = $fopen("D:/Xilinx_Vivado_SDK_2019.1_0524_1430/NPU/NPU.srcs/sources_1/new/final.txt", "r");
    if (file == 0) begin
        $fatal("Cannot open stimulus file.");
    end
    for (i = 0; i < NUM_CYCLES; i = i + 1) begin
        r = $fscanf(file, "%b %h %h\n", valid_mem[i], data_mem[i], addr_mem[i]);
        if (r != 3) begin
            $fatal("Error reading line %0d from stimulus file.", i);
        end
    end
    $fclose(file);
end

always @(posedge clk) begin
    if (valid_o) begin
        $display("Time=%0t: valid_o=1, data_out_o=0x%0h", $time, u_top.data_out_o);
    end
end

initial begin
    valid_i = 0;
    sop_i = 0;
    eop_i = 0;
    data_in_i = 0;
    addr_in_i = 0;
    ready_i = 0;
    wait(rst_n);
    #(2*CYCLE_100MHz);
    sop_i = 1;
    #(CYCLE_100MHz);
    sop_i = 0;
    for (i = 0; i < NUM_CYCLES; i = i + 1) begin
        @(negedge clk);
        valid_i   = valid_mem[i];
        data_in_i = data_mem[i];
        addr_in_i = addr_mem[i];
    end
    #(CYCLE_100MHz);
    valid_i = 0;
    eop_i = 1;
    #(CYCLE_100MHz);
    sop_i = 0;
    eop_i = 0;
    data_in_i = 0;
    addr_in_i = 0;

    wait(result_is_OK_o);
    #(2*CYCLE_100MHz + 1);
    ready_i = 1;
    #(CYCLE_100MHz);
    ready_i = 0;

    // ??????
    $fclose(log_file);
    $finish();
end



// DUT ???
NPU_top u_top (
    .clk(clk),
    .rst_n(rst_n),
    .valid_i(valid_i),
    .sop_i(sop_i),
    .eop_i(eop_i),
    .ready_o(ready_o),
    .data_in_i(data_in_i),
    .addr_in_i(addr_in_i), 
    .valid_o(valid_o),
    .ready_i(ready_i),
    .sop_o(sop_o),
    .eop_o(eop_o),
    .result_is_OK_o(result_is_OK_o)
);

endmodule
