`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2021/09/27 15:59:44
// Design Name: 
// Module Name: riscv_mcu_top
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


module riscv_mcu_tdpram_top#(
    parameter bitwidth = 32
    )(
    input CLK_FPGA,
    inout [31:0] PA
    );
    
    wire clk_cpu, dcm_locked;
    clk_wiz_sys clk_wiz_sys_inst(
      // Clock out ports
      .clk_cpu(clk_cpu),     // output clk_cpu
      // Status and control signals
      .locked(dcm_locked),       // output locked
     // Clock in ports
      .clk_in1(CLK_FPGA)     // input clk_in1
    );
    
    localparam DATA_BASE = 32'h4000_0000;
    localparam DATA_SIZE_BYTES = 32'h0010_0000;
    wire [bitwidth-1:0] inst_bram_rd_data;
    wire [bitwidth-1:0] inst_bram_addr;
    reg [bitwidth-1:0] data_bram_rd_data;
    wire [bitwidth-1:0] data_bram_addr;
    wire [bitwidth-1:0] data_bram_wr_data;
    wire [3:0] data_bram_wr_byte_mask, data_bram_wr_byte_mask_mux;
    wire data_bram_wr_en, data_bram_rd_en;
    riscv_cpu #(
      .bitwidth(bitwidth)
    ) riscv_cpu_inst (
      .clk(clk_cpu),
      .rst_n(dcm_locked),
      .inst(inst_bram_rd_data),
      .inst_bram_addr(inst_bram_addr),
      .data_bram_rd_data(data_bram_rd_data),
      .data_bram_addr(data_bram_addr),
      .data_bram_wr_data(data_bram_wr_data),
      .data_bram_wr_byte_mask(data_bram_wr_byte_mask),
      .data_bram_wr_en(data_bram_wr_en),
      .data_bram_rd_en(data_bram_rd_en)
    );

    wire [bitwidth-1:0] data_bram_addr_off;
    assign data_bram_addr_off = (data_bram_addr[31:28] == 4'h4) ? (data_bram_addr - DATA_BASE) : data_bram_addr;
    wire data_bram_addr_in_range;
    assign data_bram_addr_in_range = (data_bram_addr_off < DATA_SIZE_BYTES);
    assign data_bram_wr_byte_mask_mux = (data_bram_wr_en && data_bram_addr_in_range) ? data_bram_wr_byte_mask : 4'b0000;

    wire [bitwidth-1:0] data_bram_dout;
    
    tdp_bram inst_bram_inst (
      .clka(clk_cpu),
      .ena(1'b1),
      .wea(4'b0000),
      .addra(inst_bram_addr[bitwidth-1:2]),
      .dina(32'b0),
      .douta(inst_bram_rd_data),
      .clkb(clk_cpu),
      .enb(1'b0),
      .web(4'b0000),
      .addrb({(bitwidth-2){1'b0}}),
      .dinb(32'b0),
      .doutb()
    );

    tdp_bram data_bram_inst (
      .clka(clk_cpu),
      .ena(1'b0),
      .wea(4'b0000),
      .addra({(bitwidth-2){1'b0}}),
      .dina(32'b0),
      .douta(),
      .clkb(clk_cpu),
      .enb(data_bram_addr_in_range),
      .web(data_bram_wr_byte_mask_mux),
      .addrb(data_bram_addr_off[bitwidth-1:2]),
      .dinb(data_bram_wr_data),
      .doutb(data_bram_dout)
    );
    
    reg [bitwidth-1:0] data_bram_addr_r1 = 0;
    reg data_bram_rd_en_r1 = 0;
    reg [bitwidth-1:0] pout = 0, pa_t = 32'hffffffff;
    always @(posedge clk_cpu) begin
      data_bram_addr_r1 <= data_bram_addr;
      data_bram_rd_en_r1 <= data_bram_rd_en;
    end
    always @(posedge clk_cpu) begin
      if (data_bram_wr_en && (data_bram_addr == 32'h80000000)) pout <= data_bram_wr_data[31:0];
      else pout <= pout;
    end
    always @(posedge clk_cpu) begin
      if (data_bram_wr_en && (data_bram_addr == 32'h80000004)) pa_t <= data_bram_wr_data[31:0];
      else pa_t <= pa_t;
    end
    
    genvar i;
    generate
      for (i = 0; i < bitwidth; i = i + 1) begin: port_loop
        assign PA[i] = pa_t[i] ? 1'bz : pout[i];
      end
    endgenerate
    
    reg [bitwidth-1:0] pin_r = 0;
    always @(posedge clk_cpu) begin
      pin_r <= PA;
    end
    always @(*) begin
      if (data_bram_rd_en_r1 && (data_bram_addr_r1 == 32'h80000000)) data_bram_rd_data = pin_r;
      else if (data_bram_addr_in_range) data_bram_rd_data = data_bram_dout;
      else data_bram_rd_data = 0;
    end
endmodule
