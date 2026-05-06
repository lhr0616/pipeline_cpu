`timescale 1ns / 1ps
`include "constants.sv"

module riscv_pc_gen #(
    parameter bitwidth = 32
) (
    input                       rst_n,
    input        [         4:0] branch_opcode,
    input        [bitwidth-1:0] id_ex_pc,
    input        [bitwidth-1:0] id_ex_imm,
    input        [bitwidth-1:0] alu_data,
    input                       alu_zero_flag,
    output logic                branch_taken,
    output logic [bitwidth-1:0] branch_target_pc
);

    always_comb begin
        branch_taken = 1'b0;
        branch_target_pc = id_ex_pc + 4;
        
        casez (branch_opcode)
            5'b1000?: begin // BLT, BGE, BLTU, BGEU
                // For comparison branches, ALU result [0] is 1 if LT/LTU
                // branch_opcode[0] is 0 for BLT/BLTU, 1 for BGE/BGEU
                branch_taken = (branch_opcode[0] ^ alu_data[0]);
                branch_target_pc = id_ex_pc + id_ex_imm;
            end
            5'b0100?: begin // BEQ, BNE
                // branch_opcode[0] is 0 for BEQ, 1 for BNE
                branch_taken = (branch_opcode[0] ^ alu_zero_flag);
                branch_target_pc = id_ex_pc + id_ex_imm;
            end
            5'b00010: begin // JALR
                branch_taken = 1'b1;
                branch_target_pc = alu_data & ~32'h1;
            end
            5'b00100: begin // JAL
                branch_taken = 1'b1;
                branch_target_pc = id_ex_pc + id_ex_imm;
            end
            default: begin
                branch_taken = 1'b0;
                branch_target_pc = id_ex_pc + 4;
            end
        endcase
    end
endmodule
