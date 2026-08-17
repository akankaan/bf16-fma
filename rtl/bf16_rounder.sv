// ================================================================
//
// Date  : August 10, 2026
// Author: Kaan Akan
//
// Rounds the normalized result with RNE (round to nearest, ties to even)
//
// ================================================================

`ifndef _BF16_ROUNDER_SV_
`define _BF16_ROUNDER_SV_

(* keep_hierarchy *)
module bf16_rounder
(
    // Normalized results
    input  logic [7:0]         norm_significand,
    input  logic               guard,
    input  logic               sticky,
    input  logic signed [9:0]  norm_exponent,
    input  logic               norm_sign,
    input  logic               is_zero,

    // Rounded bf16 result
    output logic [15:0]        rounded_result
);

    // Round up when guard and sticky are high, so past the tie point or
    // at an exact tie so guard is high and sticky is low and the last fraction is odd
    // so round up to even.
    logic  round_up;
    assign round_up = (guard && sticky) || (norm_significand[0] && guard && !sticky);

    // Detect 1.1111111 to 10.0000000 after rounding
    logic  rounding_carry;
    assign rounding_carry = (round_up && (norm_significand == 8'hFF));

    // Post-normalize after possible rounding caused overlfow
    logic signed [9:0] exponent_final;
    logic        [6:0] fraction;
    assign exponent_final = norm_exponent + $signed({9'b0, rounding_carry}); 
    assign fraction       = norm_significand[6:0] + {6'b0, round_up};

    // Pack fields to rounded_result, and apply zero/DAZ and overflow
    always_comb begin
        if (is_zero || (exponent_final <= 0)) begin
            rounded_result = {norm_sign, 15'b0}; // zero or denormals flushed
        end
        else if (exponent_final >= 255) begin
            rounded_result = {norm_sign, 8'hFF, 7'b0}; // overlfow gets signed infinity
        end
        else begin
            rounded_result = {norm_sign, exponent_final[7:0], fraction}; // non-flagged
        end
    end

endmodule

`endif // _BF16_ROUNDER_SV_
