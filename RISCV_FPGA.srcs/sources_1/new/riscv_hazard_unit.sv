`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Unified Hazard and Forwarding Unit for RISC-V 5-stage pipeline
//////////////////////////////////////////////////////////////////////////////////

module riscv_hazard_unit #(
    parameter bitwidth = 32
) (
    // ID stage inputs (for stall detection)
    input [4:0] rs1_idx,
    input [4:0] rs2_idx,
    input       id_ex_mem_read_en,
    input [4:0] id_ex_rd_idx,
    
    // EX stage inputs (for forwarding detection and muxing)
    input [4:0] id_ex_rs1_idx,
    input [4:0] id_ex_rs2_idx,
    input [bitwidth-1:0] id_ex_reg_dout_1,
    input [bitwidth-1:0] id_ex_reg_dout_2,
    input [bitwidth-1:0] id_ex_pc,
    input [bitwidth-1:0] id_ex_imm,
    input [1:0] id_ex_alu_src_a_sel,
    input       id_ex_alu_src_b_is_imm,
    
    // MEM stage inputs (for forwarding)
    input [4:0] ex_mem_rd_idx,
    input       ex_mem_reg_wr_en,
    input       ex_mem_mem_read_en,
    input [bitwidth-1:0] ex_mem_alu_data_out,
    
    // WB stage inputs (for forwarding)
    input [4:0] mem_wb_rd_idx,
    input       mem_wb_reg_wr_en,
    input [bitwidth-1:0] mem_wb_wr_data,
    
    // Control inputs
    input branch_taken,
    
    // Outputs to Pipeline
    output logic stall_if,
    output logic stall_id,
    output logic flush_id,
    output logic flush_ex,
    
    // Outputs to EX stage (Muxed operands)
    output logic [bitwidth-1:0] alu_operand_a,
    output logic [bitwidth-1:0] alu_operand_b,
    output logic [bitwidth-1:0] store_data
);

    // 1. Load-Use Hazard Detection (Stall)
    // If an instruction in EX is a Load and the instruction in ID depends on its result.
    always_comb begin
        stall_if = 1'b0;
        stall_id = 1'b0;
        flush_id = 1'b0;
        flush_ex = 1'b0;
        
        if (id_ex_mem_read_en && (|id_ex_rd_idx) && 
            (id_ex_rd_idx == rs1_idx || id_ex_rd_idx == rs2_idx)) begin
            stall_if = 1'b1;
            stall_id = 1'b1;
            flush_ex = 1'b1; // Insert bubble in EX
        end
        
        // Control Hazard (Branch Taken)
        if (branch_taken) begin
            flush_id = 1'b1; // Flush IF/ID (instruction in ID stage)
            flush_ex = 1'b1; // Flush ID/EX (instruction in EX stage)
        end
    end

    // 2. Data Forwarding Detection for EX stage
    logic [1:0] forward_a, forward_b;
    
    always_comb begin
        // Default: No forwarding
        forward_a = 2'b00;
        forward_b = 2'b00;
        
        // Forward A (rs1)
        // Priority: MEM stage > WB stage
        if (ex_mem_reg_wr_en && (|ex_mem_rd_idx) && (ex_mem_rd_idx == id_ex_rs1_idx) && !ex_mem_mem_read_en) begin
            forward_a = 2'b10; // Forward from MEM stage
        end else if (mem_wb_reg_wr_en && (|mem_wb_rd_idx) && (mem_wb_rd_idx == id_ex_rs1_idx)) begin
            forward_a = 2'b01; // Forward from WB stage
        end
        
        // Forward B (rs2)
        // Priority: MEM stage > WB stage
        if (ex_mem_reg_wr_en && (|ex_mem_rd_idx) && (ex_mem_rd_idx == id_ex_rs2_idx) && !ex_mem_mem_read_en) begin
            forward_b = 2'b10; // Forward from MEM stage
        end else if (mem_wb_reg_wr_en && (|mem_wb_rd_idx) && (mem_wb_rd_idx == id_ex_rs2_idx)) begin
            forward_b = 2'b01; // Forward from WB stage
        end
    end

    // 3. Forwarding Muxes for ALU Operands
    logic [bitwidth-1:0] rs1_forwarded, rs2_forwarded;
    
    assign rs1_forwarded = (forward_a == 2'b10) ? ex_mem_alu_data_out :
                           (forward_a == 2'b01) ? mem_wb_wr_data :
                           id_ex_reg_dout_1;
                           
    assign rs2_forwarded = (forward_b == 2'b10) ? ex_mem_alu_data_out :
                           (forward_b == 2'b01) ? mem_wb_wr_data :
                           id_ex_reg_dout_2;

    // ALU Operand A Mux
    always_comb begin
        case (id_ex_alu_src_a_sel)
            2'b01:   alu_operand_a = id_ex_pc;
            2'b10:   alu_operand_a = {bitwidth{1'b0}};
            default: alu_operand_a = rs1_forwarded;
        endcase
    end

    // ALU Operand B Mux
    assign alu_operand_b = id_ex_alu_src_b_is_imm ? id_ex_imm : rs2_forwarded;

    // Store Data (Always from forwarded rs2)
    assign store_data = rs2_forwarded;

endmodule
