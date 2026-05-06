`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2026/03/11 19:33:16
// Design Name: 
// Module Name: riscv_inst_decode
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

module riscv_inst_decode (
    input        [31:0] inst,
    output       [ 2:0] inst_funct3,
    output       [ 6:0] inst_funct7,
    output logic [ 1:0] alu_opcode,
    output logic        alu_src_b_is_imm,
    output logic        reg_write_en,
    output logic        mem_read_en,
    output logic        mem_to_reg,
    output logic        mem_write_en,
    output logic [ 4:0] branch_opcode,
    output logic        pc_gen_src,
    output logic        pc_gen_to_reg,
    output logic [ 1:0] alu_src_a_sel,
    output logic [ 3:0] mem_byte_mask,
    output logic        mem_unsigned
);
    wire [6:0] opcode = inst[6:0];
    assign inst_funct3 = inst[14:12];
    assign inst_funct7 = inst[31:25];

    // ALU Opcode 控制逻辑
    always @(*) begin
        casez (opcode)
            `OP_BRANCH: alu_opcode = `ALUOP_BRANCH;  // 2'b01
            `OP_OP:     alu_opcode = `ALUOP_RTYPE;  // 2'b10
            `OP_OP_IMM: alu_opcode = `ALUOP_OPIMM;  // 2'b11
            default:    alu_opcode = `ALUOP_ADD;    // 2'b00 (Load/Store/LUI/AUIPC/JAL/JALR)
        endcase
    end

    // 写使能与存储器逻辑
    always @(*) begin
        reg_write_en = (opcode == `OP_OP)     || (opcode == `OP_OP_IMM) ||
                       (opcode == `OP_LOAD)   || (opcode == `OP_LUI)    ||
                       (opcode == `OP_AUIPC)  || (opcode == `OP_JAL)    ||
                       (opcode == `OP_JALR);

        mem_read_en  = (opcode == `OP_LOAD);
        mem_write_en = (opcode == `OP_STORE);
        mem_to_reg   = (opcode == `OP_LOAD);
    end

    // ALU 第一操作数来源
    always @(*) begin
        case (opcode)
            `OP_AUIPC: alu_src_a_sel = 2'b01; // PC
            `OP_LUI:   alu_src_a_sel = 2'b10; // Zero
            default:   alu_src_a_sel = 2'b00; // Register
        endcase
    end

    // ALU 第二操作数来源
    assign alu_src_b_is_imm = (opcode != `OP_OP) && (opcode != `OP_BRANCH) && (opcode != `OP_JAL);

    // Branch Opcode 拼接逻辑，包含 funct3 细分编码
    always @(*) begin
        casez (opcode)
            `OP_BRANCH: begin
                case (inst_funct3[2])
                    1'b0: branch_opcode = {1'b0, 1'b1, 2'b00, inst_funct3[0]}; // BEQ/BNE (bit 3=1)
                    1'b1: branch_opcode = {1'b1, 1'b0, 2'b00, inst_funct3[0]}; // BLT/BGE/BLTU/BGEU (bit 4=1)
                    default: branch_opcode = 5'b00000;
                endcase
            end
            `OP_JAL:    branch_opcode = 5'b00100; // JAL (bit 2=1)
            `OP_JALR:   branch_opcode = 5'b00010; // JALR (bit 1=1)
            default:    branch_opcode = 5'b00000;
        endcase
    end

    // 生成器相关控制
    always @(*) begin
        // pc_gen_src: 是否需要计算非顺序 PC (跳转或分支)
        pc_gen_src = (opcode == `OP_BRANCH) || (opcode == `OP_JAL) || 
                     (opcode == `OP_JALR)   || (opcode == `OP_AUIPC);
        
        // pc_gen_to_reg: 是否将 PC+4 写入目标寄存器
        pc_gen_to_reg = (opcode == `OP_JAL) || (opcode == `OP_JALR);
    end

    // Memory byte mask and unsigned control
    always @(*) begin
        mem_unsigned = inst_funct3[2];
        case (inst_funct3[1:0])
            2'b00:   mem_byte_mask = 4'b0001; // Byte
            2'b01:   mem_byte_mask = 4'b0011; // Half-word
            2'b10:   mem_byte_mask = 4'b1111; // Word
            default: mem_byte_mask = 4'b1111;
        endcase
    end

endmodule
