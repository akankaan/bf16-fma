// ================================================================
//
// Date  : August 15, 2026
// Author: Kaan Akan
//
// Testbench for Bfloat16 FMA (Fused Multiply Add) decode classify unit
//
// ================================================================

`ifndef _BF16_DECODE_CLASSIFY_TB_SV_
`define _BF16_DECODE_CLASSIFY_TB_SV_

module bf16_decode_classify_tb;

    logic [7:0]         norm_significand;
    logic               guard;
    logic               sticky;
    logic signed [9:0]  norm_exponent;
    logic               norm_sign;
    logic               is_zero;
    logic [15:0]        rounded_result;

    bf16_decode_classify dut
    (
    .a                 (a),
    .b                 (b),
    .c                 (c),
    .a_sign            (a_sign),
    .b_sign            (b_sign),
    .c_sign            (c_sign),
    .a_zero            (a_zero),
    .b_zero            (b_zero),
    .c_zero            (c_zero),
    .a_exponent        (a_exponent),
    .b_exponent        (b_exponent),
    .c_exponent        (c_exponent),
    .a_fraction        (a_fraction),
    .b_fraction        (b_fraction),
    .c_fraction        (c_fraction),      
    .bypass_arithmetic (bypass_arithmetic),
    .fma_flag_result   (fma_flag_result)
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
                $fatal(1, "ERROR: cannot open %s", path);
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
        if (num_errors == 0) begin
            $display("ROUNDER TB: PASS -- %0d vectors, 0 errors", num_vectors);
            $finish;
        end
        else begin
            $fatal(1, "ROUNDER TB: FAIL -- %0d vectors, %0d errors",
                   num_vectors, num_errors);
        end
    end

endmodule

`endif // _BF16_DECODE_CLASSIFY_TB_SV_
