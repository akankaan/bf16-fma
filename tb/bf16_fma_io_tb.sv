// ================================================================
//
// Date  : August 11, 2026
// Author: Kaan Akan
//
// Testbench for the Bfloat16 FMA IO sequencer.
//
// ================================================================

`ifndef _BF16_FMA_IO_TB_SV_
`define _BF16_FMA_IO_TB_SV_

module bf16_fma_io_tb;

    logic        clk = 0;
    logic        rst_n;
    logic [15:0] in_data;
    logic [15:0] a, b, c;
    logic        operands_valid;
    logic        fma_result_valid;
    logic [15:0] fma_result;
    logic [7:0]  out_data;
    logic        result_valid;

    integer num_vectors = 0;
    integer errors = 0;

    bf16_fma_io dut
    (
        .clk              (clk),
        .rst_n            (rst_n),
        .in_data          (in_data),
        .a                (a),
        .b                (b),
        .c                (c),
        .operands_valid   (operands_valid),
        .fma_result       (fma_result),
        .fma_result_valid (fma_result_valid),
        .out_data         (out_data),
        .result_valid     (result_valid)
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
        rst_n = 0; in_data = '0; fma_result = '0; fma_result_valid = '0;
        @(posedge clk);                                   

        // Stands in for core output, validation with real core
        // is done in top file's testbench.
        fma_result = 16'hABCD;

        // Load first operand triple
        @(negedge clk); rst_n = 1; in_data = 16'h1111;
        @(posedge clk);
        @(negedge clk); in_data = 16'h2222;
        @(posedge clk);
        @(negedge clk); in_data = 16'h3333;
        @(posedge clk); #1;
        
        check((a == 16'h1111), "a loaded");
        check((b == 16'h2222), "b loaded");
        check((c == 16'h3333), "c loaded");

        // Start sending second pair for first output and second input overlap
        @(negedge clk); in_data = 16'h4444; fma_result_valid = 1'b1;
        @(posedge clk); #1;
    
        check((out_data == 8'hCD), "first out byte correct");
        check((result_valid == 1), "output result is valid");

        @(negedge clk); in_data = 16'h5555; fma_result_valid = 1'b0;
        @(posedge clk); #1;

        check((out_data == 8'hAB), "second out byte correct");
        check((result_valid == 1), "output result is valid");
        num_vectors = num_vectors + 1;

        @(negedge clk); in_data = 16'h6666;
        @(posedge clk); #1;

        check((result_valid == 0), "output no longer driven");

        fma_result = 16'h4567;

        @(negedge clk);
        fma_result_valid = 1'b1;

        check((a == 16'h4444), "a loaded");
        check((b == 16'h5555), "b loaded");
        check((c == 16'h6666), "c loaded");

        @(posedge clk); #1;
    
        check((out_data == 8'h67), "first out byte correct");
        check((result_valid == 1), "output result is valid");

        @(negedge clk);
        fma_result_valid = 1'b0;
        
        @(posedge clk); #1;

        check((out_data == 8'h45), "second out byte correct");
        check((result_valid == 1), "output result is valid");

        @(posedge clk); #1;
        check((result_valid == 0), "output no longer driven");
        num_vectors = num_vectors + 1;

        if (errors == 0) begin
            $display("FMA_IO TB: PASS -- %0d vectors, 0 errors", num_vectors);
            $finish;
        end
        else begin
            $fatal(1, "FMA_IO TB: FAIL -- %0d vectors, %0d errors",
                   num_vectors, errors);
        end
    end

endmodule

`endif // _BF16_FMA_IO_TB_SV_
