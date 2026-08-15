// ================================================================
//
// Date  : August 11, 2026
// Author: Kaan Akan
//
// Testbench for the Bfloat16 FMA top file bf16_fma.
//
// ================================================================

`ifndef _BF16_FMA_TB_SV_
`define _BF16_FMA_TB_SV_

module bf16_fma_tb;

    logic        clk = 0;
    logic        rst_n;

    logic [15:0] in_data;       // operand words in over the 16-bit pins
    logic [7:0]  out_data;      // result byte stream out
    logic        result_valid;  // high while a result byte is on out_data

    bf16_fma dut 
    (
        .clk          (clk),
        .rst_n        (rst_n),
        .in_data      (in_data),
        .out_data     (out_data),
        .result_valid (result_valid)
    );

    always #5 clk = ~clk;

    logic [15:0] expected_q [$]; // scoreboard FIFO
    logic        first_cycle;
    logic [15:0] expected_push_result;
    logic [15:0] a, b, c;
    logic [7:0]  expected_out_data_first_byte;
    logic [15:0] expected_pop_result;

    integer errors      = 0;
    integer num_vectors = 0;

    // Result driver
    task run_vectors(input string path);
        integer file, fields_read;
        begin
            file = $fopen(path, "r");
            if (file == 0) begin
                $fatal(1, "ERROR: cannot open %s", path);
            end

            // Reset before each vector file
            rst_n = 0; in_data = '0;
            repeat (2) @(posedge clk);
            first_cycle = 1'b1;

            while (!$feof(file)) begin
                fields_read = $fscanf(file, "%h %h %h %h", a, b, c, expected_push_result);
                if (fields_read == 4) begin
                    expected_q.push_back(expected_push_result);

                    if (first_cycle) begin
                        rst_n = 1'b1;
                        first_cycle = 1'b0;
                    end

                    @(negedge clk); in_data = a;
                    @(negedge clk); in_data = b;
                    @(negedge clk); in_data = c;
                end
            end

            $fclose(file);

            // Everything pushed must get popped
            while (expected_q.size() != 0) @(posedge clk);
        end
    endtask

    // Result monitor
    initial begin
        wait (rst_n == 1);
        forever begin
            @(posedge clk); #1;
            if (result_valid) begin
                expected_out_data_first_byte = out_data;

                @(posedge clk); #1;
                if (expected_q.size() > 0) begin
                    expected_pop_result = expected_q.pop_front();
                    num_vectors = num_vectors + 1;
                    if (expected_pop_result != {out_data, expected_out_data_first_byte}) begin
                        errors = errors + 1;
                    end
                end
            end
        end
    end

    initial begin
        run_vectors("tb/vectors/vec_random_fma.txt");
        run_vectors("tb/vectors/vec_special_fma.txt");
        run_vectors("tb/vectors/vec_directed_fma.txt");

        if (errors == 0) begin
            $display("bf16_fma TB: PASS -- %0d vectors, 0 errors", num_vectors);
            $finish;
        end
        else begin
            $fatal(1, "bf16_fma TB: FAIL -- %0d vectors, %0d errors",
                   num_vectors, errors);
        end
    end

endmodule

`endif // _BF16_FMA_TB_SV_
