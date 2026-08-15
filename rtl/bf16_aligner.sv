// ================================================================
//
// Date  : July 29, 2026
// Author: Kaan Akan
//
// Aligns the addend c to the product for addition.
//
// The product is fixed in its [15:0] slot; the addend is parked at the top of
// the frame and shifted right into alignment, so shifting is in one direction.
//
// The datapath width comes from where the addend can land relative to the
// product: far above it (keep a whole addend on top), right over it (keep the
// full product), or far below it (guard and sticky bits). Bits above + product
// + guard = 3 * precision + 2 = 26 bits.
//
// Normally everything is anchored to the product except when c dominates the result,
// meaning only the sticky bit of the product can influence the result in an exact tie.
// This happnes when the product is zero, or the shift is negative; in which case
// c sets the result and the exponent re-anchors to c.
//
// ================================================================

`ifndef _BF16_ALIGNER_SV_
`define _BF16_ALIGNER_SV_

(* keep_hierarchy *)
module bf16_aligner
(
    // Product input after multiplication
    input logic [15:0]        product,
    input logic               product_zero,
    input logic signed [9:0]  product_exponent,

    // Addend inputs
    input logic       c_zero,
    input logic [7:0] c_exponent,
    input logic [6:0] c_fraction,

    // Outputs in a 26-bit (3 * precision + 2) datapath, see header
    output logic [25:0]        aligned_product,
    output logic [25:0]        aligned_addend,
    output logic               sticky,
    output logic signed [9:0]  aligned_exponent
);

    localparam int WIDTH       = 26;
    localparam int INDEX       = 18; // c's LSB when unshifted, so c parks at [25:18]
    localparam int SHIFT_CONST = 11; // gap between c's parked MSB and the product's unit bit (25-14)

    // Form addend significand: implicit 1, flushed to 0 on DAZ
    logic [7:0] c_significand;
    assign c_significand = c_zero ? 8'd0 : {1'b1, c_fraction};

    // How many bits c slides down from its home; the sign carries the exponent gap
    logic signed [10:0] shift;
    assign shift = product_exponent - $signed({2'b0, c_exponent}) + SHIFT_CONST;

    // Park c at the top of the frame: [25:18]
    logic [WIDTH-1:0] c_home;
    assign c_home = {c_significand, {(WIDTH-8){1'b0}}};

    // Anchor on c if the product is zero, or if nonzero c lies above the product frame.
    // With DAZ, exponent field 0 denotes arithmetic zero rather than a magnitude exponent
    // (should have been neg inf to denote its magnitude), so it cannot be compared with 
    // the nonzero product's extended exponent for dominance.
    assign c_dominates = product_zero || (!c_zero && (shift < 0));

    // anchor to c; -SHIFT_CONST cancels the shift while parking c at the top of the frame
    logic signed [9:0] c_anchor_exp;
    assign c_anchor_exp = $signed({2'b0, c_exponent}) - SHIFT_CONST;

    // Product itself, or 0 when c dominates (product then survives only as sticky)
    assign aligned_product  = c_dominates ? 26'b0        : product;
    // Parked c when it dominates, else shifted right into place
    assign aligned_addend   = c_dominates ? c_home       : (c_home >> shift);
    // OR of product bits when c dominates, else the OR of addend bits shifted off the bottom
    assign sticky           = c_dominates ? |product     : |(c_home & ((26'b1 << shift) - 1));
    // c's anchor when it dominates, else the product exponent
    assign aligned_exponent = c_dominates ? c_anchor_exp : product_exponent;

endmodule

`endif // _BF16_ALIGNER_SV_
