// ================================================================
//
// Date  : July 29, 2026
// Author: Kaan Akan
//
// Aligns the addend c to the product for addition
//
// ================================================================

`ifndef _BF16_ALIGNER_SV_
`define _BF16_ALIGNER_SV_

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

    // The size of the datapath is based on where the addend can land relative to the product:
    // far above the product, then keep a whole addend on top; right over it, then keep the full product, 
    // or far below the product, then guard and a sticky bit 
    // Bits above + product + guard is 3 * precision + 2: 26 bits
    output logic [25:0]        aligned_product,
    output logic [25:0]        aligned_addend,
    output logic               sticky,
    output logic signed [9:0]  aligned_exponent
);

    localparam int WIDTH       = 26;
    localparam int INDEX       = 18; // c's LSB is indexed at bit 18 when unshifted so [25:18]
    localparam int SHIFT_CONST = 11; // index difference between c's MSB and prod's unit bit (25-14)

    // Form addend mantissa
    logic [7:0] c_mantissa;
    assign c_mantissa = c_zero ? 8'd0 : {1'b1, c_fraction};

    // Product is fixed in its [15:0] slot; addend starts at top of frame
    // and shifted right into alignment so shifting is only in one directon 
    assign aligned_product = product; // automatically zero enxtreds to 26 bits

    // Determine how many bits c slides fown from its [25:18] position
    logic signed [10:0] shift;
    assign shift = product_exponent - $signed({2'b0, c_exponent}) + 11;

    // Locate c at the top and shift right into its place
    logic [WIDTH-1:0] c_home;
    assign c_home         = {c_mantissa, {{WIDTH-8}{1'b0}}};
    assign aligned_addend = c_home >> shift;

    // Sticky bit is the OR of all bits that got shifted right
    assign sticky = |( c_home & ((26'b1 << shift) - 1) );

    // Product anchor
    assign aligned_exponent = product_exponent;

endmodule

`endif // _BF16_ALIGNER_SV_
