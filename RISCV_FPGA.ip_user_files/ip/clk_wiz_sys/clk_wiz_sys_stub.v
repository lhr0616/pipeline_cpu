// Copyright 1986-2019 Xilinx, Inc. All Rights Reserved.
// --------------------------------------------------------------------------------
// Tool Version: Vivado v.2019.2 (win64) Build 2708876 Wed Nov  6 21:40:23 MST 2019
// Date        : Thu Aug 28 11:23:28 2025
// Host        : Lary-ROG13 running 64-bit major release  (build 9200)
// Command     : write_verilog -force -mode synth_stub
//               D:/Lectures/RISCV/RISCV_FPGA_TrueDualPort_Example/RISCV_FPGA.srcs/sources_1/ip/clk_wiz_sys/clk_wiz_sys_stub.v
// Design      : clk_wiz_sys
// Purpose     : Stub declaration of top-level module interface
// Device      : xc7a100tfgg676-2
// --------------------------------------------------------------------------------

// This empty module with port declaration file causes synthesis tools to infer a black box for IP.
// The synthesis directives are for Synopsys Synplify support to prevent IO buffer insertion.
// Please paste the declaration into a Verilog source file or add the file as an additional source.
module clk_wiz_sys(clk_cpu, locked, clk_in1)
/* synthesis syn_black_box black_box_pad_pin="clk_cpu,locked,clk_in1" */;
  output clk_cpu;
  output locked;
  input clk_in1;
endmodule
