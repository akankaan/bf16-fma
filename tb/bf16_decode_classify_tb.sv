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

    logic [15:0] a, b, c;

    logic a_sign, b_sign, c_sign;
    logic a_zero, b_zero, c_zero;
    
    logic [7:0]  a_exponent, b_exponent, c_exponent;
    logic [6:0]  a_fraction, b_fraction, c_fraction;
    logic        bypass_arithmetic;
    logic [15:0] fma_flag_result;

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

    logic exp_a_sign, exp_b_sign, exp_c_sign;
    logic exp_a_zero, exp_b_zero, exp_c_zero;
    logic [7:0] exp_a_exponent, exp_b_exponent, exp_c_exponent;
    logic [6:0] exp_a_fraction, exp_b_fraction, exp_c_fraction;
    logic        exp_bypass_arithmetic;
    logic [15:0] exp_fma_flag_result;

    logic [67:0] outputs;
    logic [67:0] expected_outputs;

    assign outputs = {a_sign, b_sign, c_sign,
                      a_zero, b_zero, c_zero,
                      a_exponent, b_exponent, c_exponent,
                      a_fraction, b_fraction, c_fraction,
                      bypass_arithmetic, fma_flag_result};

    assign expected_outputs = {exp_a_sign, exp_b_sign, exp_c_sign,
                               exp_a_zero, exp_b_zero, exp_c_zero,
                               exp_a_exponent, exp_b_exponent, exp_c_exponent,
                               exp_a_fraction, exp_b_fraction, exp_c_fraction,
                               exp_bypass_arithmetic, exp_fma_flag_result};

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
                fields_read = $fscanf(file,
                                      "%h %h %h %h %h %h %h %h %h %h %h %h %h %h %h %h %h",
                                      a, b, c,
                                      exp_a_sign, exp_b_sign, exp_c_sign,
                                      exp_a_zero, exp_b_zero, exp_c_zero,
                                      exp_a_exponent, exp_b_exponent, exp_c_exponent,
                                      exp_a_fraction, exp_b_fraction, exp_c_fraction,
                                      exp_bypass_arithmetic, exp_fma_flag_result);
                if (fields_read == 17) begin
                    #1;
                    file_vectors = file_vectors + 1;
                    if (outputs !== expected_outputs) begin
                        file_errors = file_errors + 1;
                        if (file_errors <= 20)
                            $display("MISS a=%h b=%h c=%h | got=%017h want=%017h",
                                     a, b, c, outputs, expected_outputs);
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
        run_vectors("tb/vectors/vec_decode_classify_random.txt");
        if (num_errors == 0) begin
            $display("DECODE CLASSIFY TB: PASS -- %0d vectors, 0 errors", num_vectors);
            $finish;
        end
        else begin
            $fatal(1, "DECODE CLASSIFY TB: FAIL -- %0d vectors, %0d errors",
                   num_vectors, num_errors);
        end
    end

endmodule

`endif // _BF16_DECODE_CLASSIFY_TB_SV_
