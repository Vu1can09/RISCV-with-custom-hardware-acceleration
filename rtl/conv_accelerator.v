`timescale 1ns / 1ps

module conv_accelerator (
    input clk,
    input rst_n,
    input start,
    input [71:0] weights,          // 9x 8-bit kernel weights
    input [7:0] pixel_in,          // feature map pixel input
    input pixel_valid,             // indicates valid pixel input
    
    output reg [23:0] pixel_out,   // accumulated output
    output reg pixel_out_valid,
    output reg done
);

    wire [71:0] window_data;
    wire window_valid;

    // Sliding Window Instantiation
    sliding_window #(
        .IMG_WIDTH(8)
    ) u_sliding_window (
        .clk(clk),
        .rst_n(rst_n),
        .en(pixel_valid),
        .new_frame(start),
        .pixel_in(pixel_in),
        .pixel_valid(pixel_valid),
        .window_out(window_data),
        .window_valid(window_valid)
    );

    wire [23:0] mac_out;
    wire mac_valid;

    // MAC Array Instantiation
    mac_array u_mac_array (
        .clk(clk),
        .rst_n(rst_n),
        .en(window_valid),
        .window_data(window_data),
        .weight_data(weights),
        .partial_sum(24'd0),        // Multi-channel accumulation handled at upper level if needed, or set to 0
        .out_data(mac_out),
        .out_valid(mac_valid)
    );

    // Accumulator and Control FSM
    localparam ST_IDLE = 2'd0;
    localparam ST_RUN  = 2'd1;
    localparam ST_DONE = 2'd2;

    reg [1:0] state, next_state;
    reg [6:0] pixel_count;         // Track 8x8 = 64 pixels

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= ST_IDLE;
            pixel_count <= 0;
            pixel_out <= 24'd0;
            pixel_out_valid <= 1'b0;
            done <= 1'b0;
        end else begin
            case (state)
                ST_IDLE: begin
                    done <= 1'b0;
                    pixel_count <= 0;
                    pixel_out_valid <= 1'b0;
                    if (start)
                        state <= ST_RUN;
                end
                
                ST_RUN: begin
                    // Register the MAC output to the Accumulator output
                    if (mac_valid) begin
                        pixel_out <= mac_out;
                        pixel_out_valid <= 1'b1;
                        pixel_count <= pixel_count + 1;
                    end else begin
                        pixel_out_valid <= 1'b0;
                    end

                    // Since 8x8 input without padding results in 6x6 valid outputs (36 pixels)
                    if (pixel_count == 36) begin
                        state <= ST_DONE;
                        pixel_out_valid <= 1'b0;
                    end
                end

                ST_DONE: begin
                    done <= 1'b1;
                    if (!start)
                        state <= ST_IDLE;
                end
                
                default: state <= ST_IDLE;
            endcase
        end
    end

endmodule
