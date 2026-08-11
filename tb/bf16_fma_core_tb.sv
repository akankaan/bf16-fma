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

    logic [15:0] a, b, c;
    logic [15:0] fma_result;
    logic [15:0] expected_result;

    bf16_fma_core dut 
    (
        .a          (a),
        .b          (b),
        .c          (c),
        .fma_result (fma_result)
    );

    integer num_vectors, num_errors;

    task run_vectors(input string path);
        integer file, fields_read;
        integer file_vectors, file_errors;
        begin
            file_vectors = 0; file_errors = 0;
            file = $fopen(path, "r");
            if (file == 0) begin
                $display("ERROR: cannot open %s", path);
                $finish;
            end
            while (!$feof(file)) begin
                fields_read = $fscanf(file, "%h %h %h %h", a, b, c, expected_result);
                if (fields_read == 4) begin
                    #1; // allow delay for combinational logic settling
                    file_vectors = file_vectors + 1;
                    if (fma_result !== expected_result) begin    // !== so X isn't considered equal
                        file_errors = file_errors + 1;
                        if (file_errors <= 20)
                            $display("MISS a=%h b=%h c=%h | got=%h want=%h",
                                     a, b, c, fma_result, expected_result);
                    end
                end
            end
            $fclose(file);
            $display("%s: %0d vectors, %0d errors", path, file_vectors, file_errors);
            num_vectors = num_vectors + file_vectors;
            num_errors  = num_errors  + file_errors;
        end
    endtask

    initial begin
        num_vectors = 0; num_errors = 0;
        run_vectors("tb/vectors/vec_random_fma.txt");
        run_vectors("tb/vectors/vec_special_fma.txt");
        $display("TOTAL: %0d vectors, %0d errors", num_vectors, num_errors);
        $finish;
    end

endmodule

`endif // _BF16_FMA_CORE_TB_SV_
