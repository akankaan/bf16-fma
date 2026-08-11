// ================================================================
//
// Date  : July 28, 2026
// Author: Kaan Akan
//
// Testbench for Bfloat16 FMA (Fused Multiply Add) unit multiplier
//
// ================================================================

`ifndef _BF16_MULTIPLIER_TB_SV_
`define _BF16_MULTIPLIER_TB_SV_

module bf16_multiplier_tb;

    logic [15:0] a, b, c;

    logic a_sign, b_sign, c_sign;
    logic a_zero, b_zero, c_zero;

    logic [7:0] a_exponent, b_exponent, c_exponent;
    logic [6:0] a_fraction, b_fraction, c_fraction;

    logic        bypass_arithmetic;
    logic [15:0] fma_flag_result;

    assign c = 16'b0;

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

    logic product_sign;
    logic product_zero;

    logic        [15:0] product;
    logic signed [9:0]  product_exponent;

    bf16_multiplier dut 
    (
        .a_sign            (a_sign),
        .b_sign            (b_sign),
        .a_zero            (a_zero),
        .b_zero            (b_zero),
        .a_exponent        (a_exponent),
        .b_exponent        (b_exponent),
        .a_fraction        (a_fraction),
        .b_fraction        (b_fraction),
        .product_sign      (product_sign),
        .product_zero      (product_zero),
        .product           (product),
        .product_exponent  (product_exponent)
    );

    integer file, fields_read, num_vectors, num_errors;
    logic [15:0] exp_product;
    logic [9:0]  exp_exponent; 
    logic        exp_sign, exp_zero;

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
                fields_read = $fscanf(file, "%h %h %h %h %h %h",
                                    a, b, exp_product, exp_exponent, exp_sign, exp_zero);
                if (fields_read == 6) begin
                    #1;
                    file_vectors = file_vectors + 1;
                    if ((product_sign      !== exp_sign)     ||
                        (product_zero      !== exp_zero)     ||
                        (product           !== exp_product)  ||
                        (product_exponent  !== exp_exponent)) begin
                        file_errors = file_errors + 1;
                        if (file_errors <= 20)
                            $display("MISS a=%h b=%h | got prod=%h exp=%h sgn=%b zero=%b | want %h %h %b %b",
                                    a, b, product, product_exponent, product_sign, product_zero,
                                    exp_product, exp_exponent, exp_sign, exp_zero);
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
        run_vectors("tb/vectors/vec_multiplier_random.txt");
        run_vectors("tb/vectors/vec_multiplier_exhaustive.txt");
        $display("TOTAL: %0d vectors, %0d errors", num_vectors, num_errors);
        $finish;
    end

endmodule

`endif // _BF16_MULTIPLIER_TB_SV_
