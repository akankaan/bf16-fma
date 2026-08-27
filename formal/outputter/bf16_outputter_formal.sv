module bf16_outputter_formal
(
    input logic        clk,
    input logic        rst_n,
    input logic [15:0] result,
    input logic        start
);

    logic [7:0]  out_byte;
    logic        busy;

    bf16_outputter dut
    (
        .clk      (clk),
        .rst_n    (rst_n),
        .result   (result),
        .start    (start),
        .out_byte (out_byte),
        .busy     (busy)
    );

    logic [1:0]  expected_index;
    logic [7:0]  expected_out_byte;
    logic        expected_busy;
    logic [15:0] registered_result;

    always_ff @(posedge clk) begin
        if (!rst_n) begin
            expected_index    <= '0;
            expected_out_byte <= '0;
            expected_busy     <= '0;
            registered_result <= '0;
        end
        else begin
            expected_busy <= 1'b0;
            expected_out_byte <= '0;

            if (start) begin
                registered_result <= result;
                expected_out_byte <= result[7:0];
                expected_index    <= 2'd1;
                expected_busy     <= 1'b1;
            end
            else if (expected_index == 2'd1) begin
                expected_out_byte <= registered_result[15:8];
                expected_index    <= 2'd0;
                expected_busy     <= 1'b1;
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
            assume(!(busy && start)); // cannot send start when busy

            assert(out_byte == expected_out_byte);
            assert(busy     == expected_busy);

            cover(busy && (expected_index == 2'd0));
            cover(busy && (expected_index == 2'd1));
        end
    end

endmodule
