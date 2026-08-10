// ================================================================
//
// Date  : August 10, 2026
// Author: Kaan Akan
//
// Testbench for the Bfloat16 FMA result outputter.
//
// Starts with a input result, then corrupts the result input on the next
// cycle, and checks the low then high byte come out with busy high.
//
// ================================================================

`ifndef _BF16_OUTPUTTER_TB_SV_
`define _BF16_OUTPUTTER_TB_SV_

module bf16_outputter_tb;

    logic        clk = 0;
    logic        rst_n;
    logic [15:0] result;
    logic        start;
    logic [7:0]  out_byte;
    logic        busy;

    integer errors = 0;

    bf16_outputter dut
    (
        .clk      (clk),
        .rst_n    (rst_n),
        .result   (result),
        .start    (start),
        .out_byte (out_byte),
        .busy     (busy)
    );

    always #5 clk = ~clk;

    task check(input logic cond, input string msg);
        if (!cond) begin
            errors = errors + 1;
            $display("FAIL: %s", msg);
        end
    endtask

    initial begin
        // Reset before start
        rst_n = 0; start = 0; result = '0;
        @(posedge clk);

        // Start an output of 0xABCD
        @(negedge clk); rst_n = 1; start = 1; result = 16'hABCD;
        @(posedge clk); #1;         // low byte out in first cycle
        check(busy === 1'b1,        "busy high on cycle 1");
        check(out_byte === 8'hCD,   "low byte out on cycle 1");

        // Corrupt result to test the high byte being latched
        @(negedge clk); start = 0; result = 16'hDEAD;
        @(posedge clk); #1;          // high byte out in second cycle
        check(busy === 1'b1,        "busy high on cycle 2");
        check(out_byte === 8'hAB,   "high byte out on cycle 2");

        @(posedge clk); #1;
        check(busy === 1'b0,        "not busy on cycle 3");
        check(out_byte === 8'h00,   "out_byte zeros on cycle 3");

        if (errors == 0) $display("OUTPUTTER TB: PASS");
        else             $display("OUTPUTTER TB: %0d errors", errors);
        $finish;
    end

endmodule

`endif // _BF16_OUTPUTTER_TB_SV_
