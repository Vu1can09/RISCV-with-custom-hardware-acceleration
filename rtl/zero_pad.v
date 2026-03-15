`timescale 1ns / 1ps

// -----------------------------------------------------------------------------
// Zero-Padding Module
//
// Inserts configurable rows/columns of zeros around the input stream before
// the convolution. This preserves spatial dimensions after convolution.
//
// For a 3×3 kernel with pad=1: output size = input size (same convolution)
// For a 5×5 kernel with pad=2: output size = input size
// -----------------------------------------------------------------------------

module zero_pad #(
    parameter DATA_WIDTH = 8
)(
    input  wire                          clk,
    input  wire                          rst_n,
    input  wire                          start,

    // Configuration
    input  wire [7:0]                    pad_size,   // Number of zero rows/cols on each side
    input  wire [15:0]                   img_width,
    input  wire [15:0]                   img_height,

    // Input stream (original image)
    input  wire [DATA_WIDTH-1:0]         pixel_in,
    input  wire                          valid_in,
    output wire                          ready_out,  // Backpressure to upstream

    // Padded output stream
    output reg  [DATA_WIDTH-1:0]         pixel_out,
    output reg                           valid_out,

    // Padded dimensions
    output wire [15:0]                   padded_width,
    output wire [15:0]                   padded_height
);

    assign padded_width  = img_width  + {8'd0, pad_size, 1'b0};   // width + 2*pad
    assign padded_height = img_height + {8'd0, pad_size, 1'b0};   // height + 2*pad

    reg [15:0] out_col;
    reg [15:0] out_row;
    wire in_pad_region;

    // A pixel is in the padding region if it's in the border zone
    assign in_pad_region = (out_col < {8'd0, pad_size}) ||
                           (out_col >= img_width + {8'd0, pad_size}) ||
                           (out_row < {8'd0, pad_size}) ||
                           (out_row >= img_height + {8'd0, pad_size});

    // Only consume upstream pixels when we're in the real image region
    assign ready_out = !in_pad_region;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n || start) begin
            out_col   <= 0;
            out_row   <= 0;
            pixel_out <= 0;
            valid_out <= 0;
        end else begin
            if (in_pad_region) begin
                // Emit zero padding pixel
                pixel_out <= {DATA_WIDTH{1'b0}};
                valid_out <= 1'b1;

                // Advance position
                if (out_col == padded_width - 1) begin
                    out_col <= 0;
                    out_row <= out_row + 1;
                end else begin
                    out_col <= out_col + 1;
                end
            end else if (valid_in) begin
                // Pass through real pixel
                pixel_out <= pixel_in;
                valid_out <= 1'b1;

                if (out_col == padded_width - 1) begin
                    out_col <= 0;
                    out_row <= out_row + 1;
                end else begin
                    out_col <= out_col + 1;
                end
            end else begin
                valid_out <= 1'b0;
            end
        end
    end

endmodule
