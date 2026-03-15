`timescale 1ns / 1ps

// -----------------------------------------------------------------------------
// Memory-mapped CNN accelerator peripheral
//
// This module is intended to be instantiated by the pipelined RISC-V core
// (riscv_core_top) using a simple memory-mapped register interface.
//
// Address map matches the existing cnn_register_interface implementation.
// -----------------------------------------------------------------------------

module edge_ai_cnn_peripheral (
    input  wire        clk,
    input  wire        rst_n,

    // Memory-mapped I/O (RISC-V will drive these signals)
    input  wire        bus_we,
    input  wire        bus_ren,
    input  wire [31:0] bus_addr,
    input  wire [31:0] bus_din,
    output wire [31:0] bus_dout,

    // Accelerator status
    output wire       cnn_done
);

    // -------------------------------------------------------------------------
    // Register interface (memory-mapped register file)
    // -------------------------------------------------------------------------
    wire [31:0] image_addr;
    wire [31:0] weight_addr;
    wire [31:0] feature_addr;
    wire [7:0]  input_width;
    wire [7:0]  input_height;
    wire [7:0]  channels;
    wire [7:0]  kernel_size;
    wire [7:0]  num_filters;
    wire        start_req;
    wire        conv_done;
    wire        reg_ready;

    cnn_register_interface u_reg_if (
        .clk          (clk),
        .rst_n        (rst_n),
        .addr         (bus_addr),
        .wdata        (bus_din),
        .wen          (bus_we),
        .ren          (bus_ren),
        .rdata        (bus_dout),
        .ready        (reg_ready),
        .image_addr   (image_addr),
        .weight_addr  (weight_addr),
        .feature_addr (feature_addr),
        .input_width  (input_width),
        .input_height (input_height),
        .channels     (channels),
        .kernel_size  (kernel_size),
        .num_filters  (num_filters),
        .start_cnn    (start_req),
        .cnn_done     (conv_done)
    );

    // -------------------------------------------------------------------------
    // CNN Control and datapath (same as in edge_ai_cnn_top)
    // -------------------------------------------------------------------------
    wire load_win, en_mac, wr_out, nxt_pix;

    cnn_controller u_cnn_ctrl (
        .clk         (clk),
        .rst_n       (rst_n),
        .start       (start_req),
        .load_window (load_win),
        .enable_mac  (en_mac),
        .write_output(wr_out),
        .next_pixel  (nxt_pix),
        .done        (conv_done),
        .mac_done    (1'b1), // Mock condition for simplicity
        .image_done  (1'b0)  // Managed by datapath top
    );

    wire [31:0] fm_out_data;
    wire        fm_out_valid;

    conv3d_accelerator u_conv1 (
        .clk            (clk),
        .rst_n          (rst_n),
        .start_conv     (start_req),
        .img_width      (input_width),
        .img_height     (input_height),
        .num_channels   (channels),
        .pixel_valid_in (load_win),    // Driven by controller
        .pixel_in       (8'h01),       // Connect to image buffer read (TODO)
        .weights_valid  (en_mac),      // Driven by controller
        .weight_in      (72'h0101010101010101), // TODO: hook to weight memory
        .pixel_out      (fm_out_data),
        .out_valid      (fm_out_valid),
        .done           (conv_done)
    );

    // -------------------------------------------------------------------------
    // Outputs
    // -------------------------------------------------------------------------
    assign cnn_done = conv_done;

    // Prevent unused-signal warnings for unused outputs/inputs
    wire _unused = &{1'b0, reg_ready, wr_out, nxt_pix, fm_out_data, fm_out_valid};

endmodule
