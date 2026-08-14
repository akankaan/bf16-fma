// ================================================================
//
// Date  : August 9, 2026
// Author: Kaan Akan
//
// Testbench for Bfloat16 FMA (Fused Multiply Add) unit add/subtract
//
// ================================================================

`ifndef _BF16_ADDSUB_TB_SV_
`define _BF16_ADDSUB_TB_SV_

module bf16_addsub_tb;

    logic [25:0]        aligned_product;
    logic [25:0]        aligned_addend;
    logic               sticky;
    logic signed [9:0]  aligned_exponent;
    logic               product_sign;
    logic               c_sign;

    logic [26:0]        sum;
    logic               sum_sign;
    logic signed [9:0]  sum_exponent;
    logic               sum_sticky;

    bf16_addsub dut 
    (
        .aligned_product  (aligned_product),
        .aligned_addend   (aligned_addend),
        .sticky           (sticky),
        .aligned_exponent (aligned_exponent),
        .product_sign     (product_sign),
        .c_sign           (c_sign),
        .sum              (sum),
        .sum_sign         (sum_sign),
        .sum_exponent     (sum_exponent),
        .sum_sticky       (sum_sticky)
    );

    integer num_vectors, num_errors;
    
    logic [26:0]        exp_sum;
    logic               exp_sum_sign;
    logic signed [9:0]  exp_sum_exponent;
    logic               exp_sum_sticky;

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
                                      aligned_product, aligned_addend, sticky,
                                      aligned_exponent, product_sign, c_sign,
                                      exp_sum, exp_sum_sign,
                                      exp_sum_exponent, exp_sum_sticky);
                if (fields_read == 10) begin
                    #1;
                    file_vectors = file_vectors + 1;
                    if ((sum          !== exp_sum)          ||
                        (sum_sign     !== exp_sum_sign)     ||
                        (sum_exponent !== exp_sum_exponent) ||
                        (sum_sticky   !== exp_sum_sticky)) begin
                        file_errors = file_errors + 1;
                        if (file_errors <= 20)
                            $display("MISS ap=%h aa=%h st=%b ae=%h psign=%b csign=%b | got sum=%h ssign=%b sexp=%h sst=%b | want %h %b %h %b",
                                     aligned_product, aligned_addend, sticky, aligned_exponent, product_sign, c_sign,
                                     sum, sum_sign, sum_exponent, sum_sticky,
                                     exp_sum, exp_sum_sign, exp_sum_exponent, exp_sum_sticky);
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
        run_vectors("tb/vectors/vec_addsub_random.txt");
        if (num_errors == 0) begin
            $display("ADDSUB TB: PASS -- %0d vectors, 0 errors", num_vectors);
            $finish;
        end
        else begin
            $fatal(1, "ADDSUB TB: FAIL -- %0d vectors, %0d errors",
                   num_vectors, num_errors);
        end
    end

endmodule

`endif // _BF16_ADDSUB_TB_SV_
