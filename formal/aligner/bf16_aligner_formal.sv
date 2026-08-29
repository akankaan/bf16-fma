`default_nettype none

module bf16_aligner_formal
(
    input logic [15:0]        product,
    input logic               product_zero,
    input logic signed [9:0]  product_exponent,

    input logic       c_zero,
    input logic [7:0] c_exponent,
    input logic [6:0] c_fraction,
);

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

    logic signed [10:0] reference_shift;
    logic               reference_c_dominates;
    logic [7:0]         reference_c_significand;
    logic [25:0]        reference_c_home;
    logic [25:0]        expected_aligned_product;
    logic [25:0]        expected_aligned_addend;
    logic               expected_sticky;
    logic signed [9:0]  expected_aligned_exponent;

    always_comb begin
        reference_c_significand = c_zero ? 8'd0 : {1'b1, c_fraction};
        reference_shift         = product_exponent - $signed({2'b0, c_exponent})
                                                   + 10'sd11;
        reference_c_home        = {reference_c_significand, 18'b0};
        reference_c_dominates   =  product_zero || (!c_zero && (reference_shift < 0));

        // Frame anchored to product and c is zero
        expected_aligned_product  = {10'b0, product};
        expected_aligned_addend   = 26'b0;
        expected_sticky           = 1'b0;
        expected_aligned_exponent = product_exponent;

        if (reference_c_dominates) begin
            expected_aligned_product  = 26'b0;
            expected_aligned_addend   = reference_c_home;
            expected_sticky           = |product;
            expected_aligned_exponent = $signed({2'b00, c_exponent}) - 10'sd11;
        end
        // c doesn't dominate and it's not zero
        else if (!c_zero) begin
            expected_aligned_product = {10'b0, product};
            // I deemed formal for aligner worth it mainly b/c of the tree shifter
            // strucuture optimization in implementation, so check with simple shift
            expected_aligned_addend  = reference_c_home >> reference_shift;

            for (int i = 0; i < 26; i++) begin
                if (i < reference_shift) begin
                    expected_sticky = expected_sticky || reference_c_home[i];
                end
            end

            expected_aligned_exponent = product_exponent;
        end
    end

    always_comb begin
        // Constrain inputs w/assume to valid prior outputs, so the reference can use
        // |product for sticky instead of mirroring the RTL's !product_zero
        assume(product_zero == (product == 16'b0));
        assume(c_zero       == (c_exponent == 8'b0));
        
        assert(aligned_product  == expected_aligned_product);
        assert(aligned_addend   == expected_aligned_addend);
        assert(sticky           == expected_sticky);
        assert(aligned_exponent == expected_aligned_exponent);

        if (c_zero && !product_zero) begin
            assert(aligned_addend == 26'b0);
            assert(sticky         == 1'b0);
        end

        if (!c_zero && !product_zero && (reference_shift == 0)) begin
            assert(aligned_addend == reference_c_home);
            assert(sticky         == 1'b0);
        end

        if (!c_zero && !product_zero && (reference_shift >= 26)) begin
            assert(aligned_addend == 26'b0);
            assert(sticky         == 1'b1);
        end

        cover(!product_zero && !c_zero && reference_c_dominates);
        cover(product_zero && c_zero);
        cover((reference_shift < 0) && c_zero && !product_zero);
        cover(!product_zero && !c_zero && (reference_shift == 0));
        cover(!product_zero && !c_zero && (reference_shift == 19) &&
               expected_sticky);
        cover(!product_zero && !c_zero && (reference_shift == 19) &&
               !expected_sticky);
        cover(!product_zero && !c_zero && (reference_shift == 25));
        cover(!product_zero && !c_zero && (reference_shift == 31));
        cover(!product_zero && !c_zero && (reference_shift == 32));
        cover(!product_zero && !c_zero && (reference_shift == 132));
    end

endmodule