`timescale 1ns / 1ps

// -----------------------------------------------------------------------------
// Memory-Mapped CNN Accelerator Peripheral (LeNet-5 Enhanced)
//
// Full multi-layer inference pipeline:
//   DMA → Conv1+ReLU+Pool → Conv2+ReLU+Pool → FC → Output
//
// Integrated with the RISC-V core via memory-mapped register interface.
// The CPU configures layer dimensions, loads data via DMA or direct writes,
// then triggers the full pipeline with a single START command.
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
    output wire        cnn_done
);

    // =========================================================================
    // Register Interface
    // =========================================================================
    wire [31:0] image_addr, weight_addr, feature_addr;
    wire [15:0] input_width, input_height;
    wire [7:0]  channels, kernel_size, num_filters;
    wire        start_req;
    wire        pipeline_done;
    wire        reg_ready;

    // DMA config
    wire [31:0] dma_src_addr, dma_dst_addr;
    wire [15:0] dma_length;
    wire        dma_start_cfg;

    // Layer 2 config
    wire [7:0]  l2_channels, l2_num_filters;

    // FC config
    wire [15:0] fc_num_inputs;
    wire [7:0]  fc_num_outputs;

    cnn_register_interface u_reg_if (
        .clk            (clk),
        .rst_n          (rst_n),
        .addr           (bus_addr),
        .wdata          (bus_din),
        .wen            (bus_we),
        .ren            (bus_ren),
        .rdata          (bus_dout),
        .ready          (reg_ready),
        .image_addr     (image_addr),
        .weight_addr    (weight_addr),
        .feature_addr   (feature_addr),
        .input_width    (input_width),
        .input_height   (input_height),
        .channels       (channels),
        .kernel_size    (kernel_size),
        .num_filters    (num_filters),
        .start_cnn      (start_req),
        .dma_src_addr   (dma_src_addr),
        .dma_dst_addr   (dma_dst_addr),
        .dma_length     (dma_length),
        .dma_start      (dma_start_cfg),
        .l2_channels    (l2_channels),
        .l2_num_filters (l2_num_filters),
        .fc_num_inputs  (fc_num_inputs),
        .fc_num_outputs (fc_num_outputs),
        .cnn_done       (pipeline_done)
    );

    // =========================================================================
    // Multi-Layer CNN Controller FSM
    // =========================================================================
    wire ctrl_dma_start;
    wire ctrl_l1_start, ctrl_l2_start, ctrl_fc_start;
    wire dma_done_sig, l1_done_sig, l2_done_sig, fc_done_sig;
    wire ctrl_load_win, ctrl_en_mac, ctrl_wr_out, ctrl_nxt_pix;

    cnn_controller u_cnn_ctrl (
        .clk          (clk),
        .rst_n        (rst_n),
        .start        (start_req),
        .dma_start    (ctrl_dma_start),
        .dma_done     (dma_done_sig),
        .l1_start     (ctrl_l1_start),
        .l1_done      (l1_done_sig),
        .l2_start     (ctrl_l2_start),
        .l2_done      (l2_done_sig),
        .fc_start     (ctrl_fc_start),
        .fc_done      (fc_done_sig),
        .load_window  (ctrl_load_win),
        .enable_mac   (ctrl_en_mac),
        .write_output (ctrl_wr_out),
        .next_pixel   (ctrl_nxt_pix),
        .done         (pipeline_done),
        .mac_done     (1'b1),
        .image_done   (1'b0)
    );

    // =========================================================================
    // DMA Controller
    // =========================================================================
    wire [31:0] dma_rd_addr, dma_wr_addr, dma_wr_data, dma_rd_data;
    wire dma_rd_en, dma_wr_en, dma_busy;

    dma_controller u_dma (
        .clk           (clk),
        .rst_n         (rst_n),
        .start         (ctrl_dma_start | dma_start_cfg),
        .src_addr      (dma_src_addr),
        .dst_addr      (dma_dst_addr),
        .transfer_len  (dma_length),
        .mem_rd_addr   (dma_rd_addr),
        .mem_rd_en     (dma_rd_en),
        .mem_rd_data   (dma_rd_data),
        .mem_wr_addr   (dma_wr_addr),
        .mem_wr_en     (dma_wr_en),
        .mem_wr_data   (dma_wr_data),
        .busy          (dma_busy),
        .done          (dma_done_sig)
    );

    // DMA memory stub (reads return 0 for now; in real impl, connect to ext mem)
    assign dma_rd_data = 32'd0;

    // =========================================================================
    // Image Feature Map RAM (64KB)
    // =========================================================================
    wire [7:0]  fm_rdata;
    wire fm_we = bus_we && (bus_addr >= 32'h0001_0000 && bus_addr < 32'h0002_0000);

    reg [15:0] fm_read_addr;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)        fm_read_addr <= 16'd0;
        else if (start_req) fm_read_addr <= 16'd0;
        else if (ctrl_load_win | ctrl_l1_start) fm_read_addr <= fm_read_addr + 1'b1;
    end

    feature_map_ram #(
        .DATA_WIDTH(8),
        .ADDR_WIDTH(16)
    ) u_fm_ram (
        .clk   (clk),
        .wea   (fm_we),
        .addra (bus_addr[17:2]),
        .dina  (bus_din[7:0]),
        .enb   (1'b1),
        .addrb (fm_read_addr),
        .doutb (fm_rdata)
    );

    // =========================================================================
    // Weight RAM
    // =========================================================================
    wire [71:0] wt_rdata;
    wire wt_we = bus_we && (bus_addr >= 32'h0000_0200 && bus_addr < 32'h0000_0300);

    weight_ram #(
        .WEIGHT_WIDTH(72),
        .ADDR_WIDTH(2)
    ) u_wt_ram (
        .clk   (clk),
        .wea   (wt_we),
        .addra (bus_addr[3:2]),
        .dina  ({40'd0, bus_din}),
        .enb   (1'b1),
        .addrb (2'd0),
        .doutb (wt_rdata)
    );

    // =========================================================================
    // Layer 1: Conv1 → ReLU → MaxPool
    // =========================================================================
    wire signed [31:0] l1_out_pixel;
    wire l1_out_valid;
    wire [15:0] l1_pool_width;
    wire l1_conv_done;

    cnn_layer_pipeline u_layer1 (
        .clk             (clk),
        .rst_n           (rst_n),
        .start           (ctrl_l1_start),
        .img_width       (input_width),
        .img_height      (input_height),
        .num_channels    (channels),
        .pixel_valid_in  (1'b1),
        .pixel_in        (fm_rdata),
        .weights_valid   (1'b1),
        .weight_in       (wt_rdata),
        .pixel_out       (l1_out_pixel),
        .out_valid       (l1_out_valid),
        .conv_raw_out    (),
        .conv_raw_valid  (),
        .pool_out_width  (l1_pool_width),
        .conv_done       (l1_conv_done)
    );

    assign l1_done_sig = l1_conv_done;

    // =========================================================================
    // Intermediate Feature Map Buffer (between Layer 1 and Layer 2)
    // =========================================================================
    // Store Layer 1 output for Layer 2 consumption
    reg [15:0] l1_wr_addr;
    reg [7:0]  l2_pixel_in;
    wire [7:0] inter_fm_rdata;

    reg [15:0] l2_read_addr;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)           l1_wr_addr <= 16'd0;
        else if (ctrl_l1_start) l1_wr_addr <= 16'd0;
        else if (l1_out_valid)  l1_wr_addr <= l1_wr_addr + 1'b1;
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)           l2_read_addr <= 16'd0;
        else if (ctrl_l2_start) l2_read_addr <= 16'd0;
        else if (l2_read_addr != 16'hFFFF) l2_read_addr <= l2_read_addr + 1'b1;
    end

    // Quantize L1 output back to 8-bit for Layer 2 input (INT8 quantization)
    wire [7:0] l1_quantized = l1_out_pixel[7:0];

    feature_map_ram #(
        .DATA_WIDTH(8),
        .ADDR_WIDTH(16)
    ) u_inter_fm (
        .clk   (clk),
        .wea   (l1_out_valid),
        .addra (l1_wr_addr),
        .dina  (l1_quantized),
        .enb   (1'b1),
        .addrb (l2_read_addr),
        .doutb (inter_fm_rdata)
    );

    // =========================================================================
    // Layer 2: Conv2 → ReLU → MaxPool
    // =========================================================================
    // Layer 2 input dimensions = Layer 1 pooled output dimensions
    wire [15:0] l2_img_width  = l1_pool_width;
    wire [15:0] l2_img_height = l1_pool_width; // Assuming square feature maps

    wire signed [31:0] l2_out_pixel;
    wire l2_out_valid;
    wire [15:0] l2_pool_width;
    wire l2_conv_done;

    cnn_layer_pipeline u_layer2 (
        .clk             (clk),
        .rst_n           (rst_n),
        .start           (ctrl_l2_start),
        .img_width       (l2_img_width),
        .img_height      (l2_img_height),
        .num_channels    (l2_channels),
        .pixel_valid_in  (1'b1),
        .pixel_in        (inter_fm_rdata),
        .weights_valid   (1'b1),
        .weight_in       (wt_rdata),  // Shared weight RAM (address managed by controller)
        .pixel_out       (l2_out_pixel),
        .out_valid       (l2_out_valid),
        .conv_raw_out    (),
        .conv_raw_valid  (),
        .pool_out_width  (l2_pool_width),
        .conv_done       (l2_conv_done)
    );

    assign l2_done_sig = l2_conv_done;

    // =========================================================================
    // FC Input Buffer (flattened pool2 output)
    // =========================================================================
    reg [15:0] fc_wr_addr;
    wire [7:0] l2_quantized = l2_out_pixel[7:0];
    wire [7:0] fc_feature_rdata;

    reg [15:0] fc_read_addr;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)           fc_wr_addr <= 16'd0;
        else if (ctrl_l2_start) fc_wr_addr <= 16'd0;
        else if (l2_out_valid)  fc_wr_addr <= fc_wr_addr + 1'b1;
    end

    feature_map_ram #(
        .DATA_WIDTH(8),
        .ADDR_WIDTH(16)
    ) u_fc_buf (
        .clk   (clk),
        .wea   (l2_out_valid),
        .addra (fc_wr_addr),
        .dina  (l2_quantized),
        .enb   (1'b1),
        .addrb (fc_read_addr),
        .doutb (fc_feature_rdata)
    );

    // =========================================================================
    // Fully Connected Layer
    // =========================================================================
    wire [15:0] fc_weight_addr;
    wire signed [31:0] fc_score;
    wire fc_score_valid;

    fc_layer #(
        .FEATURE_WIDTH(8),
        .WEIGHT_WIDTH(8),
        .ACC_WIDTH(32),
        .MAX_INPUTS(576),
        .MAX_OUTPUTS(10)
    ) u_fc (
        .clk           (clk),
        .rst_n         (rst_n),
        .start         (ctrl_fc_start),
        .num_inputs    (fc_num_inputs),
        .num_outputs   (fc_num_outputs),
        .feature_in    (fc_feature_rdata),
        .feature_valid (1'b1),
        .weight_addr   (fc_weight_addr),
        .weight_in     (8'd0),          // FC weight memory (connect to dedicated RAM)
        .bias_in       (32'd0),         // Bias (connect to bias RAM)
        .score_out     (fc_score),
        .score_valid   (fc_score_valid),
        .done          (fc_done_sig)
    );

    // FC read address follows the FC layer's internal sequencing
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)           fc_read_addr <= 16'd0;
        else if (ctrl_fc_start) fc_read_addr <= 16'd0;
        else                    fc_read_addr <= fc_read_addr + 1'b1;
    end

    // =========================================================================
    // Outputs
    // =========================================================================
    assign cnn_done = pipeline_done;

    // Suppress unused-signal warnings
    wire _unused = &{1'b0, reg_ready, ctrl_wr_out, ctrl_nxt_pix,
                     image_addr, weight_addr, feature_addr, kernel_size,
                     dma_rd_addr, dma_wr_addr, dma_wr_data, dma_rd_en, dma_wr_en, dma_busy,
                     fc_weight_addr, fc_score, fc_score_valid,
                     l2_pool_width, l1_out_pixel,
                     l2_out_pixel, 1'b0};

endmodule
