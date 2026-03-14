`timescale 1ns / 1ps

module cnn_register_interface (
    input clk,
    input rst_n,
    
    // Processor Bus Interface
    input         we,
    input  [31:0] addr,
    input  [31:0] din,
    output reg [31:0] dout,
    
    // Internal Control Signals
    output reg [31:0] input_addr,
    output reg [31:0] weight_addr,
    output reg [31:0] output_addr,
    output reg [31:0] feature_size,
    output reg [31:0] kernel_size,
    output reg        start,
    
    // Status Signals
    input             done
);

    // Register Offsets
    localparam REG_INPUT_ADDR  = 32'h00;
    localparam REG_WEIGHT_ADDR = 32'h04;
    localparam REG_OUTPUT_ADDR = 32'h08;
    localparam REG_FEATURE_SIZE= 32'h0C;
    localparam REG_KERNEL_SIZE = 32'h10;
    localparam REG_START       = 32'h14;
    localparam REG_DONE        = 32'h18;

    // Write Logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            input_addr   <= 32'd0;
            weight_addr  <= 32'd0;
            output_addr  <= 32'd0;
            feature_size <= 32'd8; // Default 8x8
            kernel_size  <= 32'd3; // Default 3x3
            start        <= 1'b0;
        end else if (we) begin
            case (addr)
                REG_INPUT_ADDR:   input_addr   <= din;
                REG_WEIGHT_ADDR:  weight_addr  <= din;
                REG_OUTPUT_ADDR:  output_addr  <= din;
                REG_FEATURE_SIZE: feature_size <= din;
                REG_KERNEL_SIZE:  kernel_size  <= din;
                REG_START:        start        <= din[0];
            endcase
            
            // Auto-clear start pulse after 1 cycle to behave as a trigger
            if (addr != REG_START && start)
                start <= 1'b0;
        end else begin
            if (start)
                start <= 1'b0;
        end
    end

    // Read Logic
    always @(*) begin
        case (addr)
            REG_INPUT_ADDR:   dout = input_addr;
            REG_WEIGHT_ADDR:  dout = weight_addr;
            REG_OUTPUT_ADDR:  dout = output_addr;
            REG_FEATURE_SIZE: dout = feature_size;
            REG_KERNEL_SIZE:  dout = kernel_size;
            REG_START:        dout = {31'd0, start};
            REG_DONE:         dout = {31'd0, done};
            default:          dout = 32'd0;
        endcase
    end

endmodule
