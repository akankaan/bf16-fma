// ================================================================
//
// Date  : July 27, 2026
// Author: Kaan Akan
//
// Multiplies two Bfloat16 numbers. 
//
// Conventions used:
// fraction          : 7 stored fraction bits (after implicit 1)
// x_significand     : {1, fraction}                U8,  [128, 255]
// product           : a_significand*b_significand  U16, [16384, 65025]
// x_exponent        : unsigned, biased (127),       [1,254]
// product_exponent  : a_exponent + b_exponent - 127   
//                     biased (127) but still signed,[-125, 381]
// value of product = product * 2^(product_exponent - 127 - 14),
//                    in which 127 from bias and 14 from fraction bits
// ================================================================

`ifndef _BF16_MULTIPLIER_SV_
`define _BF16_MULTIPLIER_SV_

(* keep_hierarchy *)
module bf16_multiplier
(
    input  logic a_sign,
    input  logic b_sign,

    input  logic a_zero,
    input  logic b_zero,

    input  logic [7:0]  a_exponent,
    input  logic [7:0]  b_exponent,

    input  logic [6:0]  a_fraction,
    input  logic [6:0]  b_fraction,

    output logic        product_sign,
    output logic        product_zero,
    output logic [15:0] product,

    output logic signed [9:0]  product_exponent
);

assign product_sign = a_sign ^ b_sign;
assign product_zero = a_zero || b_zero;

logic [7:0] a_significand, b_significand;
assign a_significand = a_zero ? 8'd0 : {1'b1, a_fraction};
assign b_significand = b_zero ? 8'd0 : {1'b1, b_fraction};
assign product       = a_significand * b_significand;

logic signed [9:0] a_exponent_signed, b_exponent_signed;
assign a_exponent_signed = a_exponent;
assign b_exponent_signed = b_exponent;
assign product_exponent  = product_zero ? 
                           (10'sd0) :
                           (a_exponent_signed + b_exponent_signed - 10'sd127);

endmodule

`endif // _BF16_MULTIPLIER_SV_
