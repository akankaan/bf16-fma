// ================================================================
//
// Date  : August 10, 2026
// Author: Kaan Akan
//
// IO sequencer for the Bfloat16 FMA on the tapeout.
//
// The three 16-bit operands each load in one cycle over the 16-bit input bus.
// Then outputted a byte at a time on the 8-bit output bus.
//
// ================================================================

`ifndef _BF16_FMA_IO_SV_
`define _BF16_FMA_IO_SV_

module bf16_fma_io
(
    input  logic        clk,
    input  logic        rst_n,

    // For load 
    input  logic [15:0] in_data,          // operand word from pins
    output logic [15:0] a, b, c,          // operand triples to fma unit
    output logic        operands_valid,   // goes high when load completes

    // For output
    input  logic [15:0] fma_result,       // computed result from fma unit
    input  logic        fma_result_valid, // start output when pipeline has valid output
    output logic [7:0]  out_data,         // result byte to pins
    output logic        result_valid
);

    bf16_loader input_loader 
    (
        .clk            (clk),
        .rst_n          (rst_n),
        .in_data        (in_data),
        .a              (a),
        .b              (b),
        .c              (c),
        .operands_valid (operands_valid)
    );

    bf16_outputter outputter 
    (
        .clk              (clk),
        .rst_n            (rst_n),
        .result           (fma_result),
        .start            (fma_result_valid), 
        .out_byte         (out_data),       
        .busy             (result_valid) // indicates the output byte is valid
    );

endmodule

`endif // _BF16_FMA_IO_SV_
