// ================================================================
//
// Date  : August 3, 2026
// Author: Kaan Akan
//
// Adds or subtracts the aligned product and addend in two's complement.
//
// The effective operation is an add when the product and addend share a sign,
// and a subtract when they differ. Each operand is taken to two's complement by
// its sign, summed in the 26-bit frame (plus one carry bit), and the signed
// result is split back into a sign and a magnitude for the normalizer.
//
// The exponent and sticky bit pass through to the normalizer.
//
// ================================================================

`ifndef _BF16_ADDSUB_SV_
`define _BF16_ADDSUB_SV_

module bf16_addsub
(
    // Aligned to same magnitude from aligner
    input  logic [25:0]        aligned_product,
    input  logic [25:0]        aligned_addend,
    input  logic               sticky,
    input  logic signed [9:0]  aligned_exponent,

    // Signs from the multiplier and decoder 
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

    // Take magnitude to two's complement using its sign and add
    logic signed [27:0] signed_product, signed_addend, signed_sum;
    assign signed_product = product_sign ? -$signed({2'b0, aligned_product}) : 
                                            $signed({2'b0, aligned_product});
                            
    assign signed_addend = c_sign ? -$signed({2'b0, aligned_addend}) : 
                                     $signed({2'b0, aligned_addend});

    assign signed_sum = signed_product + signed_addend;

    // Split sign and magnitude
    assign sum_sign = signed_sum[27];
    logic [26:0] magnitude;
    assign magnitude = sum_sign ? -signed_sum : signed_sum;

    // On a subtract, the smaller operand is the one that dropped bits into sticky, so we took
    // away a bit too little which makes the magnitude land a bit high, so take it down by one
    // when there's an effective subtraction and sticky
    assign sum = magnitude - (effective_subtraction & sticky);
    assign sum_sticky   = sticky;
    assign sum_exponent = aligned_exponent;

endmodule

`endif // _BF16_ADDSUB_SV_
