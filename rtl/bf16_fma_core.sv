// ================================================================
//
// Date  : July 24, 2026
// Author: Kaan Akan
//
// Bfloat16 FMA (Fused Multiply Add) unit compute core
//
// ================================================================

`ifndef _BF16_FMA_CORE_SV_
`define _BF16_FMA_CORE_SV_

module bf16_fma_core 
(
    input  logic clk,
    input  logic rst_n,
    input  logic operands_valid,

    input  logic [15:0] a, // First  multiplicand
    input  logic [15:0] b, // Second multiplicand
    input  logic [15:0] c, // Addend

    output logic [15:0] fma_result,
    output logic        fma_result_valid

);

    // Pipeline register data structs
    typedef struct packed {
        logic               valid;

        logic [15:0]        product;
        logic               product_zero;
        logic signed [9:0]  product_exponent;
        logic               product_sign;

        logic               c_zero;
        logic [7:0]         c_exponent;
        logic [6:0]         c_fraction;
        logic               c_sign;

        logic               bypass_arithmetic;
        logic [15:0]        fma_flag_result;
    } multiplier_to_aligner_t;

    typedef struct packed {
        logic               valid;

        logic [25:0]        aligned_product;
        logic [25:0]        aligned_addend;
        logic               sticky;
        logic signed [9:0]  aligned_exponent;
        logic               product_sign;
        logic               c_sign;

        logic               bypass_arithmetic;
        logic [15:0]        fma_flag_result;
    } aligner_to_addsub_t;

    typedef struct packed {
        logic               valid;

        logic [26:0]        sum;
        logic               sum_sign;
        logic signed [9:0]  sum_exponent;
        logic               sum_sticky;

        logic               bypass_arithmetic;
        logic [15:0]        fma_flag_result;
    } addsub_to_normalizer_t;

    aligner_to_addsub_t     aligner_to_addsub_q;
    addsub_to_normalizer_t  addsub_to_normalizer_q;
    multiplier_to_aligner_t multiplier_to_aligner_q;

    // Main FMA implementation starts here
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
        .product          (multiplier_to_aligner_q.product),
        .product_zero     (multiplier_to_aligner_q.product_zero),
        .product_exponent (multiplier_to_aligner_q.product_exponent),
        .c_zero           (multiplier_to_aligner_q.c_zero),
        .c_exponent       (multiplier_to_aligner_q.c_exponent),
        .c_fraction       (multiplier_to_aligner_q.c_fraction),
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
        .aligned_product  (aligner_to_addsub_q.aligned_product),
        .aligned_addend   (aligner_to_addsub_q.aligned_addend),
        .sticky           (aligner_to_addsub_q.sticky),
        .aligned_exponent (aligner_to_addsub_q.aligned_exponent),
        .product_sign     (aligner_to_addsub_q.product_sign),
        .c_sign           (aligner_to_addsub_q.c_sign),
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
        .sum              (addsub_to_normalizer_q.sum),
        .sum_sign         (addsub_to_normalizer_q.sum_sign),
        .sum_exponent     (addsub_to_normalizer_q.sum_exponent),
        .sum_sticky       (addsub_to_normalizer_q.sum_sticky),
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

    logic [15:0] selected_result;
    assign selected_result = addsub_to_normalizer_q.bypass_arithmetic ? 
                             addsub_to_normalizer_q.fma_flag_result : 
                             rounded_result;

    // Pipeline register 
    always_ff @(posedge clk) begin
        if (!rst_n) begin
            multiplier_to_aligner_q <= '0;
            aligner_to_addsub_q    <= '0;
            addsub_to_normalizer_q <= '0;
            fma_result             <= '0;
            fma_result_valid       <= '0;
        end
        else begin
            // First boundary (decoder, multiplier)
            multiplier_to_aligner_q.valid             <= operands_valid;
            multiplier_to_aligner_q.product           <= product;
            multiplier_to_aligner_q.product_zero      <= product_zero;
            multiplier_to_aligner_q.product_exponent  <= product_exponent;
            multiplier_to_aligner_q.product_sign      <= product_sign;
            multiplier_to_aligner_q.c_zero            <= c_zero;
            multiplier_to_aligner_q.c_exponent        <= c_exponent;
            multiplier_to_aligner_q.c_fraction        <= c_fraction;
            multiplier_to_aligner_q.c_sign            <= c_sign;
            multiplier_to_aligner_q.bypass_arithmetic <= bypass_arithmetic;
            multiplier_to_aligner_q.fma_flag_result   <= fma_flag_result;

            // Second boundary (aligner)
            aligner_to_addsub_q.valid                 <= multiplier_to_aligner_q.valid;
            aligner_to_addsub_q.aligned_product       <= aligned_product;
            aligner_to_addsub_q.aligned_addend        <= aligned_addend;
            aligner_to_addsub_q.sticky                <= sticky;
            aligner_to_addsub_q.aligned_exponent      <= aligned_exponent;
            aligner_to_addsub_q.product_sign          <= multiplier_to_aligner_q.product_sign;
            aligner_to_addsub_q.c_sign                <= multiplier_to_aligner_q.c_sign;
            aligner_to_addsub_q.bypass_arithmetic     <= multiplier_to_aligner_q.bypass_arithmetic;
            aligner_to_addsub_q.fma_flag_result       <= multiplier_to_aligner_q.fma_flag_result;

            // Third boundary (addsub)
            addsub_to_normalizer_q.valid              <= aligner_to_addsub_q.valid;
            addsub_to_normalizer_q.sum                <= sum;
            addsub_to_normalizer_q.sum_sign           <= sum_sign;
            addsub_to_normalizer_q.sum_exponent       <= sum_exponent;
            addsub_to_normalizer_q.sum_sticky         <= sum_sticky;
            addsub_to_normalizer_q.bypass_arithmetic  <= aligner_to_addsub_q.bypass_arithmetic;
            addsub_to_normalizer_q.fma_flag_result    <= aligner_to_addsub_q.fma_flag_result;

            // Fourth boundary (normalizer, rounder)
            fma_result       <= selected_result;
            fma_result_valid <= addsub_to_normalizer_q.valid; 
        end
    end
    
endmodule

`endif // _BF16_FMA_CORE_SV_
