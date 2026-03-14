`timescale 1ns / 1ps

module mac_array (
    input clk,
    input rst_n,
    input en,
    input signed [71:0] window_data,  // 9 pixels of 8 bits each
    input signed [71:0] weight_data,  // 9 weights of 8 bits each
    input signed [23:0] partial_sum,
    output reg signed [23:0] out_data,
    output reg out_valid
);

    integer i;
    reg signed [15:0] prod [0:8];
    reg signed [23:0] psum_comb;

    // Combinational Mult-Add
    always @(*) begin
        psum_comb = partial_sum;
        for (i = 0; i < 9; i = i + 1) begin
            prod[i] = $signed(window_data[i*8 +: 8]) * $signed(weight_data[i*8 +: 8]);
            psum_comb = psum_comb + prod[i];
        end
    end

    // Sequential output
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            out_data <= 24'd0;
            out_valid <= 1'b0;
        end else if (en) begin
            out_data <= psum_comb;
            out_valid <= 1'b1;
        end else begin
            out_valid <= 1'b0;
        end
    end

endmodule
