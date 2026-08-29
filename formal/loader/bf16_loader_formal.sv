`default_nettype none

module bf16_loader_formal
(
    input logic        clk,
    input logic        rst_n,
    input logic        in_valid,
    input logic [15:0] in_data
);

    logic [15:0] a;
    logic [15:0] b;
    logic [15:0] c;
    logic        operands_valid;

    bf16_loader dut
    (
        .clk            (clk),
        .rst_n          (rst_n),
        .in_valid       (in_valid),
        .in_data        (in_data),
        .a              (a),
        .b              (b),
        .c              (c),
        .operands_valid (operands_valid)
    );

    logic [1:0]  expected_index;
    logic [15:0] expected_a;
    logic [15:0] expected_b;
    logic [15:0] expected_c;
    logic        expected_valid;

    always_ff @(posedge clk) begin
        if (!rst_n) begin
            expected_index <= '0;
            expected_a     <= '0;
            expected_b     <= '0;
            expected_c     <= '0;
            expected_valid <= '0;
        end
        else begin
            expected_valid <= 1'b0;

            if (in_valid) begin
                case (expected_index) 
                    2'd0: begin
                        expected_a     <= in_data;
                        expected_index <= 2'd1;
                    end
                    2'd1: begin
                        expected_b     <= in_data;
                        expected_index <= 2'd2;
                    end
                    2'd2: begin
                        expected_c     <= in_data;
                        expected_index <= 2'd0;
                        expected_valid <= 1'b1;
                    end

                    default: expected_index <= '0;
                endcase
            end
        end
    end

    logic past_valid = 1'b0;

    always_ff @(posedge clk) begin
        past_valid <= 1'b1;
        if (!past_valid) begin
            assume (!rst_n); // assume reset in first cycle
        end
        else begin
            assert (a              == expected_a);
            assert (b              == expected_b);
            assert (c              == expected_c);
            assert (operands_valid == expected_valid);

            cover (operands_valid);
        end
    end

endmodule
