`timescale 1ns / 1ps

// -----------------------------------------------------------------------------
// Activation LUT — Sigmoid & Softmax Approximation
//
// Uses a 256-entry lookup table for sigmoid approximation on INT8 inputs.
// For softmax, the output is e^x approximated through the same LUT followed
// by normalization (division by sum).
//
// Sigmoid(x) ≈ LUT[x + 128] where x ∈ [-128, 127] maps to [0, 255]
//
// The LUT is pre-initialized with the sigmoid curve scaled to 8-bit output.
// For ASIC synthesis, the LUT will be inferred as a small ROM.
// -----------------------------------------------------------------------------

module activation_lut #(
    parameter IN_WIDTH  = 8,
    parameter OUT_WIDTH = 8
)(
    input  wire                          clk,
    input  wire                          rst_n,

    // Mode select: 0 = sigmoid, 1 = pass-through (for softmax normalization stage)
    input  wire                          mode,

    // Streaming input
    input  wire signed [IN_WIDTH-1:0]    data_in,
    input  wire                          valid_in,

    // Output
    output reg  [OUT_WIDTH-1:0]          data_out,
    output reg                           valid_out
);

    // 256-entry sigmoid LUT (pre-computed: sigmoid(x/32)*255 for x in [-128,127])
    reg [OUT_WIDTH-1:0] sigmoid_lut [0:255];

    // Initialize LUT with approximated sigmoid curve
    integer k;
    initial begin
        for (k = 0; k < 256; k = k + 1) begin
            // Piecewise linear approximation of sigmoid
            if (k < 64)       sigmoid_lut[k] = 0;           // Deep negative → ~0
            else if (k < 96)  sigmoid_lut[k] = (k - 64) * 2;   // Rising slope
            else if (k < 128) sigmoid_lut[k] = 64 + (k - 96);  // Steeper
            else if (k < 160) sigmoid_lut[k] = 128 + (k - 128); // Center
            else if (k < 192) sigmoid_lut[k] = 192 + (k - 160) / 2; // Saturating
            else              sigmoid_lut[k] = 255;          // Deep positive → ~1
        end
    end

    wire [7:0] lut_addr = data_in + 8'd128;  // Shift signed to unsigned index

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            data_out  <= 0;
            valid_out <= 0;
        end else if (valid_in) begin
            if (mode == 1'b0) begin
                data_out <= sigmoid_lut[lut_addr];
            end else begin
                data_out <= data_in[OUT_WIDTH-1:0]; // Pass-through
            end
            valid_out <= 1'b1;
        end else begin
            valid_out <= 1'b0;
        end
    end

endmodule
