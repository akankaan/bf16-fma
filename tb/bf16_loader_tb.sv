// ================================================================
//
// Date  : August 10, 2026
// Author: Kaan Akan
//
// Testbench for the Bfloat16 FMA operand loader.
//
// Inputs two operand triples and checks that a/b/c gets captured in order and
// that operands_valid gets high for one cycle after input is completed.
//
// ================================================================

`ifndef _BF16_LOADER_TB_SV_
`define _BF16_LOADER_TB_SV_

module bf16_loader_tb;

    logic        clk = 0;
    logic        rst_n;
    logic [15:0] in_data;
    logic [15:0] a, b, c;
    logic        operands_valid;

    integer errors = 0;

    bf16_loader dut
    (
        .clk            (clk),
        .rst_n          (rst_n),
        .in_data        (in_data),
        .a              (a),
        .b              (b),
        .c              (c),
        .operands_valid (operands_valid)
    );

    always #5 clk = ~clk;

    task check(input logic cond, input string msg);
        if (!cond) begin
            errors = errors + 1;
            $display("FAIL: %s", msg);
        end
    endtask

    initial begin
        // Reset before test
        rst_n = 0; in_data = '0;
        @(posedge clk);                                   

        // First triple: a=1111, b=2222, c=3333
        @(negedge clk); rst_n = 1; in_data = 16'h1111;
        @(posedge clk);
        @(negedge clk); in_data = 16'h2222;
        @(posedge clk);
        @(negedge clk); in_data = 16'h3333;
        @(posedge clk); #1;                  // final input captured, valid goes high
        check(operands_valid === 1'b1, "operands_valid goes high after first triple");
        check(a === 16'h1111, "a captured");
        check(b === 16'h2222, "b captured");
        check(c === 16'h3333, "c captured");

        // Second triple: valid must go low while loading, then go high after c
        @(negedge clk); in_data = 16'h4444;
        @(posedge clk); #1;
        check(operands_valid === 1'b0, "operands_valid low after first load completes");
        @(negedge clk); in_data = 16'h5555;
        @(posedge clk);
        @(negedge clk); in_data = 16'h6666;
        @(posedge clk); #1;
        check(operands_valid === 1'b1, "operands_valid goes high after second triple");
        check(a === 16'h4444, "a captured");
        check(b === 16'h5555, "b captured");
        check(c === 16'h6666, "c captured");

        if (errors == 0) $display("LOADER TB: PASS");
        else             $display("LOADER TB: %0d errors", errors);
        $finish;
    end

endmodule

`endif // _BF16_LOADER_TB_SV_
