`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2026/03/12 20:13:21
// Design Name: 
// Module Name: riscv_cpu
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
`include "constants.sv"

module riscv_cpu #(
    parameter bitwidth = 32
) (
    input                 clk,
    input                 rst_n,
    input  [bitwidth-1:0] inst,
    output [bitwidth-1:0] inst_bram_addr,
    input  [bitwidth-1:0] data_bram_rd_data,
    output [bitwidth-1:0] data_bram_addr,
    output logic [bitwidth-1:0] data_bram_wr_data,
    output                data_bram_wr_en,
    output                data_bram_rd_en,
    output [         3:0] data_bram_wr_byte_mask
);

    // Pipeline PC signals
    logic [bitwidth-1:0] pc = 0;
    logic [bitwidth-1:0] pc_next;
    logic [bitwidth-1:0] pc_i;

    // ID Stage signals
    logic [bitwidth-1:0] imm;
    logic [         1:0] alu_opcode;
    logic                alu_src_b_is_imm;
    logic [         4:0] branch_opcode;
    logic [         2:0] inst_funct3;
    logic [         6:0] inst_funct7;
    logic                mem_read_en;
    logic                mem_to_reg;
    logic                mem_write_en;
    logic                reg_write_en;
    logic                pc_gen_to_reg;
    logic [         1:0] alu_src_a_sel;
    logic [bitwidth-1:0] rd_dout_1;
    logic [bitwidth-1:0] rd_dout_2;
    logic [         3:0] alu_ctl;
    logic [         3:0] mem_byte_mask;
    logic                mem_unsigned;

    // Hazard and Forward signals
    logic stall_if, stall_id, flush_id, flush_ex;
    logic [bitwidth-1:0] alu_operand_a, alu_operand_b, store_data;

    // ID/EX Pipeline signals
    logic [3:0] reg_alu_ctl, id_ex_data_bram_wr_byte_mask;
    logic [4:0] id_ex_branch_opcode;
    logic id_ex_alu_src_b_is_imm, id_ex_pc_gen_to_reg;
    logic id_ex_reg_wr_en, id_ex_data_bram_wr_en, id_ex_data_bram_rd_en;
    logic id_ex_reg_wr_src;
    logic [1:0] id_ex_alu_src_a_sel;
    logic [bitwidth-1:0] id_ex_imm;
    logic [bitwidth-1:0] id_ex_pc_gen_data;
    logic [bitwidth-1:0] id_ex_pc_i;
    logic [4:0] id_ex_reg_wr_idx, id_ex_rs1_idx, id_ex_rs2_idx;
    logic id_ex_mem_unsigned;

    // EX Stage signals
    logic [bitwidth-1:0] alu_data_out;
    logic                alu_zero_flag;
    logic                branch_taken_ex;
    logic [bitwidth-1:0] branch_target_pc_ex;
    logic                branch_taken_r;
    logic [bitwidth-1:0] branch_target_pc_r;

    // EX/MEM Pipeline signals
    logic [bitwidth-1:0] ex_mem_pc_gen_data, ex_mem_alu_data_out, ex_mem_imm;
    logic ex_mem_data_bram_rd_en, ex_mem_data_bram_wr_en;
    logic ex_mem_pc_gen_to_reg, ex_mem_reg_wr_src;
    logic [3:0] ex_mem_data_bram_wr_byte_mask;
    logic [bitwidth-1:0] ex_mem_reg_rd_dout_2;
    logic [4:0] ex_mem_reg_wr_idx;
    logic ex_mem_reg_wr_en;
    logic ex_mem_mem_unsigned;

    logic mem_wait;
    wire mem_stall = ex_mem_data_bram_rd_en && !mem_wait;
    logic mem_wait_reg_wr_src, mem_wait_pc_gen_to_reg;
    logic [bitwidth-1:0] mem_wait_imm, mem_wait_pc_gen_data, mem_wait_alu_data_out;
    logic [3:0] mem_wait_data_bram_wr_byte_mask;
    logic mem_wait_reg_wr_en, mem_wait_data_bram_rd_en, mem_wait_mem_unsigned;
    logic [4:0] mem_wait_reg_wr_idx;

    // MEM Stage signals
    // logic [bitwidth-1:0] signed_data_bram_rd_data; // Redundant declaration removed

    // MEM/WB Pipeline signals
    logic mem_wb_reg_wr_src, mem_wb_pc_gen_to_reg;
    logic [bitwidth-1:0] mem_wb_imm, mem_wb_pc_gen_data, mem_wb_alu_data_out;
    logic [4:0] mem_wb_reg_wr_idx;
    logic mem_wb_reg_wr_en;
    logic [bitwidth-1:0] mem_wb_signed_data_bram_rd_data;
    logic mem_wb_data_bram_rd_en;

    // Internal wires
    logic [bitwidth-1:0] reg_din_a;
    logic [bitwidth-1:0] reg_din_b;
    logic [bitwidth-1:0] fetch_buf_inst;
    logic [bitwidth-1:0] fetch_buf_pc;
    logic fetch_buf_valid;
    wire ifid_en = !(stall_id || mem_stall);

    // pc_i assignment - PC input to pipeline registers
    logic [bitwidth-1:0] pc_id;
    always @(posedge clk) begin
        if (!rst_n) begin
            pc_id <= 0;
        end else if (!stall_id && !mem_stall) begin
            pc_id <= pc;
        end
    end

    // Register branch decisions one cycle later to cut the WB->EX->IF feedback path.
    // The delayed branch flushes IF/ID, ID/EX, and EX/MEM together on the next cycle.
    always @(posedge clk) begin
        if (!rst_n) begin
            branch_taken_r <= 1'b0;
            branch_target_pc_r <= {bitwidth{1'b0}};
        end else if (branch_taken_r) begin
            branch_taken_r <= 1'b0;
            branch_target_pc_r <= {bitwidth{1'b0}};
        end else if (branch_taken_ex) begin
            branch_taken_r <= 1'b1;
            branch_target_pc_r <= branch_target_pc_ex;
        end
    end

    // One-entry fetch buffer absorbs the one-cycle delayed BRAM output so IF/ID stalls
    // do not skip the instruction already in flight from synchronous instruction memory.
    always @(posedge clk) begin
        if (!rst_n) begin
            fetch_buf_inst <= 32'h00000013;
            fetch_buf_pc <= {bitwidth{1'b0}};
            fetch_buf_valid <= 1'b0;
        end else if (flush_id) begin
            fetch_buf_inst <= 32'h00000013;
            fetch_buf_pc <= {bitwidth{1'b0}};
            fetch_buf_valid <= 1'b0;
        end else begin
            if (!ifid_en && !fetch_buf_valid) begin
                // IF/ID cannot accept a new instruction this cycle, so hold the in-flight fetch.
                fetch_buf_inst <= inst;
                fetch_buf_pc <= pc_id;
                fetch_buf_valid <= 1'b1;
            end else if (ifid_en && fetch_buf_valid) begin
                // IF/ID consumes the buffered instruction in this cycle.
                fetch_buf_valid <= 1'b0;
            end
        end
    end

    always @(posedge clk) begin
        if (!rst_n) begin
            mem_wait <= 1'b0;
            mem_wait_reg_wr_src <= 1'b0;
            mem_wait_pc_gen_to_reg <= 1'b0;
            mem_wait_imm <= {bitwidth{1'b0}};
            mem_wait_pc_gen_data <= {bitwidth{1'b0}};
            mem_wait_alu_data_out <= {bitwidth{1'b0}};
            mem_wait_data_bram_wr_byte_mask <= 4'b0000;
            mem_wait_reg_wr_en <= 1'b0;
            mem_wait_data_bram_rd_en <= 1'b0;
            mem_wait_mem_unsigned <= 1'b0;
            mem_wait_reg_wr_idx <= 5'b00000;
        end else if (ex_mem_data_bram_rd_en && !mem_wait) begin
            mem_wait <= 1'b1;
            mem_wait_reg_wr_src <= ex_mem_reg_wr_src;
            mem_wait_pc_gen_to_reg <= ex_mem_pc_gen_to_reg;
            mem_wait_imm <= ex_mem_imm;
            mem_wait_pc_gen_data <= ex_mem_pc_gen_data;
            mem_wait_alu_data_out <= ex_mem_alu_data_out;
            mem_wait_data_bram_wr_byte_mask <= ex_mem_data_bram_wr_byte_mask;
            mem_wait_reg_wr_en <= ex_mem_reg_wr_en;
            mem_wait_data_bram_rd_en <= ex_mem_data_bram_rd_en;
            mem_wait_mem_unsigned <= ex_mem_mem_unsigned;
            mem_wait_reg_wr_idx <= ex_mem_reg_wr_idx;
        end else begin
            mem_wait <= 1'b0;
        end
    end

    // IF/ID register keeps instruction and PC stable while the pipeline stalls.
    logic [bitwidth-1:0] current_inst;
    IFID_reg #(
        .bitwidth(bitwidth)
    ) IFID_reg_inst (
        .clk(clk),
        .rst_n(rst_n),
        .en(ifid_en),
        .flush(flush_id),
        .inst_in(fetch_buf_valid ? fetch_buf_inst : inst),
        .pc_in(fetch_buf_valid ? fetch_buf_pc : pc_id),
        .inst_out(current_inst),
        .pc_out(pc_i)
    );

    assign reg_din_a = rd_dout_1;
    assign reg_din_b = rd_dout_2;

    riscv_inst_decode riscv_inst_decode_inst (
        .inst            (current_inst),
        .alu_opcode      (alu_opcode),
        .alu_src_b_is_imm(alu_src_b_is_imm),
        .branch_opcode   (branch_opcode),
        .inst_funct3     (inst_funct3),
        .inst_funct7     (inst_funct7),
        .mem_read_en     (mem_read_en),
        .mem_to_reg      (mem_to_reg),
        .mem_write_en    (mem_write_en),
        .reg_write_en    (reg_write_en),
        .pc_gen_to_reg   (pc_gen_to_reg),
        .alu_src_a_sel   (alu_src_a_sel),
        .mem_byte_mask   (mem_byte_mask),
        .mem_unsigned    (mem_unsigned)
    );

    // Register File Write-back (WB Stage)
    logic [bitwidth-1:0] wb_wr_data;
    assign wb_wr_data = (mem_wb_pc_gen_to_reg) ? mem_wb_pc_gen_data :
                        (mem_wb_data_bram_rd_en) ? mem_wb_signed_data_bram_rd_data :
                        mem_wb_alu_data_out;

    riscv_reg_file riscv_reg_file_inst (
        .clk      (clk),
        .rst_n    (rst_n),
        .wr_en    (mem_wb_reg_wr_en),
        .wr_idx   (mem_wb_reg_wr_idx),
        .wr_data  (wb_wr_data),
        .rd_idx_1 (current_inst[19:15]),
        .rd_idx_2 (current_inst[24:20]),
        .rd_dout_1(rd_dout_1),
        .rd_dout_2(rd_dout_2)
    );

    riscv_alu_decode riscv_alu_decode_inst (
        .alu_opcode (alu_opcode),
        .inst_funct3(inst_funct3),
        .inst_funct7(inst_funct7),
        .alu_ctl    (alu_ctl)
    );

    riscv_hazard_unit #(
        .bitwidth(bitwidth)
    ) riscv_hazard_unit_inst (
        .rs1_idx(current_inst[19:15]),
        .rs2_idx(current_inst[24:20]),
        .id_ex_mem_read_en(id_ex_data_bram_rd_en),
        .id_ex_rd_idx(id_ex_reg_wr_idx),
        .id_ex_rs1_idx(id_ex_rs1_idx),
        .id_ex_rs2_idx(id_ex_rs2_idx),
        .id_ex_reg_dout_1(id_ex_reg_din_a),
        .id_ex_reg_dout_2(id_ex_reg_din_b),
        .id_ex_pc(id_ex_pc_i),
        .id_ex_imm(id_ex_imm),
        .id_ex_alu_src_a_sel(id_ex_alu_src_a_sel),
        .id_ex_alu_src_b_is_imm(id_ex_alu_src_b_is_imm),
        .ex_mem_rd_idx(ex_mem_reg_wr_idx),
        .ex_mem_reg_wr_en(ex_mem_reg_wr_en),
        .ex_mem_mem_read_en(ex_mem_data_bram_rd_en),
        .ex_mem_alu_data_out(ex_mem_alu_data_out),
        .mem_wb_rd_idx(mem_wb_reg_wr_idx),
        .mem_wb_reg_wr_en(mem_wb_reg_wr_en),
        .mem_wb_wr_data(wb_wr_data),
        .branch_taken(branch_taken_r),
        .stall_if(stall_if),
        .stall_id(stall_id),
        .flush_id(flush_id),
        .flush_ex(flush_ex),
        .alu_operand_a(alu_operand_a),
        .alu_operand_b(alu_operand_b),
        .store_data(store_data)
    );

    IDEX_reg IDEX_reg_inst (
        .clk(clk),
        .rst_n(rst_n),
        .en(!mem_stall),
        .alu_src_b_is_imm(alu_src_b_is_imm),
        .imm(imm),
        .branch_opcode(branch_opcode),
        .mem_read_en(mem_read_en),
        .mem_write_en(mem_write_en),
        .mem_to_reg(mem_to_reg),
        .reg_write_en(reg_write_en),
        .reg_wr_src(1'b0),
        .pc_gen_to_reg(pc_gen_to_reg),
        .alu_ctl(alu_ctl),
        .alu_src_a_sel(alu_src_a_sel),
        .reg_dout_1(rd_dout_1),
        .reg_dout_2(rd_dout_2),
        .reg_wr_idx(current_inst[11:7]),
        .rs1_idx(current_inst[19:15]),
        .rs2_idx(current_inst[24:20]),
        .pc_gen_data(pc_i + 32'd4),
        .pc_next(pc_next),
        .pc(pc),
        .pc_i(pc_i),
        .mem_byte_mask(mem_byte_mask),
        .mem_unsigned(mem_unsigned),
        .forward_d(1'b0),
        .flush(flush_ex),
        .id_ex_reg_wr_en(id_ex_reg_wr_en),
        .id_ex_reg_wr_idx(id_ex_reg_wr_idx),
        .id_ex_rs1_idx(id_ex_rs1_idx),
        .id_ex_rs2_idx(id_ex_rs2_idx),
        .reg_din_a(id_ex_reg_din_a), // Renamed to avoid conflict
        .reg_din_b(id_ex_reg_din_b), // Renamed to avoid conflict
        .id_ex_imm(id_ex_imm),
        .id_ex_pc_gen_data(id_ex_pc_gen_data),
        .reg_alu_ctl(reg_alu_ctl),
        .id_ex_alu_src_b_is_imm(id_ex_alu_src_b_is_imm),
        .id_ex_reg_wr_src(id_ex_reg_wr_src),
        .id_ex_pc_gen_to_reg(id_ex_pc_gen_to_reg),
        .id_ex_branch_opcode(id_ex_branch_opcode),
        .id_ex_alu_src_a_sel(id_ex_alu_src_a_sel),
        .id_ex_data_bram_wr_byte_mask(id_ex_data_bram_wr_byte_mask),
        .id_ex_data_bram_wr_en(id_ex_data_bram_wr_en),
        .id_ex_data_bram_rd_en(id_ex_data_bram_rd_en),
        .id_ex_mem_unsigned(id_ex_mem_unsigned),
        .id_ex_pc_i(id_ex_pc_i)
    );

    // Use renaming to avoid conflict with existing reg_din_a/b
    logic [bitwidth-1:0] id_ex_reg_din_a, id_ex_reg_din_b;

    riscv_alu riscv_alu_inst (
        .din_a     (alu_operand_a),
        .din_b     (alu_operand_b),
        .ctl_in    (reg_alu_ctl),
        .dout      (alu_data_out),
        .zero_flag (alu_zero_flag)
    );

    EXMEM_reg EXMEM_reg_inst (
        .clk(clk),
        .rst_n(rst_n),
        .en(!mem_stall),
        .flush(branch_taken_r),
        .id_ex_pc_gen_data(id_ex_pc_gen_data),
        .alu_data_out(alu_data_out),
        .id_ex_imm(id_ex_imm),
        .ex_mem_imm(ex_mem_imm),
        .id_ex_data_bram_rd_en(id_ex_data_bram_rd_en),
        .id_ex_data_bram_wr_en(id_ex_data_bram_wr_en),
        .id_ex_reg_wr_idx(id_ex_reg_wr_idx),
        .id_ex_reg_wr_en(id_ex_reg_wr_en),
        .id_ex_pc_gen_to_reg(id_ex_pc_gen_to_reg),
        .id_ex_reg_wr_src(id_ex_reg_wr_src),
        .id_ex_data_bram_wr_byte_mask(id_ex_data_bram_wr_byte_mask),
        .id_ex_mem_unsigned(id_ex_mem_unsigned),
        .ex_mem_pc_gen_data(ex_mem_pc_gen_data),
        .ex_mem_alu_data_out(ex_mem_alu_data_out),
        .ex_mem_data_bram_rd_en(ex_mem_data_bram_rd_en),
        .ex_mem_data_bram_wr_en(ex_mem_data_bram_wr_en),
        .ex_mem_reg_wr_idx(ex_mem_reg_wr_idx),
        .ex_mem_reg_wr_en(ex_mem_reg_wr_en),
        .ex_mem_pc_gen_to_reg(ex_mem_pc_gen_to_reg),
        .ex_mem_reg_wr_src(ex_mem_reg_wr_src),
        .id_ex_reg_rd_dout_2(store_data), // Use forwarded rs2 data for stores
        .ex_mem_reg_rd_dout_2(ex_mem_reg_rd_dout_2),
        .ex_mem_data_bram_wr_byte_mask(ex_mem_data_bram_wr_byte_mask),
        .ex_mem_mem_unsigned(ex_mem_mem_unsigned)
    );

    // Load data sign extension logic
    logic [bitwidth-1:0] signed_data_bram_rd_data;
    logic [bitwidth-1:0] data_bram_rd_data_aligned;
    logic mem_stage_reg_wr_src, mem_stage_pc_gen_to_reg;
    logic [bitwidth-1:0] mem_stage_imm, mem_stage_pc_gen_data, mem_stage_alu_data_out;
    logic [3:0] mem_stage_data_bram_wr_byte_mask;
    logic mem_stage_reg_wr_en, mem_stage_data_bram_rd_en, mem_stage_mem_unsigned;
    logic [4:0] mem_stage_reg_wr_idx;

    assign mem_stage_reg_wr_src = mem_wait ? mem_wait_reg_wr_src : ex_mem_reg_wr_src;
    assign mem_stage_pc_gen_to_reg = mem_wait ? mem_wait_pc_gen_to_reg : ex_mem_pc_gen_to_reg;
    assign mem_stage_imm = mem_wait ? mem_wait_imm : ex_mem_imm;
    assign mem_stage_pc_gen_data = mem_wait ? mem_wait_pc_gen_data : ex_mem_pc_gen_data;
    assign mem_stage_alu_data_out = mem_wait ? mem_wait_alu_data_out : ex_mem_alu_data_out;
    assign mem_stage_data_bram_wr_byte_mask = mem_wait ? mem_wait_data_bram_wr_byte_mask : ex_mem_data_bram_wr_byte_mask;
    assign mem_stage_reg_wr_en = mem_wait ? mem_wait_reg_wr_en : ex_mem_reg_wr_en;
    assign mem_stage_data_bram_rd_en = mem_wait ? mem_wait_data_bram_rd_en : ex_mem_data_bram_rd_en;
    assign mem_stage_mem_unsigned = mem_wait ? mem_wait_mem_unsigned : ex_mem_mem_unsigned;
    assign mem_stage_reg_wr_idx = mem_wait ? mem_wait_reg_wr_idx : ex_mem_reg_wr_idx;
    
    // Align load data based on address offset
    always @(*) begin
        case (mem_stage_alu_data_out[1:0])
            2'b00: data_bram_rd_data_aligned = data_bram_rd_data;
            2'b01: data_bram_rd_data_aligned = {8'b0, data_bram_rd_data[31:8]};
            2'b10: data_bram_rd_data_aligned = {16'b0, data_bram_rd_data[31:16]};
            2'b11: data_bram_rd_data_aligned = {24'b0, data_bram_rd_data[31:24]};
            default: data_bram_rd_data_aligned = data_bram_rd_data;
        endcase
    end

    always @(*) begin
        if (mem_stage_mem_unsigned) begin
            case (mem_stage_data_bram_wr_byte_mask)
                4'b0001: signed_data_bram_rd_data = {24'b0, data_bram_rd_data_aligned[7:0]};
                4'b0011: signed_data_bram_rd_data = {16'b0, data_bram_rd_data_aligned[15:0]};
                4'b1111: signed_data_bram_rd_data = data_bram_rd_data_aligned;
                default: signed_data_bram_rd_data = data_bram_rd_data_aligned;
            endcase
        end else begin
            case (mem_stage_data_bram_wr_byte_mask)
                4'b0001: signed_data_bram_rd_data = {{24{data_bram_rd_data_aligned[7]}}, data_bram_rd_data_aligned[7:0]};
                4'b0011: signed_data_bram_rd_data = {{16{data_bram_rd_data_aligned[15]}}, data_bram_rd_data_aligned[15:0]};
                4'b1111: signed_data_bram_rd_data = data_bram_rd_data_aligned;
                default: signed_data_bram_rd_data = data_bram_rd_data_aligned;
            endcase
        end
    end

    MEMWB_reg MEMWB_reg_inst (
        .clk(clk),
        .rst_n(rst_n),
        .en(!mem_stall),
        .ex_mem_reg_wr_src(mem_stage_reg_wr_src),
        .ex_mem_pc_gen_to_reg(mem_stage_pc_gen_to_reg),
        .ex_mem_imm(mem_stage_imm),
        .ex_mem_pc_gen_data(mem_stage_pc_gen_data),
        .ex_mem_alu_data_out(mem_stage_alu_data_out),
        .signed_data_bram_rd_data(signed_data_bram_rd_data),
        .ex_mem_reg_wr_en(mem_stage_reg_wr_en),
        .ex_mem_reg_wr_idx(mem_stage_reg_wr_idx),
        .ex_mem_data_bram_rd_en(mem_stage_data_bram_rd_en),
        .mem_wb_imm(mem_wb_imm),
        .mem_wb_pc_gen_data(mem_wb_pc_gen_data),
        .mem_wb_alu_data_out(mem_wb_alu_data_out),
        .mem_wb_reg_wr_src(mem_wb_reg_wr_src),
        .mem_wb_pc_gen_to_reg(mem_wb_pc_gen_to_reg),
        .mem_wb_reg_wr_en(mem_wb_reg_wr_en),
        .mem_wb_reg_wr_idx(mem_wb_reg_wr_idx),
        .mem_wb_signed_data_bram_rd_data(mem_wb_signed_data_bram_rd_data),
        .mem_wb_data_bram_rd_en(mem_wb_data_bram_rd_en)
    );

    assign data_bram_wr_data = ex_mem_reg_rd_dout_2 << (8 * ex_mem_alu_data_out[1:0]);
    assign inst_bram_addr = pc;
    assign data_bram_addr = {ex_mem_alu_data_out[31:2], 2'b00}; // Word aligned address
    assign data_bram_wr_en = ex_mem_data_bram_wr_en;
    assign data_bram_rd_en = ex_mem_data_bram_rd_en;
    assign data_bram_wr_byte_mask = ex_mem_data_bram_wr_byte_mask << ex_mem_alu_data_out[1:0];

    // PC update logic with branch and stall handling
    always @(posedge clk) begin
        if (!rst_n) begin
            pc <= 0;
        end else begin
            if (branch_taken_r) begin
                // Branch or jump taken
                pc <= branch_target_pc_r;
            end else if (stall_if || mem_stall) begin
                // Stall pipeline for load-use hazard
                pc <= pc;
            end else begin
                // Normal PC increment
                pc <= pc + 4;
            end
        end
    end
    
    assign pc_next = pc + 4;
    
    riscv_pc_gen riscv_pc_gen_inst (
        .rst_n           (rst_n),
        .branch_opcode   (id_ex_branch_opcode),
        .id_ex_pc        (id_ex_pc_i),
        .id_ex_imm       (id_ex_imm),
        .alu_data        (alu_data_out),
        .alu_zero_flag   (alu_zero_flag),
        .branch_taken    (branch_taken_ex),
        .branch_target_pc(branch_target_pc_ex)
    );

    riscv_imm_gen riscv_imm_gen_inst (
        .inst(current_inst),
        .imm (imm)
    );

endmodule
