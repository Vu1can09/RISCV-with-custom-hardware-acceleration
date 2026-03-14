`timescale 1ns / 1ps

module line_buffer #(
    parameter DATA_WIDTH = 8,
    parameter MAX_IMAGE_WIDTH = 128
)(
    input wire clk,
    input wire rst_n,
    input wire en,
    
    input wire [7:0] image_width, // Dynamically configured width
    input wire [DATA_WIDTH-1:0] pixel_in,
    
    // Column outputs for 3x3 window: current row, row-1, row-2
    output reg [DATA_WIDTH-1:0] out_row0, // Newest
    output reg [DATA_WIDTH-1:0] out_row1, // Middle
    output reg [DATA_WIDTH-1:0] out_row2, // Oldest
    output reg valid_out
);

    // BRAM inference for line buffers
    reg [DATA_WIDTH-1:0] fifo_row1 [0:MAX_IMAGE_WIDTH-1];
    reg [DATA_WIDTH-1:0] fifo_row2 [0:MAX_IMAGE_WIDTH-1];
    
    reg [7:0] wr_ptr;
    reg [7:0] rd_ptr;
    reg state_fill; 
    
    wire [DATA_WIDTH-1:0] fifo1_out_data;
    wire [DATA_WIDTH-1:0] fifo2_out_data;

    assign fifo1_out_data = fifo_row1[rd_ptr];
    assign fifo2_out_data = fifo_row2[rd_ptr];

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            wr_ptr <= 0;
            rd_ptr <= 0;
            out_row0 <= 0;
            out_row1 <= 0;
            out_row2 <= 0;
            valid_out <= 0;
            state_fill <= 0;
            
            // clear buffers (optional, typically BRAM doesn't need this, but good for sim)
            // skipping loop for synthesis efficiency; rely on valid logic
        end else if (en) begin
            // Read from FIFOs and set outputs
            out_row0 <= pixel_in;
            out_row1 <= fifo1_out_data;
            out_row2 <= fifo2_out_data;
            valid_out <= 1'b1;
            
            // Write to FIFOs
            fifo_row1[wr_ptr] <= pixel_in;
            fifo_row2[wr_ptr] <= fifo1_out_data;
            
            // Manage pointers
            if (wr_ptr == image_width - 1) begin
                wr_ptr <= 0;
            end else begin
                wr_ptr <= wr_ptr + 1;
            end
            
            // Read pointer follows write pointer (shift register behavior)
            rd_ptr <= wr_ptr; // Since we read then write at same address for next cycle shift
            
        end else begin
            valid_out <= 1'b0;
        end
    end

endmodule
