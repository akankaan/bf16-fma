// ================================================================
//
// Date  : July 24, 2026
// Author: Kaan Akan
//
// Bfloat16 FMA (Fused Multiply Add) unit top file
//
// ================================================================

`ifndef _BF16_FMA_TOP_SV_
`define _BF16_FMA_TOP_SV_

module bf16_fma_top 
(
    input  logic [15:0] a, // First multiplicand
    input  logic [15:0] b, // Second multiplicand
    input  logic [15:0] c, // Addend

    output logic [15:0] fma_result
);

    assign fma_result = a; // Stub to be replaced; will test the tester fails with this

endmodule

`endif // _BF16_FMA_TOP_SV_
