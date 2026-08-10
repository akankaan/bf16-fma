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

module bf16_fma_top 
(
    input  logic [15:0] a, // First  multiplicand
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
        .a                 (a),
        .b                 (b),
        .c                 (c),
        .a_sign            (a_sign),
        .b_sign            (b_sign),
        .c_sign            (c_sign),
        .a_zero            (a_zero),
        .b_zero            (b_zero),
        .c_zero            (c_zero),
        .a_exponent        (a_exponent),
        .b_exponent        (b_exponent),
        .c_exponent        (c_exponent),
        .a_fraction        (a_fraction),
        .b_fraction        (b_fraction),
        .c_fraction        (c_fraction),
        .bypass_arithmetic (bypass_arithmetic),
        .fma_flag_result   (fma_flag_result)
    );

    logic product_sign;
    logic product_zero;

    logic        [15:0] product;
    logic signed [9:0]  product_exponent;

    bf16_multiplier multiplier 
    (
        .a_sign            (a_sign),
        .b_sign            (b_sign),
        .a_zero            (a_zero),
        .b_zero            (b_zero),
        .a_exponent        (a_exponent),
        .b_exponent        (b_exponent),
        .a_fraction        (a_fraction),
        .b_fraction        (b_fraction),
        .product_sign      (product_sign),
        .product_zero      (product_zero),
        .product           (product),
        .product_exponent  (product_exponent)
    );
    
    logic [25:0]        aligned_product;
    logic [25:0]        aligned_addend;
    logic               sticky;
    logic signed [9:0]  aligned_exponent;

    bf16_aligner aligner 
    (
        .product          (product),
        .product_zero     (product_zero),
        .product_exponent (product_exponent),
        .c_zero           (c_zero),
        .c_exponent       (c_exponent),
        .c_fraction       (c_fraction),
        .aligned_product  (aligned_product),
        .aligned_addend   (aligned_addend),
        .sticky           (sticky),
        .aligned_exponent (aligned_exponent)
    );

    logic [26:0]        sum;
    logic               sum_sign;
    logic signed [9:0]  sum_exponent;
    logic               sum_sticky;

    bf16_addsub addsub 
    (
        .aligned_product  (aligned_product),
        .aligned_addend   (aligned_addend),
        .sticky           (sticky),
        .aligned_exponent (aligned_exponent),
        .product_sign     (product_sign),
        .c_sign           (c_sign),
        .sum              (sum),
        .sum_sign         (sum_sign),
        .sum_exponent     (sum_exponent),
        .sum_sticky       (sum_sticky)
    );

    logic [7:0]         norm_significand;
    logic               guard;
    logic               round_sticky;
    logic signed [9:0]  norm_exponent;
    logic               norm_sign;
    logic               is_zero;

    bf16_normalizer normalizer 
    (
        .sum              (sum),
        .sum_sign         (sum_sign),
        .sum_exponent     (sum_exponent),
        .sum_sticky       (sum_sticky),
        .norm_significand (norm_significand),
        .guard            (guard),
        .sticky           (round_sticky),
        .norm_exponent    (norm_exponent),
        .norm_sign        (norm_sign),
        .is_zero          (is_zero)
    );

    logic [15:0] rounded_result;

    bf16_rounder rounder
    (
        .norm_significand (norm_significand),
        .guard            (guard),
        .sticky           (round_sticky),
        .norm_exponent    (norm_exponent),
        .norm_sign        (norm_sign),
        .is_zero          (is_zero),
        .rounded_result   (rounded_result)
    );

    assign fma_result = bypass_arithmetic ? fma_flag_result : rounded_result;
    
endmodule

`endif // _BF16_FMA_TOP_SV_
