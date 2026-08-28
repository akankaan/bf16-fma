`default_nettype none

module bf16_fma_io_formal
(
    input logic        clk,
    input logic        rst_n,
    input logic        in_valid,
    input logic [15:0] in_data,
    input logic [15:0] fma_result,
    input logic        fma_result_valid
);

    logic [15:0] a;
    logic [15:0] b;
    logic [15:0] c;
    logic        operands_valid;

    logic [7:0]  out_data;
    logic        result_valid;


    bf16_fma_io dut
    (
        .clk              (clk),
        .rst_n            (rst_n),
        .in_valid         (in_valid),
        .in_data          (in_data),
        .a                (a),
        .b                (b),
        .c                (c),
        .operands_valid   (operands_valid),
        .fma_result       (fma_result),
        .fma_result_valid (fma_result_valid),
        .out_data         (out_data),
        .result_valid     (result_valid)
    );

    logic [1:0]  expected_index_loader;
    logic [15:0] expected_a;
    logic [15:0] expected_b;
    logic [15:0] expected_c;
    logic        expected_valid;

    logic        expected_index_outputter;
    logic [7:0]  expected_out_byte;
    logic        expected_busy;
    logic [15:0] registered_result;

    always_ff @(posedge clk) begin
        if (!rst_n) begin
            expected_index_loader    <= '0;
            expected_index_outputter <= '0;
            expected_a               <= '0;
            expected_b               <= '0;
            expected_c               <= '0;
            expected_valid           <= '0;
            expected_out_byte        <= '0;
            expected_busy            <= '0;
            registered_result        <= '0;
        end
        else begin
            expected_valid    <= 1'b0;
            expected_busy     <= 1'b0;
            expected_out_byte <= '0;

            // Loader section
            if (in_valid) begin
                case (expected_index_loader) 
                    2'd0: begin
                        expected_a            <= in_data;
                        expected_index_loader <= 2'd1;
                    end
                    2'd1: begin
                        expected_b            <= in_data;
                        expected_index_loader <= 2'd2;
                    end
                    2'd2: begin
                        expected_c            <= in_data;
                        expected_index_loader <= 2'd0;
                        expected_valid        <= 1'b1;
                    end

                    default: expected_index_loader <= '0;
                endcase
            end

            if (fma_result_valid) begin
                registered_result        <= fma_result;
                expected_out_byte        <= fma_result[7:0];
                expected_index_outputter <= 2'd1;
                expected_busy            <= 1'b1;
            end
            else if (expected_index_outputter == 2'd1) begin
                expected_out_byte        <= registered_result[15:8];
                expected_index_outputter <= 2'd0;
                expected_busy            <= 1'b1;
            end 
        end
    end

    logic past_valid = 1'b0;

    always_ff @(posedge clk) begin
        past_valid <= 1'b1;
        if (!past_valid) begin
            assume(!rst_n); // assume reset in first cycle
        end
        else begin
            // cannot send start when the latched result's high byte is being sent out
            assume(!(fma_result_valid && (expected_index_outputter == 2'd1)));

            assert(out_data       == expected_out_byte);
            assert(result_valid   == expected_busy);
            assert(a              == expected_a);
            assert(b              == expected_b);
            assert(c              == expected_c);
            assert(operands_valid == expected_valid);

            cover(operands_valid);
            cover(result_valid && (expected_index_outputter == 2'd0));
            cover(result_valid && (expected_index_outputter == 2'd1));
        end
    end

endmodule
