`timescale 1ns / 1ps

module mac_array (
    input wire clk,
    input wire rst_n,
    input wire en,
    
    // 9 pixels from 3x3 window, 8-bit each
    input wire [71:0] pixels_in, // {p8, p7, ..., p0}
    // 9 weights from 3x3 kernel, 8-bit each
    input wire [71:0] weights_in, // {w8, w7, ..., w0}
    
    // Output of the 3x3 MAC (9 multiplications + accumulation)
    output reg [19:0] mac_out,
    output reg valid_out
);

    integer i;
    
    // Pipeline Registers
    reg signed [7:0] px_reg [0:8];
    reg signed [7:0] wt_reg [0:8];
    reg signed [15:0] mult_res [0:8];
    reg signed [19:0] acc_sum;
    reg valid_stg1, valid_stg2;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (i=0; i<9; i=i+1) begin
                px_reg[i] <= 0;
                wt_reg[i] <= 0;
                mult_res[i] <= 0;
            end
            acc_sum <= 0;
            mac_out <= 0;
            valid_stg1 <= 0;
            valid_stg2 <= 0;
            valid_out <= 0;
        end else begin
            // Stage 1: Register Inputs
            if (en) begin
                for (i=0; i<9; i=i+1) begin
                    px_reg[i] <= pixels_in[i*8 +: 8];
                    wt_reg[i] <= weights_in[i*8 +: 8];
                end
                valid_stg1 <= 1'b1;
            end else begin
                valid_stg1 <= 1'b0;
            end
            
            // Stage 2: Multiply
            if (valid_stg1) begin
                for (i=0; i<9; i=i+1) begin
                    mult_res[i] <= px_reg[i] * wt_reg[i];
                end
                valid_stg2 <= 1'b1;
            end else begin
                valid_stg2 <= 1'b0;
            end
            
            // Stage 3: Accumulate 9 products
            if (valid_stg2) begin
                mac_out <= mult_res[0] + mult_res[1] + mult_res[2] +
                           mult_res[3] + mult_res[4] + mult_res[5] +
                           mult_res[6] + mult_res[7] + mult_res[8];
                valid_out <= 1'b1;
            end else begin
                valid_out <= 1'b0;
            end
        end
    end

endmodule
