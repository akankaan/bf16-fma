// ================================================================
//
// Date  : July 24, 2026
// Author: Kaan Akan
//
// Bfloat16 FMA (Fused Multiply Add) unit top file
//
// ================================================================

`ifndef _BF16_FMA_TOP_SV_
`define _BF16_FMA_TOP_SV_

`include "bf16_decode_classify.sv"

module bf16_fma_top 
(
    input  logic [15:0] a, // First multiplicand
    input  logic [15:0] b, // Second multiplicand
    input  logic [15:0] c, // Addend

    output logic [15:0] fma_result
);

    logic a_sign, b_sign, c_sign;
    logic a_zero, b_zero, c_zero;

    logic [7:0] a_exponent, b_exponent, c_exponent;
    logic [6:0] a_fraction, b_fraction, c_fraction;

    logic        bypass_arithmetic;
    logic [15:0] fma_flag_result;

    bf16_decode_classify decode_classify 
    (
        .a (a),
        .b (b),
        .c (c),
        .a_sign (a_sign),
        .b_sign (b_sign),
        .c_sign (c_sign),
        .a_zero (a_zero),
        .b_zero (b_zero),
        .c_zero (c_zero),
        .a_exponent (a_exponent),
        .b_exponent (b_exponent),
        .c_exponent (c_exponent),
        .a_fraction (a_fraction),
        .b_fraction (b_fraction),
        .c_fraction (c_fraction),
        .bypass_arithmetic (bypass_arithmetic),
        .fma_flag_result   (fma_flag_result)
    );

    assign fma_result = bypass_arithmetic ? fma_flag_result : '0; // Stub to be replaced; will test the tester fails with this

endmodule

`endif // _BF16_FMA_TOP_SV_
