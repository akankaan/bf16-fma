// ================================================================
//
// Date  : August 9, 2026
// Author: Kaan Akan
//
// Testbench for Bfloat16 FMA (Fused Multiply Add) unit rounder
//
// ================================================================

`ifndef _BF16_ROUNDER_TB_SV_
`define _BF16_ROUNDER_TB_SV_

module bf16_rounder_tb;

    logic [7:0]         norm_significand;
    logic               guard;
    logic               sticky;
    logic signed [9:0]  norm_exponent;
    logic               norm_sign;
    logic               is_zero;
    logic [15:0]        rounded_result;

    bf16_rounder rounder
    (
        .norm_significand (norm_significand),
        .guard            (guard),
        .sticky           (sticky),
        .norm_exponent    (norm_exponent),
        .norm_sign        (norm_sign),
        .is_zero          (is_zero),
        .rounded_result   (rounded_result)
    );

    integer num_vectors, num_errors;
    
    logic [15:0] exp_rounded_result;

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
                fields_read = $fscanf(file, "%h %h %h %h %h %h %h",
                                      norm_significand, guard, sticky, norm_exponent,
                                      norm_sign, is_zero, exp_rounded_result);
                if (fields_read == 7) begin
                    #1;
                    file_vectors = file_vectors + 1;
                    if (rounded_result !== exp_rounded_result) begin
                        file_errors = file_errors + 1;
                        if (file_errors <= 20)
                            $display("MISS nsig=%h g=%b st=%b nexp=%h nsign=%b zero=%b | got %h | want %h",
                                     norm_significand, guard, sticky, norm_exponent, norm_sign, is_zero,
                                     rounded_result, exp_rounded_result);
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
        run_vectors("tb/vectors/vec_rounder_random.txt");
        $display("TOTAL: %0d vectors, %0d errors", num_vectors, num_errors);
        $finish;
    end

endmodule

`endif // _BF16_ROUNDER_TB_SV_
