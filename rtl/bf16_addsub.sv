// ================================================================
//
// Date  : August 3, 2026
// Author: Kaan Akan
//
// Adds or subtracts the aligned product and addend in sign-magnitude
//
// ================================================================

`ifndef _BF16_ADDSUB_SV_
`define _BF16_ADDSUB_SV_

(* keep_hierarchy *)
module bf16_addsub
(
    // Aligned to same magnitude from aligner
    input  logic [25:0]        aligned_product,
    input  logic [25:0]        aligned_addend,
    input  logic               sticky,
    input  logic signed [9:0]  aligned_exponent,

    // Signs from the multiplier and decode/classify unit
    input  logic               product_sign,
    input  logic               c_sign,

    // Result as sign and magnitude, exponent and sticky for normalization
    output logic [26:0]        sum, // 27-bit magnitude (26-bit frame + carry from add)
    output logic               sum_sign,
    output logic signed [9:0]  sum_exponent,
    output logic               sum_sticky
);
    // If the product and addend signs disagree, the add is effectively a subtraction
    logic  effective_subtraction;
    assign effective_subtraction = c_sign ^ product_sign;

    logic [26:0] magnitude;
    
    always_comb begin
        // Same signs so add magnitude and keep common sign
        if (!effective_subtraction) begin
            magnitude = {1'b0, aligned_product} + {1'b0, aligned_addend};
            sum_sign  = c_sign && product_sign;
        end
        // Different signs, addend larger, so sub magnitude and keep addend's sign
        else if (aligned_addend > aligned_product) begin
            magnitude = {1'b0, aligned_addend} - {1'b0, aligned_product};
            sum_sign  = c_sign;
        end
        // Different signs, product larger, so sub magnitude and keep product's sign
        else if (aligned_addend < aligned_product) begin
            magnitude = {1'b0, aligned_product} - {1'b0, aligned_addend};
            sum_sign  = product_sign;
        end
        // Exact cancellation
        else begin
            magnitude = '0;
            sum_sign  = c_sign && product_sign;
        end
    end

    // On a subtract, we took away too little when there is a sticky
    // which makes the magnitude land a bit high, so take it down by one.
    // Nothing to borrow at zero magnitude, so guard keeps it at zero. 
    logic  decrement;
    assign decrement = effective_subtraction && sticky && (magnitude != '0);
    assign sum = magnitude - {26'b0, decrement};

    assign sum_sticky   = sticky;
    assign sum_exponent = aligned_exponent;

endmodule

`endif // _BF16_ADDSUB_SV_
