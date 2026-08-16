// ================================================================
//
// Date  : August 3, 2026
// Author: Kaan Akan
//
// Adds or subtracts the aligned product and addend in two's complement.
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

    // Take magnitude to two's complement, 28th bit is for possible carry in addition
    logic signed [27:0] signed_product, signed_addend, signed_sum;
    assign signed_product = product_sign ? -$signed({2'b0, aligned_product}) : 
                                            $signed({2'b0, aligned_product});

    assign signed_addend = c_sign ? -$signed({2'b0, aligned_addend}) : 
                                     $signed({2'b0, aligned_addend});

    assign signed_sum = signed_product + signed_addend;
    assign sum_sign   = signed_sum[27];

    // Take absolute value at full width, then narrow to 27-bit
    logic [26:0] magnitude;
    assign magnitude = 27'(sum_sign ? -signed_sum : signed_sum);

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
