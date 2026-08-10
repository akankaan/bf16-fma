// ================================================================
//
// Date  : August 11, 2026
// Author: Kaan Akan
//
// Result outputter for the Bfloat16 FMA IO sequencer.
//
// On start, latches result and drives it out over the 8-bit uo_out
// bus across two cycles.
//
// ================================================================

`ifndef _BF16_OUTPUTTER_SV_
`define _BF16_OUTPUTTER_SV_

module bf16_outputter
(
    input  logic        clk,
    input  logic        rst_n,

    // Result to send, and a pulse to latch and send
    input  logic [15:0] result,
    input  logic        start,

    // One byte per cycle onto uo_out (low byte first), busy while sending
    output logic [7:0]  out_byte,
    output logic        busy
);

    // Byte index tracker
    logic byte_index;
    always_ff @(posedge clk) begin
        if (!rst_n) begin
            byte_index <= '0;
        end
        // Count if start is high or if counting had already started
        else if (start || (byte_index != '0)) begin
            if (byte_index == 1'b1) begin
                byte_index <= '0;
            end
            else begin
                byte_index <= byte_index + 1'b1;
            end
        end
    end

    // Result register
    logic [15:0] result_register;
    always_ff @(posedge clk) begin
        if (!rst_n) begin
            result_register <= '0;
        end
        else if (start) begin
            result_register <= result;
        end
    end

    // Register busy when start is received or when count has started
    always_ff @(posedge clk) begin
        if (!rst_n) begin
            out_byte <= '0;
            busy     <= '0;
        end
        else if (start && (byte_index == '0)) begin
            // Use result directly since it's not latched in result_register yet
            out_byte <= result[7:0];
            busy     <= 1'b1;
        end
        else if (byte_index == 1'b1) begin
            out_byte <= result_register[15:8];
            busy     <= 1'b1;
        end
        else begin
            out_byte <= 1'b0;
            busy     <= 1'b0;
        end
    end

endmodule

`endif // _BF16_OUTPUTTER_SV_
