`timescale 1ns / 1ps

module sliding_window #(
    parameter IMG_WIDTH = 8
) (
    input clk,
    input rst_n,
    input en,
    input new_frame,
    input [7:0] pixel_in,
    input pixel_valid,
    output reg [71:0] window_out,
    output reg window_valid
);

    // 2 Line Buffers for 8x8 image
    reg [7:0] line_buf_1 [0:IMG_WIDTH-1];
    reg [7:0] line_buf_2 [0:IMG_WIDTH-1];
    
    // 3x3 Window registers
    reg [7:0] window [0:8];

    reg [3:0] col_count;
    reg [3:0] row_count;
    
    integer i;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (i = 0; i < IMG_WIDTH; i = i + 1) begin
                line_buf_1[i] <= 8'd0;
                line_buf_2[i] <= 8'd0;
            end
            for (i = 0; i < 9; i = i + 1) begin
                window[i] <= 8'd0;
            end
            col_count <= 0;
            row_count <= 0;
            window_valid <= 0;
            window_out <= 72'd0;
        end else if (new_frame) begin
            col_count <= 0;
            row_count <= 0;
            window_valid <= 0;
        end else if (en && pixel_valid) begin
            // Shift line buffers
            line_buf_1[col_count] <= pixel_in;
            line_buf_2[col_count] <= line_buf_1[col_count];

            // Shift window pixels (shift left)
            // Row 0
            window[0] <= window[1];
            window[1] <= window[2];
            window[2] <= line_buf_2[col_count];
            // Row 1
            window[3] <= window[4];
            window[4] <= window[5];
            window[5] <= line_buf_1[col_count];
            // Row 2
            window[6] <= window[7];
            window[7] <= window[8];
            window[8] <= pixel_in;

            // Packing into 72-bit output
            window_out <= {
                pixel_in, window[8], window[7],
                line_buf_1[col_count], window[5], window[4],
                line_buf_2[col_count], window[2], window[1] // Wait, simpler to assign flatly after
            }; 
            
            window_out[71:64] <= pixel_in;                // W8
            window_out[63:56] <= window[8];               // W7 (previous W8)
            window_out[55:48] <= window[7];               // W6
            window_out[47:40] <= line_buf_1[col_count];   // W5
            window_out[39:32] <= window[5];               // W4
            window_out[31:24] <= window[4];               // W3
            window_out[23:16] <= line_buf_2[col_count];   // W2
            window_out[15:8]  <= window[2];               // W1
            window_out[7:0]   <= window[1];               // W0

            // Update row and col counters
            if (col_count == IMG_WIDTH - 1) begin
                col_count <= 0;
                row_count <= row_count + 1;
            end else begin
                col_count <= col_count + 1;
            end

            // Window is valid after 2 full rows and 3 columns of data have streamed in
            if (row_count >= 2 && col_count >= 2) begin
                window_valid <= 1'b1;
            end else begin
                // Turn off valid at the wrap around ends of the image, simple handling:
                // For proper 3x3 no padding, valid only when col >= 2
                if (col_count >= 2) window_valid <= 1'b1;
                else window_valid <= 1'b0;
            end
            
            // Re-eval valid properly to handle initial fill
            if ((row_count == 2 && col_count >= 2) || (row_count > 2 && col_count >= 2)) begin
                window_valid <= 1'b1;
            end else begin
                window_valid <= 1'b0;
            end

        end else begin
            window_valid <= 1'b0;
        end
    end

endmodule
