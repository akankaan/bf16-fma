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

        logic               a_sign;
        logic               b_sign;
        logic               a_zero;
        logic               b_zero;
        logic [7:0]         a_exponent;
        logic [7:0]         b_exponent;
        logic [6:0]         a_fraction;
        logic [6:0]         b_fraction;

        logic               c_zero;
        logic [7:0]         c_exponent;
        logic [6:0]         c_fraction;
        logic               c_sign;

        logic               bypass_arithmetic;
        logic [15:0]        fma_flag_result;
    } decode_classify_to_multiplier_t;

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
        logic               aligned_addend_greater;
        logic               effective_subtraction;
        logic               result_sign;
        logic               subtract_correction;

        logic               sticky;
        logic signed [9:0]  aligned_exponent;

        logic               bypass_arithmetic;
        logic [15:0]        fma_flag_result;
    } addsub_prepare_to_addsub_t;

    typedef struct packed {
        logic               valid;

        logic [26:0]        sum;
        logic               sum_sign;
        logic signed [9:0]  sum_exponent;
        logic               sum_sticky;

        logic               bypass_arithmetic;
        logic [15:0]        fma_flag_result;
    } addsub_to_normalizer_t;

    typedef struct packed {
        logic               valid;

        logic [7:0]         norm_significand;
        logic               guard;
        logic               sticky;
        logic signed [9:0]  norm_exponent;
        logic               norm_sign;
        logic               is_zero;

        logic               bypass_arithmetic;
        logic [15:0]        fma_flag_result;
    } normalizer_to_rounder_t;

    decode_classify_to_multiplier_t  decode_classify_to_multiplier_q;
    multiplier_to_aligner_t          multiplier_to_aligner_q;
    addsub_prepare_to_addsub_t       addsub_prepare_to_addsub_q;
    addsub_to_normalizer_t           addsub_to_normalizer_q;
    normalizer_to_rounder_t          normalizer_to_rounder_q;

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
        .a_sign            (decode_classify_to_multiplier_q.a_sign),
        .b_sign            (decode_classify_to_multiplier_q.b_sign),
        .a_zero            (decode_classify_to_multiplier_q.a_zero),
        .b_zero            (decode_classify_to_multiplier_q.b_zero),
        .a_exponent        (decode_classify_to_multiplier_q.a_exponent),
        .b_exponent        (decode_classify_to_multiplier_q.b_exponent),
        .a_fraction        (decode_classify_to_multiplier_q.a_fraction),
        .b_fraction        (decode_classify_to_multiplier_q.b_fraction),
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

    logic aligned_addend_greater;
    logic effective_subtraction;
    logic result_sign;
    logic subtract_correction;

    bf16_addsub_prepare addsub_prepare
    (
        .aligned_product       (aligned_product),
        .aligned_addend        (aligned_addend),
        .sticky                (sticky),
        .product_sign          (multiplier_to_aligner_q.product_sign),
        .c_sign                (multiplier_to_aligner_q.c_sign),
        .aligned_addend_greater(aligned_addend_greater),
        .effective_subtraction (effective_subtraction),
        .result_sign           (result_sign),
        .subtract_correction   (subtract_correction)
    );

    logic [26:0]        sum;
    logic               sum_sign;
    logic signed [9:0]  sum_exponent;
    logic               sum_sticky;

    bf16_addsub addsub 
    (
        .aligned_addend_greater(addsub_prepare_to_addsub_q.aligned_addend_greater),
        .effective_subtraction (addsub_prepare_to_addsub_q.effective_subtraction),
        .result_sign           (addsub_prepare_to_addsub_q.result_sign),
        .subtract_correction   (addsub_prepare_to_addsub_q.subtract_correction),
        .aligned_product      (addsub_prepare_to_addsub_q.aligned_product),
        .aligned_addend       (addsub_prepare_to_addsub_q.aligned_addend),
        .sticky               (addsub_prepare_to_addsub_q.sticky),
        .aligned_exponent     (addsub_prepare_to_addsub_q.aligned_exponent),
        .sum                  (sum),
        .sum_sign             (sum_sign),
        .sum_exponent         (sum_exponent),
        .sum_sticky           (sum_sticky)
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
        .norm_significand (normalizer_to_rounder_q.norm_significand),
        .guard            (normalizer_to_rounder_q.guard),
        .sticky           (normalizer_to_rounder_q.sticky),
        .norm_exponent    (normalizer_to_rounder_q.norm_exponent),
        .norm_sign        (normalizer_to_rounder_q.norm_sign),
        .is_zero          (normalizer_to_rounder_q.is_zero),
        .rounded_result   (rounded_result)
    );

    logic [15:0] selected_result;
    assign selected_result = normalizer_to_rounder_q.bypass_arithmetic ?
                             normalizer_to_rounder_q.fma_flag_result :
                             rounded_result;

    // Pipeline register 
    always_ff @(posedge clk) begin
        if (!rst_n) begin
            decode_classify_to_multiplier_q <= '0;
            multiplier_to_aligner_q         <= '0;
            addsub_prepare_to_addsub_q       <= '0;
            addsub_to_normalizer_q           <= '0;
            normalizer_to_rounder_q          <= '0;
            fma_result                       <= '0;
            fma_result_valid                 <= '0;
        end
        else begin
            // First boundary (decode and classify)
            decode_classify_to_multiplier_q.valid             <= operands_valid;
            decode_classify_to_multiplier_q.a_sign            <= a_sign;
            decode_classify_to_multiplier_q.b_sign            <= b_sign;
            decode_classify_to_multiplier_q.a_zero            <= a_zero;
            decode_classify_to_multiplier_q.b_zero            <= b_zero;
            decode_classify_to_multiplier_q.a_exponent        <= a_exponent;
            decode_classify_to_multiplier_q.b_exponent        <= b_exponent;
            decode_classify_to_multiplier_q.a_fraction        <= a_fraction;
            decode_classify_to_multiplier_q.b_fraction        <= b_fraction;
            decode_classify_to_multiplier_q.c_zero            <= c_zero;
            decode_classify_to_multiplier_q.c_exponent        <= c_exponent;
            decode_classify_to_multiplier_q.c_fraction        <= c_fraction;
            decode_classify_to_multiplier_q.c_sign            <= c_sign;
            decode_classify_to_multiplier_q.bypass_arithmetic <= bypass_arithmetic;
            decode_classify_to_multiplier_q.fma_flag_result   <= fma_flag_result;

            // Second boundary (multiplier)
            multiplier_to_aligner_q.valid             <= decode_classify_to_multiplier_q.valid;
            multiplier_to_aligner_q.product           <= product;
            multiplier_to_aligner_q.product_zero      <= product_zero;
            multiplier_to_aligner_q.product_exponent  <= product_exponent;
            multiplier_to_aligner_q.product_sign      <= product_sign;
            multiplier_to_aligner_q.c_zero            <= decode_classify_to_multiplier_q.c_zero;
            multiplier_to_aligner_q.c_exponent        <= decode_classify_to_multiplier_q.c_exponent;
            multiplier_to_aligner_q.c_fraction        <= decode_classify_to_multiplier_q.c_fraction;
            multiplier_to_aligner_q.c_sign            <= decode_classify_to_multiplier_q.c_sign;
            multiplier_to_aligner_q.bypass_arithmetic <= decode_classify_to_multiplier_q.bypass_arithmetic;
            multiplier_to_aligner_q.fma_flag_result   <= decode_classify_to_multiplier_q.fma_flag_result;

            // Third boundary (aligner, addsub prepare)
            addsub_prepare_to_addsub_q.valid                  <= multiplier_to_aligner_q.valid;
            addsub_prepare_to_addsub_q.aligned_product        <= aligned_product;
            addsub_prepare_to_addsub_q.aligned_addend         <= aligned_addend;
            addsub_prepare_to_addsub_q.aligned_addend_greater <= aligned_addend_greater;
            addsub_prepare_to_addsub_q.effective_subtraction  <= effective_subtraction;
            addsub_prepare_to_addsub_q.result_sign            <= result_sign;
            addsub_prepare_to_addsub_q.subtract_correction    <= subtract_correction;
            addsub_prepare_to_addsub_q.sticky                 <= sticky;
            addsub_prepare_to_addsub_q.aligned_exponent       <= aligned_exponent;
            addsub_prepare_to_addsub_q.bypass_arithmetic      <= multiplier_to_aligner_q.bypass_arithmetic;
            addsub_prepare_to_addsub_q.fma_flag_result        <= multiplier_to_aligner_q.fma_flag_result;

            // Fourth boundary (addsub)
            addsub_to_normalizer_q.valid              <= addsub_prepare_to_addsub_q.valid;
            addsub_to_normalizer_q.sum                <= sum;
            addsub_to_normalizer_q.sum_sign           <= sum_sign;
            addsub_to_normalizer_q.sum_exponent       <= sum_exponent;
            addsub_to_normalizer_q.sum_sticky         <= sum_sticky;
            addsub_to_normalizer_q.bypass_arithmetic  <= addsub_prepare_to_addsub_q.bypass_arithmetic;
            addsub_to_normalizer_q.fma_flag_result    <= addsub_prepare_to_addsub_q.fma_flag_result;

            // Fifth boundary (normalizer)
            normalizer_to_rounder_q.valid             <= addsub_to_normalizer_q.valid;
            normalizer_to_rounder_q.norm_significand  <= norm_significand;
            normalizer_to_rounder_q.guard             <= guard;
            normalizer_to_rounder_q.sticky            <= round_sticky;
            normalizer_to_rounder_q.norm_exponent     <= norm_exponent;
            normalizer_to_rounder_q.norm_sign         <= norm_sign;
            normalizer_to_rounder_q.is_zero           <= is_zero;
            normalizer_to_rounder_q.bypass_arithmetic <= addsub_to_normalizer_q.bypass_arithmetic;
            normalizer_to_rounder_q.fma_flag_result   <= addsub_to_normalizer_q.fma_flag_result;

            // Sixth boundary (rounder)
            fma_result       <= selected_result;
            fma_result_valid <= normalizer_to_rounder_q.valid;
        end
    end

    // Assertions
    `ifndef SYNTHESIS

    logic [5:0] valid_history; // shift register

    always @(posedge clk) begin
        if (!rst_n) begin
            valid_history <= '0;
        end
        else begin
            // Output latency
            assert (fma_result_valid == valid_history[5]) // expecting 6 cycles late
                else $fatal(1, "FMA CORE ASSERT: incorrect pipeline valid latency");

            valid_history <= {valid_history[4:0], operands_valid};

            // Multiplier output
            if (decode_classify_to_multiplier_q.valid) begin
                assert (product_zero == (product == 16'b0))
                else $fatal(1, "MULTIPLIER ASSERT: inconsistent product_zero");

                // Product should either be zero or have its unit or carry bit high
                assert (product_zero || product[15] || product[14])
                else $fatal(1, "MULTIPLIER ASSERT: product outside expected range");
            end
            
            // Aligner and addsub prepare output
            if (multiplier_to_aligner_q.valid) begin
                // Product doesn't move up from its frame. Either it stays in 
                // frame or c_dominates, making it effectively zero
                assert (aligned_product[25:16] == 10'b0)
                else $fatal(1, "ALIGNER ASSERT: product moved from its frame");

                assert (aligned_addend_greater == (aligned_addend > aligned_product))
                else $fatal(1, "ADDSUB PREPARE ASSERT: incorrect addeng greater comparison");

                if (subtract_correction) begin
                    assert (effective_subtraction)
                        else $fatal(1, "ADDSUB PREPARE ASSERT: correction without subtraction");

                    assert (sticky)
                        else $fatal(1, "ADDSUB PREPARE ASSERT: correction without sticky");

                    assert (aligned_addend != aligned_product)
                        else $fatal(1, "ADDSUB PREPARE ASSERT: correction subtraction from zero");
                end
            end

            // Addsub outputs
            if (addsub_prepare_to_addsub_q.valid) begin
                if (addsub_prepare_to_addsub_q.effective_subtraction && 
                   (addsub_prepare_to_addsub_q.aligned_addend == 
                    addsub_prepare_to_addsub_q.aligned_product)) begin
                    assert (sum == 27'b0)
                    else $fatal(1, "ADDSUB ASSERT: exact cancellation is nonzero");
                end

                if (addsub_prepare_to_addsub_q.effective_subtraction) begin
                    assert (!sum[26])
                    else $fatal(1, "ADDSUB ASSERT: subtraction resulted in carry");
                end
            end

            // Normalizer outputs
            if (addsub_to_normalizer_q.valid) begin
                assert (is_zero || norm_significand[7])
                else $fatal(1, "NORMALIZER ASSERT: result is not normalized");
            end

            // Rounder outputs
            if (normalizer_to_rounder_q.valid) begin

                assert (rounded_result[15] == normalizer_to_rounder_q.norm_sign)
                else $fatal(1, "ROUNDER ASSERT: sign changed during roundung");

                // no subnormal result, fraction should be flushed to zero if exp zero
                 assert ((rounded_result[14:7] != 8'h00) ||
                         (rounded_result[6:0] == 7'b0))
                else $fatal(1, "ROUNDER ASSERT: produced subnormal result");
            end

        end
    end

    `endif
    
endmodule

`endif // _BF16_FMA_CORE_SV_
