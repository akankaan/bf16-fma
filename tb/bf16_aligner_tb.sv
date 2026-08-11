// ================================================================
//
// Date  : August 3, 2026
// Author: Kaan Akan
//
// Testbench for Bfloat16 FMA (Fused Multiply Add) unit aligner
//
// ================================================================

`ifndef _BF16_ALIGNER_TB_SV_
`define _BF16_ALIGNER_TB_SV_

module bf16_aligner_tb;

    logic [15:0]       product;
    logic              product_zero;
    logic signed [9:0] product_exponent;

    logic       c_zero;
    logic [7:0] c_exponent;
    logic [6:0] c_fraction;

    logic [25:0]        aligned_product;
    logic [25:0]        aligned_addend;
    logic               sticky;
    logic signed [9:0]  aligned_exponent;

    bf16_aligner dut 
    (
        .product          (product),
        .product_zero     (product_zero),
        .product_exponent (product_exponent),
        .c_zero           (c_zero),
        .c_exponent       (c_exponent),
        .c_fraction       (c_fraction),
        .aligned_product  (aligned_product),
        .aligned_addend   (aligned_addend),
        .sticky           (sticky),
        .aligned_exponent (aligned_exponent)
    );

    integer num_vectors, num_errors;
    
    logic [25:0]        exp_aligned_product;
    logic [25:0]        exp_aligned_addend;
    logic               exp_sticky;
    logic signed [9:0]  exp_aligned_exponent;

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
                fields_read = $fscanf(file, "%h %h %h %h %h %h %h %h %h %h",
                                      product, product_zero, product_exponent,
                                      c_zero, c_exponent, c_fraction,
                                      exp_aligned_product, exp_aligned_addend,
                                      exp_sticky, exp_aligned_exponent);
                if (fields_read == 10) begin
                    #1;
                    file_vectors = file_vectors + 1;
                    if ((aligned_product   !== exp_aligned_product)  ||
                        (aligned_addend    !== exp_aligned_addend)   ||
                        (sticky            !== exp_sticky)           ||
                        (aligned_exponent  !== exp_aligned_exponent)) begin
                        file_errors = file_errors + 1;
                        if (file_errors <= 20)
                            $display("MISS prod=%h pz=%b pexp=%h | c(z=%b exp=%h frac=%h) | got ap=%h aa=%h st=%b ae=%h | want %h %h %b %h",
                                     product, product_zero, product_exponent,
                                     c_zero, c_exponent, c_fraction,
                                     aligned_product, aligned_addend, sticky, aligned_exponent,
                                     exp_aligned_product, exp_aligned_addend, exp_sticky, exp_aligned_exponent);
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
        run_vectors("tb/vectors/vec_aligner_random.txt");
        run_vectors("tb/vectors/vec_aligner_edge.txt");
        $display("TOTAL: %0d vectors, %0d errors", num_vectors, num_errors);
        $finish;
    end

endmodule

`endif // _BF16_ALIGNER_TB_SV_
