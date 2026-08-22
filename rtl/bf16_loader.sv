// ================================================================
//
// Date  : August 10, 2026
// Author: Kaan Akan
//
// Operand loader for the Bfloat16 FMA IO sequencer.
//
// Captures the three 16-bit operands one word per cycle from the
// 16-bit input bus, and sets operands_valid high when operands are loaded.
// It accepts an operand whenever in_valid is high, and supports bubbles
// between operand loads.
//
// ================================================================

`ifndef _BF16_LOADER_SV_
`define _BF16_LOADER_SV_

module bf16_loader
(
    input  logic        clk,
    input  logic        rst_n,

    // 16-bit input word: operand a, then b, then c, on consecutive cycles
    input  logic        in_valid,
    input  logic [15:0] in_data,

    // Assembled operands, and a pulse when all three are loaded and stable
    output logic [15:0] a,
    output logic [15:0] b,
    output logic [15:0] c,
    output logic        operands_valid
);

// Input index tracker
logic [1:0] input_index;

always_ff @ (posedge clk) begin
    if (!rst_n) begin
        input_index <= '0;
    end
    else if (in_valid) begin
        // Back to first input of next operation after last input of previous
        if (input_index == 2'd2) begin
            input_index <= '0;
        end
        else begin
            input_index <= input_index + 2'b1;
        end
    end
end

always_ff @(posedge clk) begin
    if (!rst_n) begin
        operands_valid <= 1'b0;
        a <= '0;
        b <= '0;
        c <= '0;
    end
    else begin
        // Default low so operands_valid remains a one-cycle pulse
        // in case in_val remains low at index 2
        operands_valid <= 1'b0; 

        if (in_valid) begin
            operands_valid <= (input_index == 2'd2);
            case (input_index)
                2'd0: a <= in_data;
                2'd1: b <= in_data;
                2'd2: c <= in_data;
                default: begin end
            endcase
        end
    end

end

endmodule

`endif // _BF16_LOADER_SV_
