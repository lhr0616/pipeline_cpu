-- Copyright 1986-2019 Xilinx, Inc. All Rights Reserved.
-- --------------------------------------------------------------------------------
-- Tool Version: Vivado v.2019.2 (win64) Build 2708876 Wed Nov  6 21:40:23 MST 2019
-- Date        : Thu Aug 28 11:23:28 2025
-- Host        : Lary-ROG13 running 64-bit major release  (build 9200)
-- Command     : write_vhdl -force -mode synth_stub
--               D:/Lectures/RISCV/RISCV_FPGA_TrueDualPort_Example/RISCV_FPGA.srcs/sources_1/ip/clk_wiz_sys/clk_wiz_sys_stub.vhdl
-- Design      : clk_wiz_sys
-- Purpose     : Stub declaration of top-level module interface
-- Device      : xc7a100tfgg676-2
-- --------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity clk_wiz_sys is
  Port ( 
    clk_cpu : out STD_LOGIC;
    locked : out STD_LOGIC;
    clk_in1 : in STD_LOGIC
  );

end clk_wiz_sys;

architecture stub of clk_wiz_sys is
attribute syn_black_box : boolean;
attribute black_box_pad_pin : string;
attribute syn_black_box of stub : architecture is true;
attribute black_box_pad_pin of stub : architecture is "clk_cpu,locked,clk_in1";
begin
end;
