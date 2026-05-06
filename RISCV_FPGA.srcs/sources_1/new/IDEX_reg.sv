`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2026/03/27 15:06:26
// Design Name: 
// Module Name: IDEX_reg
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


module IDEX_reg #(
    parameter bitwidth = 32
)(
    input clk,
    input rst_n,
    input en,
    input alu_src_b_is_imm,
    input [bitwidth-1:0] imm,
    input [4:0] branch_opcode,
    input mem_read_en,
    input mem_write_en,
    input mem_to_reg,
    input reg_write_en,
    input reg_wr_src, pc_gen_to_reg,
    input [3:0] alu_ctl,
    input [1:0] alu_src_a_sel,
    input [bitwidth-1:0] reg_dout_1,
    input [bitwidth-1:0] reg_dout_2,
    input [4:0] reg_wr_idx, rs1_idx, rs2_idx,
    input [bitwidth-1:0] pc_gen_data,
    input [bitwidth-1:0] pc_next, pc, pc_i,
    input [3:0] mem_byte_mask,
    input mem_unsigned,
    input forward_d,
    input flush,
    output logic id_ex_reg_wr_en,
    output logic [4:0] id_ex_reg_wr_idx, id_ex_rs1_idx, id_ex_rs2_idx,
    output logic [bitwidth-1:0] reg_din_a,
    output logic [bitwidth-1:0] reg_din_b,
    output logic [bitwidth-1:0] id_ex_imm,
    output logic [bitwidth-1:0] id_ex_pc_gen_data,
    output logic [3:0] reg_alu_ctl,
    output logic id_ex_alu_src_b_is_imm,
    output logic id_ex_reg_wr_src, id_ex_pc_gen_to_reg,
    output logic [4:0] id_ex_branch_opcode,
    output logic [1:0] id_ex_alu_src_a_sel,
    output logic [3:0] id_ex_data_bram_wr_byte_mask,
    output logic id_ex_data_bram_wr_en, id_ex_data_bram_rd_en,
    output logic id_ex_mem_unsigned,
    output logic [bitwidth-1:0] id_ex_pc_i
    );

    always @(posedge clk) begin
        if (!rst_n) begin
            id_ex_reg_wr_en <= 1'b0;
            id_ex_reg_wr_idx <= 5'b00000;
            id_ex_rs1_idx <= 5'b00000;
            id_ex_rs2_idx <= 5'b00000;
            reg_din_a <= {bitwidth{1'b0}};
            reg_din_b <= {bitwidth{1'b0}};
            id_ex_imm <= {bitwidth{1'b0}};
            id_ex_pc_gen_data <= {bitwidth{1'b0}};
            reg_alu_ctl <= 4'b0000;
            id_ex_alu_src_b_is_imm <= 1'b0;
            id_ex_reg_wr_src <= 1'b0;
            id_ex_pc_gen_to_reg <= 1'b0;
            id_ex_branch_opcode <= 5'b00000;
            id_ex_alu_src_a_sel <= 2'b00;
            id_ex_data_bram_wr_byte_mask <= 4'b0000;
            id_ex_data_bram_wr_en <= 1'b0;
            id_ex_data_bram_rd_en <= 1'b0;
            id_ex_mem_unsigned <= 1'b0;
            id_ex_pc_i <= {bitwidth{1'b0}};
        end else if (en) begin
            id_ex_pc_i <= pc_i;
            id_ex_alu_src_b_is_imm <= (flush | forward_d) ? 1'b0 : alu_src_b_is_imm;
            id_ex_imm <= imm;
            reg_din_a <= reg_dout_1;
            reg_din_b <= reg_dout_2;
            reg_alu_ctl <= (flush | forward_d) ? 4'b0000 : alu_ctl;
            id_ex_reg_wr_src <= (flush | forward_d) ? 1'b0 : reg_wr_src;
            id_ex_reg_wr_en <= (flush | forward_d) ? 1'b0 : reg_write_en;
            id_ex_data_bram_wr_en <= (flush | forward_d) ? 1'b0 : mem_write_en;
            id_ex_data_bram_rd_en <= (flush | forward_d) ? 1'b0 : mem_read_en;
            id_ex_pc_gen_to_reg <= (flush | forward_d) ? 1'b0 : pc_gen_to_reg;
            id_ex_branch_opcode <= (flush | forward_d) ? 5'b00000 : branch_opcode;
            id_ex_data_bram_wr_byte_mask <= (flush | forward_d) ? 4'b0000 : mem_byte_mask;
            id_ex_mem_unsigned <= (flush | forward_d) ? 1'b0 : mem_unsigned;
            id_ex_reg_wr_idx <= (flush | forward_d) ? 5'b00000 : reg_wr_idx;
            id_ex_rs1_idx <= (flush | forward_d) ? 5'b00000 : rs1_idx;
            id_ex_rs2_idx <= (flush | forward_d) ? 5'b00000 : rs2_idx;
            id_ex_pc_gen_data <= pc_gen_data;
            id_ex_alu_src_a_sel <= (flush | forward_d) ? 2'b00 : alu_src_a_sel;
        end
    end
endmodule
