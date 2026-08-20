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
    // Operand ordering and controls from addsub prepare
    input  logic               aligned_addend_greater,
    input  logic               effective_subtraction,
    input  logic               result_sign,
    input  logic               subtract_correction,

    // Operands, exponent, and sticky from the aligner
    input  logic [25:0]        aligned_product,
    input  logic [25:0]        aligned_addend,
    input  logic               sticky,
    input  logic signed [9:0]  aligned_exponent,

    // Result as sign and magnitude, exponent and sticky for normalization
    output logic [26:0]        sum, // 27-bit magnitude (26-bit frame + carry from add)
    output logic               sum_sign,
    output logic signed [9:0]  sum_exponent,
    output logic               sum_sticky
);

    logic [26:0] magnitude;
    
    always_comb begin
        if (effective_subtraction) begin
            if (aligned_addend_greater) begin
                magnitude = {1'b0, aligned_addend} - {1'b0, aligned_product};
            end
            else begin
                magnitude = {1'b0, aligned_product} - {1'b0, aligned_addend};
            end
        end
        else begin
            magnitude = {1'b0, aligned_addend} + {1'b0, aligned_product};
        end
    end

    assign sum          = magnitude - {{26{1'b0}}, subtract_correction};
    assign sum_sign     = result_sign;
    assign sum_exponent = aligned_exponent;
    assign sum_sticky   = sticky;

endmodule

`endif // _BF16_ADDSUB_SV_
