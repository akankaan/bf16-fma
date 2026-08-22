// ================================================================
//
// Date  : August 11, 2026
// Author: Kaan Akan
//
// Bfloat16 FMA top file, compute core combined with the IO sequencer.
//
// Operands stream in from the 16-bit input bus over 3 cycles, the 
// main unit computes, and the result streams out a byte at a time.
//
// ================================================================

`ifndef _BF16_FMA_SV_
`define _BF16_FMA_SV_

module bf16_fma
(
    input  logic        clk,
    input  logic        rst_n,

    input  logic        in_valid,
    input  logic [15:0] in_data,       // operand words in over the 16-bit pins

    output logic [7:0]  out_data,      // result byte stream out
    output logic        result_valid   // high while a result byte is on out_data
);

    logic [15:0] a, b, c;
    logic [15:0] fma_result;
    logic        fma_result_valid;
    logic        operands_valid;

    // IO sequencer to deserialize inputs and serialize the result
    bf16_fma_io io
    (
        .clk              (clk),
        .rst_n            (rst_n),
        .in_valid         (in_valid),
        .in_data          (in_data),
        .a                (a),
        .b                (b),
        .c                (c),
        .operands_valid   (operands_valid),
        .fma_result       (fma_result),
        .fma_result_valid (fma_result_valid),
        .out_data         (out_data),
        .result_valid     (result_valid)
    );

    // FMA core unit
    bf16_fma_core core
    (
        .clk              (clk),
        .rst_n            (rst_n),
        .operands_valid   (operands_valid),
        .a                (a),
        .b                (b),
        .c                (c),
        .fma_result       (fma_result),
        .fma_result_valid (fma_result_valid)
    );

endmodule

`endif // _BF16_FMA_SV_
