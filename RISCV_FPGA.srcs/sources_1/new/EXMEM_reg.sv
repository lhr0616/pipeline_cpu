`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2026/03/27 15:06:26
// Design Name: 
// Module Name: EXMEM_reg
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


module EXMEM_reg #(
    parameter bitwidth = 32
)(
    input clk,
    input rst_n,
    input en,
    input flush,
    input id_ex_reg_wr_src, id_ex_pc_gen_to_reg,
    input [bitwidth-1:0] id_ex_imm, id_ex_pc_gen_data, alu_data_out, id_ex_reg_rd_dout_2,
    input id_ex_reg_wr_en, id_ex_data_bram_wr_en, id_ex_data_bram_rd_en,
    input [4:0] id_ex_reg_wr_idx,
    input [3:0] id_ex_data_bram_wr_byte_mask,
    input id_ex_mem_unsigned,
    output logic [bitwidth-1:0] ex_mem_imm, ex_mem_pc_gen_data,
    output logic ex_mem_reg_wr_src, ex_mem_pc_gen_to_reg,
    output logic [bitwidth-1:0] ex_mem_alu_data_out, ex_mem_reg_rd_dout_2,
    output logic [3:0] ex_mem_data_bram_wr_byte_mask,
    output logic ex_mem_reg_wr_en, ex_mem_data_bram_wr_en, ex_mem_data_bram_rd_en,
    output logic [4:0] ex_mem_reg_wr_idx,
    output logic ex_mem_mem_unsigned
    );
    always @(posedge clk) begin
        if (!rst_n) begin
            ex_mem_imm <= {bitwidth{1'b0}};
            ex_mem_pc_gen_data <= {bitwidth{1'b0}};
            ex_mem_reg_wr_src <= 1'b0;
            ex_mem_pc_gen_to_reg <= 1'b0;
            ex_mem_alu_data_out <= {bitwidth{1'b0}};
            ex_mem_reg_rd_dout_2 <= {bitwidth{1'b0}};
            ex_mem_data_bram_wr_byte_mask <= 4'b0000;
            ex_mem_reg_wr_en <= 1'b0;
            ex_mem_data_bram_wr_en <= 1'b0;
            ex_mem_data_bram_rd_en <= 1'b0;
            ex_mem_reg_wr_idx <= 5'b00000;
            ex_mem_mem_unsigned <= 1'b0;
        end else if (flush) begin
            ex_mem_imm <= {bitwidth{1'b0}};
            ex_mem_pc_gen_data <= {bitwidth{1'b0}};
            ex_mem_reg_wr_src <= 1'b0;
            ex_mem_pc_gen_to_reg <= 1'b0;
            ex_mem_alu_data_out <= {bitwidth{1'b0}};
            ex_mem_reg_rd_dout_2 <= {bitwidth{1'b0}};
            ex_mem_data_bram_wr_byte_mask <= 4'b0000;
            ex_mem_reg_wr_en <= 1'b0;
            ex_mem_data_bram_wr_en <= 1'b0;
            ex_mem_data_bram_rd_en <= 1'b0;
            ex_mem_reg_wr_idx <= 5'b00000;
            ex_mem_mem_unsigned <= 1'b0;
        end else if (en) begin
            ex_mem_imm <= id_ex_imm;
            ex_mem_pc_gen_data <= id_ex_pc_gen_data;
            ex_mem_reg_wr_src <= id_ex_reg_wr_src;
            ex_mem_pc_gen_to_reg <= id_ex_pc_gen_to_reg;
            ex_mem_alu_data_out <= alu_data_out;
            ex_mem_reg_rd_dout_2 <= id_ex_reg_rd_dout_2;
            ex_mem_data_bram_wr_byte_mask <= id_ex_data_bram_wr_byte_mask;
            ex_mem_reg_wr_en <= id_ex_reg_wr_en;
            ex_mem_data_bram_wr_en <= id_ex_data_bram_wr_en;
            ex_mem_data_bram_rd_en <= id_ex_data_bram_rd_en;
            ex_mem_reg_wr_idx <= id_ex_reg_wr_idx;
            ex_mem_mem_unsigned <= id_ex_mem_unsigned;
        end
    end
endmodule
