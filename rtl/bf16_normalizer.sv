// ================================================================
//
// Date  : August 9, 2026
// Author: Kaan Akan
//
// Normalizes the add/subtract result for the rounder.
//
// The output is an 8-bit significand with the implicit one at bit 7, 
// and guard, sticky bits for rounding.
//
// ================================================================

`ifndef _BF16_NORMALIZER_SV_
`define _BF16_NORMALIZER_SV_

(* keep_hierarchy *)
module bf16_normalizer
(
    // Add/subtract results from addsub
    input  logic [26:0]        sum,
    input  logic               sum_sign,
    input  logic signed [9:0]  sum_exponent,
    input  logic               sum_sticky, 

    // Normalized significand and rounding bits
    output logic [7:0]         norm_significand,
    output logic               guard,
    output logic               sticky,
    output logic signed [9:0]  norm_exponent,
    output logic               norm_sign,
    output logic               is_zero
);

    // Fully zero sum doesn't have a leading one, so flag it
    assign is_zero = (sum == '0);

    // Find leading one in sum
    logic [4:0] leading_one_pos;
    always_comb begin
        leading_one_pos = 0;
        for (int i = 0; i < 27; i++) begin
            if (sum[i]) begin
                leading_one_pos = i;
            end
        end
    end

    // Shift leading one to the top of frame
    logic [26:0] shifted_sum;
    assign shifted_sum = sum << (26 - leading_one_pos);

    // Get top 8 bits for significand and lower rest for rounding
    assign norm_significand =  shifted_sum[26:19];
    assign guard            =  shifted_sum[18];
    assign sticky           = |shifted_sum[17:0] || sum_sticky;

    // Re-anchor exponent to leading one. 
    // Add leading pos for shift and compensate for 2^14 from significand multiply
    assign norm_exponent = sum_exponent + $signed({5'b0, leading_one_pos}) - 10'sd14;
    assign norm_sign     = sum_sign; 

endmodule

`endif // _BF16_NORMALIZER_SV_
