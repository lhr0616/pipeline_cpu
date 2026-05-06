`timescale 1ns / 1ps

module IFID_reg #(
    parameter bitwidth = 32
)(
    input  logic                 clk,
    input  logic                 rst_n,
    input  logic                 en,
    input  logic                 flush,
    input  logic [bitwidth-1:0]  inst_in,
    input  logic [bitwidth-1:0]  pc_in,
    output logic [bitwidth-1:0]  inst_out,
    output logic [bitwidth-1:0]  pc_out
);

    localparam logic [31:0] NOP_INST = 32'h00000013;

    always_ff @(posedge clk) begin
        if (!rst_n) begin
            inst_out <= NOP_INST;
            pc_out <= {bitwidth{1'b0}};
        end else if (flush) begin
            inst_out <= NOP_INST;
            pc_out <= pc_out;
        end else if (en) begin
            inst_out <= inst_in;
            pc_out <= pc_in;
        end
    end

endmodule
