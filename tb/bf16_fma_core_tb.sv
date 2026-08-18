// ================================================================
//
// Date  : July 24, 2026
// Author: Kaan Akan
//
// Testbench for Bfloat16 FMA (Fused Multiply Add) unit compute core
//
// ================================================================

`ifndef _BF16_FMA_CORE_TB_SV_
`define _BF16_FMA_CORE_TB_SV_

module bf16_fma_core_tb;

    logic clk = 0;
    logic rst_n;
    logic operands_valid;
    logic fma_result_valid;

    logic [15:0] a, b, c;
    logic [15:0] fma_result;

    bf16_fma_core dut 
    (
        .clk              (clk),
        .rst_n            (rst_n),
        .operands_valid   (operands_valid),
        .a                (a),
        .b                (b),
        .c                (c),
        .fma_result       (fma_result),
        .fma_result_valid (fma_result_valid)
    );

    always #5 clk = ~clk;

    logic [15:0] expected_q [$];
    logic [15:0] expected_push_result;
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
            rst_n          = 1'b0;
            operands_valid = 1'b0;
            a              = '0;
            b              = '0;
            c              = '0;

            repeat (2) @(posedge clk);
            @(negedge clk);
            rst_n = 1'b1;

            while (!$feof(file)) begin
                @(negedge clk);

                fields_read = $fscanf(
                    file,
                    "%h %h %h %h",
                    a,
                    b,
                    c,
                    expected_push_result
                );

                if (fields_read == 4) begin
                    operands_valid = 1'b1;
                    expected_q.push_back(expected_push_result);
                end
                else begin
                    operands_valid = 1'b0;
                end
            end

            // Don't let op valid to go low directly after loop,
            // so it can be sampled for final vector
            @(negedge clk);
            operands_valid = 1'b0;

            $fclose(file);

            // Every pushed result must get popped
            while (expected_q.size() != 0) begin
                @(posedge clk);
            end
        end
    endtask

    // Result monitor
    initial begin
        forever begin
            @(posedge clk);
            #1;

            if (rst_n && fma_result_valid) begin
                if (expected_q.size() == 0) begin
                    errors = errors + 1;
                    $display("UNEXPECTED result=%h", fma_result);
                end
                else begin
                    expected_pop_result = expected_q.pop_front();
                    num_vectors = num_vectors + 1;

                    if (fma_result !== expected_pop_result) begin
                        errors = errors + 1;

                        if (errors <= 20) begin
                            $display(
                                "MISS got=%h want=%h",
                                fma_result,
                                expected_pop_result
                            );
                        end
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
            $display("FMA CORE TB: PASS -- %0d vectors, 0 errors", num_vectors);
            $finish;
        end
        else begin
            $fatal(1, "FMA CORE TB: FAIL -- %0d vectors, %0d errors",
                   num_vectors, errors);
        end
    end

endmodule

`endif // _BF16_FMA_CORE_TB_SV_
