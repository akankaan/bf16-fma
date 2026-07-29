// ================================================================
//
// Date  : July 24, 2026
// Author: Kaan Akan
//
// Testbench for Bfloat16 FMA (Fused Multiply Add) unit top file
//
// ================================================================

`ifndef _BF16_FMA_TOP_TB_SV_
`define _BF16_FMA_TOP_TB_SV_

module bf16_fma_top_tb;

    logic [15:0] a, b, c;
    logic [15:0] fma_result;
    logic [15:0] expected_result;

    bf16_fma_top fma_top 
    (
        .a          (a),
        .b          (b),
        .c          (c),
        .fma_result (fma_result)
    );

    integer file, fields_read, num_vectors, num_errors;

    initial begin
        num_vectors = 0; num_errors = 0;
        file = $fopen("tb/vectors/vec_special_fma.txt", "r");
        if (file == 0) begin
            $display("ERROR: cannot open vector file");
            $finish;
        end

        // While end-of-file not reached
        while (!$feof(file)) begin
            fields_read = $fscanf(file, "%h %h %h %h\n", a, b, c, expected_result);
            if (fields_read == 4) begin
                #1; // allow delay for combinational logic settling
                num_vectors = num_vectors + 1;
                if (fma_result !== expected_result) begin    // !== so X isn't considered equal
                    num_errors = num_errors + 1;
                    if (num_errors <= 20)
                        $display("MISS a=%h b=%h c=%h got=%h exp=%h",
                                a, b, c, fma_result, expected_result);
                end
            end
        end

    $fclose(file);
    $display("%0d vectors, %0d errors", num_vectors, num_errors);
    $finish;
    end

endmodule

`endif // _BF16_FMA_TOP_TB_SV_
