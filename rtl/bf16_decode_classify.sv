// ================================================================
//
// Date  : July 24, 2026
// Author: Kaan Akan
//
// Decodes Bfloat16 and classifies based on special flags (NaN and inf)
//
// ================================================================

`ifndef _BF16_DECODE_CLASSIFY_SV_
`define _BF16_DECODE_CLASSIFY_SV_

module bf16_decode_classify
(
    input  logic [15:0] a,
    input  logic [15:0] b,
    input  logic [15:0] c,

    output logic a_sign,
    output logic b_sign,
    output logic c_sign,

    output logic a_zero,
    output logic b_zero,
    output logic c_zero,

    output logic [7:0] a_exponent,
    output logic [7:0] b_exponent,
    output logic [7:0] c_exponent,

    output logic [6:0] a_fraction,
    output logic [6:0] b_fraction,
    output logic [6:0] c_fraction,      

    output logic        bypass_arithmetic, 
    output logic [15:0] fma_flag_result
);

    // Decode sign, exponent, and significand fields according to 
    // following format: {sign[15],exponent[14:7], significand[6:0]}
    assign a_sign = a[15];
    assign b_sign = b[15];
    assign c_sign = c[15];

    assign a_exponent = a[14:7];
    assign b_exponent = b[14:7];
    assign c_exponent = c[14:7];

    assign a_fraction = a[6:0];
    assign b_fraction = b[6:0];
    assign c_fraction = c[6:0];
    

    logic  multiplication_sign;
    assign multiplication_sign = a_sign ^ b_sign;

    logic a_nan,  b_nan,  c_nan;
    logic a_inf,  b_inf,  c_inf;

    // Check for special case flagged inputs, 
    // if so set flag result and set bypass_arithmetic high
    always_comb begin
        a_nan  = (a_exponent == 8'hFF ) && (a_fraction != 7'h0);
        b_nan  = (b_exponent == 8'hFF ) && (b_fraction != 7'h0);
        c_nan  = (c_exponent == 8'hFF ) && (c_fraction != 7'h0);

        a_inf  = (a_exponent == 8'hFF ) && (a_fraction == 7'h0);
        b_inf  = (b_exponent == 8'hFF ) && (b_fraction == 7'h0);
        c_inf  = (c_exponent == 8'hFF ) && (c_fraction == 7'h0);

        a_zero = (a_exponent == 8'h0);
        b_zero = (b_exponent == 8'h0);
        c_zero = (c_exponent == 8'h0);

        // Return NaN for any NaN input
        if (a_nan | b_nan | c_nan ) begin
            bypass_arithmetic = 1'b1;
            fma_flag_result   = 16'h7FC0;
        end
        // Return NaN when one multiplicand is infinite and the other zero
        else if ((a_inf && b_zero) || (a_zero && b_inf)) begin
            bypass_arithmetic = 1'b1;
            fma_flag_result   = 16'h7FC0;
        end
        // Return NaN when inf multiplication's sign doesn't match infinite addend's sign
        else if ((multiplication_sign != c_sign) && (a_inf || b_inf) && c_inf) begin
            bypass_arithmetic = 1'b1;
            fma_flag_result   = 16'h7FC0;
        end
        // Return inf, with appopriate sign, when at least one multiplicand is inf.
        // c is either finite or same signed inf due to previous else if
        else if (a_inf || b_inf) begin
            bypass_arithmetic = 1'b1;
            fma_flag_result   = {multiplication_sign, 8'hFF, 7'd0};
        end
        // Return inf, with appopriate sign, when addend is inf, multiplicands are finite
        else if (c_inf) begin
            bypass_arithmetic = 1'b1;
            fma_flag_result   = {c_sign, 8'hFF, 7'd0};
        end
        // No special flags so arithmetic should occur
        else begin 
            bypass_arithmetic = '0;
            fma_flag_result   = '0;
        end
    end

endmodule

`endif // _BF16_DECODE_CLASSIFY_SV_
