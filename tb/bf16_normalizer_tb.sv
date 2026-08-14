// ================================================================
//
// Date  : August 9, 2026
// Author: Kaan Akan
//
// Testbench for Bfloat16 FMA (Fused Multiply Add) unit normalizer
//
// ================================================================

`ifndef _BF16_NORMALIZER_TB_SV_
`define _BF16_NORMALIZER_TB_SV_

module bf16_normalizer_tb;

    logic [26:0]        sum;
    logic               sum_sign;
    logic signed [9:0]  sum_exponent;
    logic               sum_sticky;

    logic [7:0]         norm_significand;
    logic               guard;
    logic               sticky;
    logic signed [9:0]  norm_exponent;
    logic               norm_sign;
    logic               is_zero;

    bf16_normalizer dut 
    (
        .sum              (sum),
        .sum_sign         (sum_sign),
        .sum_exponent     (sum_exponent),
        .sum_sticky       (sum_sticky),
        .norm_significand (norm_significand),
        .guard            (guard),
        .sticky           (sticky),
        .norm_exponent    (norm_exponent),
        .norm_sign        (norm_sign),
        .is_zero          (is_zero)
    );

    integer num_vectors, num_errors;
    
    logic [7:0]         exp_norm_significand;
    logic               exp_guard;
    logic               exp_sticky;
    logic signed [9:0]  exp_norm_exponent;
    logic               exp_norm_sign;
    logic               exp_is_zero;

    task run_vectors(input string path);
        integer file, fields_read;
        integer file_vectors, file_errors;
        begin
            file_vectors = 0; file_errors = 0;
            file = $fopen(path, "r");
            if (file == 0) begin
                $fatal(1, "ERROR: cannot open %s", path);
            end
            while (!$feof(file)) begin
                fields_read = $fscanf(file, "%h %h %h %h %h %h %h %h %h %h",
                                      sum, sum_sign, sum_exponent, sum_sticky,
                                      exp_norm_significand, exp_guard, exp_sticky,
                                      exp_norm_exponent, exp_norm_sign, exp_is_zero);
                if (fields_read == 10) begin
                    #1;
                    file_vectors = file_vectors + 1;
                    if ((norm_significand !== exp_norm_significand) ||
                        (guard            !== exp_guard)            ||
                        (sticky           !== exp_sticky)           ||
                        (norm_exponent    !== exp_norm_exponent)    ||
                        (norm_sign        !== exp_norm_sign)        ||
                        (is_zero          !== exp_is_zero)) begin
                        file_errors = file_errors + 1;
                        if (file_errors <= 20)
                            $display("MISS sum=%h ssign=%b sexp=%h sst=%b | got nsig=%h g=%b st=%b nexp=%h nsign=%b zero=%b | want %h %b %b %h %b %b",
                                     sum, sum_sign, sum_exponent, sum_sticky,
                                     norm_significand, guard, sticky, norm_exponent, norm_sign, is_zero,
                                     exp_norm_significand, exp_guard, exp_sticky,
                                     exp_norm_exponent, exp_norm_sign, exp_is_zero);
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
        run_vectors("tb/vectors/vec_normalizer_random.txt");
        if (num_errors == 0) begin
            $display("NORMALIZER TB: PASS -- %0d vectors, 0 errors", num_vectors);
            $finish;
        end
        else begin
            $fatal(1, "NORMALIZER TB: FAIL -- %0d vectors, %0d errors",
                   num_vectors, num_errors);
        end
    end

endmodule

`endif // _BF16_NORMALIZER_TB_SV_
