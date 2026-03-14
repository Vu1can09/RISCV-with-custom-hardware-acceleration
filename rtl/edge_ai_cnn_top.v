`timescale 1ns / 1ps

module edge_ai_cnn_top (
    input clk,
    input rst_n,

    // Processor Bus Interface
    input         bus_we,
    input  [31:0] bus_addr,
    input  [31:0] bus_din,
    output [31:0] bus_dout,
    
    // Status
    output        cnn_done
);

    // Internal wires
    wire [31:0] input_addr;
    wire [31:0] weight_addr;
    wire [31:0] output_addr;
    wire [31:0] feature_size;
    wire [31:0] kernel_size;
    wire        start;
    wire        done;
    
    // Acceleration signals
    wire conv1_start;
    wire conv2_start;
    wire conv3_start;
    wire conv1_done;
    wire conv2_done;
    wire conv3_done;
    
    // Memory Signals
    wire [71:0] weights_1;
    wire [71:0] weights_2;
    wire [71:0] weights_3;
    
    assign cnn_done = done;

    // Processor Interface
    cnn_register_interface u_reg_interface (
        .clk(clk),
        .rst_n(rst_n),
        .we(bus_we),
        .addr(bus_addr),
        .din(bus_din),
        .dout(bus_dout),
        
        .input_addr(input_addr),
        .weight_addr(weight_addr),
        .output_addr(output_addr),
        .feature_size(feature_size),
        .kernel_size(kernel_size),
        .start(start),
        .done(done)
    );

    // CNN Controller
    cnn_controller u_cnn_controller (
        .clk(clk),
        .rst_n(rst_n),
        .start(start),
        .processor_config(feature_size), 
        .done(done),
        .conv1_done(conv1_done),
        .conv2_done(conv2_done),
        .conv3_done(conv3_done),
        .conv1_start(conv1_start),
        .conv2_start(conv2_start),
        .conv3_start(conv3_start)
    );

    // Weight RAM (mock read paths)
    weight_ram #(
        .WEIGHT_WIDTH(72),
        .ADDR_WIDTH(2)
    ) u_weight_ram (
        .clk(clk),
        .wea(1'b0),
        .addra(2'd0),
        .dina(72'd0),
        .enb(1'b1),
        .addrb(2'd0),   // Simplified: In reality, we'd multiplex this for different layers 
        .doutb(weights_1)
    );
    assign weights_2 = weights_1; // For simulation
    assign weights_3 = weights_1; // For simulation

    // Feature Map RAM
    wire [7:0] px_in;
    wire       px_valid;
    
    feature_map_ram #(
        .DATA_WIDTH(8),
        .ADDR_WIDTH(6)
    ) u_feature_map_ram (
        .clk(clk),
        .wea(1'b0),          // Handled externally for top level filling
        .addra(6'd0),
        .dina(8'd0),
        .enb(1'b1),
        .addrb(6'd0),
        .doutb(px_in)
    );
    
    // In a full implementation, we need counters to read from feature map RAM
    // generating px_valid and streaming pixels. We will assume simple streaming
    // by tying the valid signal high for simulation.
    assign px_valid = 1'b1; 

    // Convolution Accelerators
    conv_accelerator conv_accelerator_1 (
        .clk(clk),
        .rst_n(rst_n),
        .start(conv1_start),
        .weights(weights_1),
        .pixel_in(px_in),
        .pixel_valid(px_valid),
        .pixel_out(),
        .pixel_out_valid(),
        .done(conv1_done)
    );

    conv_accelerator conv_accelerator_2 (
        .clk(clk),
        .rst_n(rst_n),
        .start(conv2_start),
        .weights(weights_2),
        .pixel_in(px_in),
        .pixel_valid(px_valid),
        .pixel_out(),
        .pixel_out_valid(),
        .done(conv2_done)
    );

    conv_accelerator conv_accelerator_3 (
        .clk(clk),
        .rst_n(rst_n),
        .start(conv3_start),
        .weights(weights_3),
        .pixel_in(px_in),
        .pixel_valid(px_valid),
        .pixel_out(),
        .pixel_out_valid(),
        .done(conv3_done)
    );

    // =========================================================================
    // DEBUG: Monitor CNN layer transitions
    // =========================================================================
    always @(posedge clk) begin
        if (conv1_start) $display("TIME=%0t | CNN Layer 1 Started", $time);
        if (conv2_start) $display("TIME=%0t | CNN Layer 2 Started", $time);
        if (conv3_start) $display("TIME=%0t | CNN Layer 3 Started", $time);
        if (conv1_done)  $display("TIME=%0t | CNN Layer 1 Done", $time);
        if (conv2_done)  $display("TIME=%0t | CNN Layer 2 Done", $time);
        if (conv3_done)  $display("TIME=%0t | CNN Layer 3 Done", $time);
        if (done)        $display("TIME=%0t | CNN Entire Forward Pass Done", $time);
    end

endmodule
