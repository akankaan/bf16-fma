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
// This happens when the product is zero, or the shift is negative; in which case
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

    localparam int WIDTH = 26;
    // Gap between c's parked MSB and the product's unit bit (25-14)
    localparam logic signed [9:0] SHIFT_CONST = 10'sd11;

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
    logic  c_dominates;
    assign c_dominates = product_zero || (!c_zero && (shift < 0));

    // anchor to c; -SHIFT_CONST cancels the shift while parking c at the top of the frame
    logic signed [9:0] c_anchor_exp;
    assign c_anchor_exp = $signed({2'b0, c_exponent}) - SHIFT_CONST;

    // Product itself, or 0 when c dominates (product then survives only as sticky)
    assign aligned_product  = c_dominates ? 26'b0         : {10'b0, product};
    // c's anchor when it dominates, else the product exponent
    assign aligned_exponent = c_dominates ? c_anchor_exp  : product_exponent;

    // Shift c through an explicit binary tree and OR the shifted to sticky
    logic c_sticky,   c_sticky_1, c_sticky_2, 
          c_sticky_4, c_sticky_8, c_sticky_16;

    logic [WIDTH-1:0] shifted_addend, c_shift_1,  c_shift_2,
                      c_shift_4,      c_shift_8,  c_shift_16;

    always_comb begin
        c_shift_1  = shift[0] ? {1'b0,  c_home[25:1]}     : c_home;
        c_shift_2  = shift[1] ? {2'b0,  c_shift_1[25:2]}  : c_shift_1;
        c_shift_4  = shift[2] ? {4'b0,  c_shift_2[25:4]}  : c_shift_2;
        c_shift_8  = shift[3] ? {8'b0,  c_shift_4[25:8]}  : c_shift_4;
        c_shift_16 = shift[4] ? {16'b0, c_shift_8[25:16]} : c_shift_8;

        c_sticky_1  = (shift[0] && c_home[0]);
        c_sticky_2  = (shift[1] && |c_shift_1[1:0])  || c_sticky_1;
        c_sticky_4  = (shift[2] && |c_shift_2[3:0])  || c_sticky_2;
        c_sticky_8  = (shift[3] && |c_shift_4[7:0])  || c_sticky_4;
        c_sticky_16 = (shift[4] && |c_shift_8[15:0]) || c_sticky_8;

        // Any upper shift bit represents a shift of at least 32,
        // which clears the 26 bit frame
        shifted_addend = |shift[10:5] ? '0 : c_shift_16;
        c_sticky       = |shift[10:5] ? |c_home : c_sticky_16;
    end

    // Parked c when it dominates, else shifted right into place
    assign aligned_addend   = c_dominates ? c_home        : shifted_addend;
    // When c dominates, any nonzero product bit sets sticky high, which is !product_zero
    // Else, sticky is the OR of addend bits shifted off the bottom.
    assign sticky           = c_dominates ? !product_zero : c_sticky;


endmodule

`endif // _BF16_ALIGNER_SV_
