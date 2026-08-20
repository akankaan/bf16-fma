// ================================================================
//
// Date  : August 20, 2026
// Author: Kaan Akan
//
// Prepares aligned sign-magnitude operands for addition or subtraction
//
// ================================================================

`ifndef _BF16_ADDSUB_PREPARE_SV_
`define _BF16_ADDSUB_PREPARE_SV_

(* keep_hierarchy *)
module bf16_addsub_prepare
(
    // Aligned magnitudes and sticky bit from the aligner
    input  logic [25:0] aligned_product,
    input  logic [25:0] aligned_addend,
    input  logic        sticky,

    // Signs from the multiplier and decode/classify unit
    input  logic        product_sign,
    input  logic        c_sign,

    // Ordered magnitudes and controls for addsub
    output logic [25:0] larger_magnitude,
    output logic [25:0] smaller_magnitude,
    output logic        effective_subtraction,
    output logic        result_sign,
    output logic        subtract_correction
);

    // If the product and addend signs disagree, the add is effectively a subtraction
    assign effective_subtraction = c_sign ^ product_sign;

    always_comb begin
        // Same signs so add magnitude and keep common sign;
        // ordering doesn't matter for addition
        if (!effective_subtraction) begin
            larger_magnitude  = aligned_addend;
            smaller_magnitude = aligned_product;
            result_sign       = c_sign && product_sign;
        end
        // Different signs, addend larger, so keep addend's sign
        else if (aligned_addend > aligned_product) begin
            larger_magnitude  = aligned_addend;
            smaller_magnitude = aligned_product;
            result_sign       = c_sign;
        end
        // Different signs, product larger, so sub magnitude and keep product's sign
        else if (aligned_addend < aligned_product) begin
            larger_magnitude  = aligned_product;
            smaller_magnitude = aligned_addend;
            result_sign       = product_sign;
        end
        // Exact cancellation, send zeros
        else begin
            larger_magnitude  = '0;
            smaller_magnitude = '0;
            result_sign       = c_sign && product_sign;
        end
    end

    // On a subtract, we took away too little when there is a sticky
    // which makes the magnitude land a bit high, so take it down by one.
    // Nothing to borrow at zero magnitude, so guard keeps it at zero. 
    assign subtract_correction = effective_subtraction && sticky && 
                                !(aligned_addend == aligned_product);
endmodule

`endif // _BF16_ADDSUB_PREPARE_SV_
