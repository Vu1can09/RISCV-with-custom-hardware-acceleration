`timescale 1ns / 1ps

// -----------------------------------------------------------------------------
// CNN Register Interface (Memory-Mapped)
//
// Extended for multi-layer LeNet-5 pipeline with DMA and FC support.
//
// Register Map:
//   0x00 : STATUS/CONTROL  [0] START, [1] DONE
//   0x04 : IMAGE_ADDR
//   0x08 : WEIGHT_ADDR
//   0x0C : FEATURE_ADDR
//   0x10 : INPUT_WIDTH     (16-bit, supports up to 65535)
//   0x14 : INPUT_HEIGHT    (16-bit)
//   0x18 : CHANNELS        (8-bit, Layer 1 input channels)
//   0x1C : KERNEL_SIZE     (8-bit)
//   0x20 : NUM_FILTERS     (8-bit, Layer 1 output filters)
//   --- DMA Registers ---
//   0x24 : DMA_SRC_ADDR
//   0x28 : DMA_DST_ADDR
//   0x2C : DMA_LENGTH
//   0x30 : DMA_START       [0] START pulse
//   --- Layer 2 Registers ---
//   0x34 : L2_CHANNELS     (8-bit, Layer 2 input channels = L1 num_filters)
//   0x38 : L2_NUM_FILTERS  (8-bit, Layer 2 output filters)
//   --- FC Layer Registers ---
//   0x3C : FC_NUM_INPUTS   (16-bit, flattened input size)
//   0x40 : FC_NUM_OUTPUTS  (8-bit, number of classes)
// -----------------------------------------------------------------------------

module cnn_register_interface (
    input wire clk,
    input wire rst_n,

    // Simple Memory-Mapped Interface from RISC-V
    input wire [31:0] addr,
    input wire [31:0] wdata,
    input wire wen,
    input wire ren,
    output reg [31:0] rdata,
    output reg ready,

    // CNN configuration registers
    output reg [31:0] image_addr,
    output reg [31:0] weight_addr,
    output reg [31:0] feature_addr,
    output reg [15:0] input_width,
    output reg [15:0] input_height,
    output reg [7:0]  channels,
    output reg [7:0]  kernel_size,
    output reg [7:0]  num_filters,
    output reg        start_cnn,

    // DMA configuration
    output reg [31:0] dma_src_addr,
    output reg [31:0] dma_dst_addr,
    output reg [15:0] dma_length,
    output reg        dma_start,

    // Layer 2 configuration
    output reg [7:0]  l2_channels,
    output reg [7:0]  l2_num_filters,

    // FC configuration
    output reg [15:0] fc_num_inputs,
    output reg [7:0]  fc_num_outputs,

    // Status from CNN
    input wire        cnn_done
);

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            image_addr     <= 0;
            weight_addr    <= 0;
            feature_addr   <= 0;
            input_width    <= 0;
            input_height   <= 0;
            channels       <= 0;
            kernel_size    <= 0;
            num_filters    <= 0;
            start_cnn      <= 0;
            dma_src_addr   <= 0;
            dma_dst_addr   <= 0;
            dma_length     <= 0;
            dma_start      <= 0;
            l2_channels    <= 0;
            l2_num_filters <= 0;
            fc_num_inputs  <= 0;
            fc_num_outputs <= 0;
            rdata          <= 0;
            ready          <= 0;
        end else begin
            ready     <= 1'b0;
            start_cnn <= 1'b0;  // Pulse
            dma_start <= 1'b0;  // Pulse

            if (wen) begin
                ready <= 1'b1;
                case (addr[7:0])
                    8'h00: start_cnn      <= wdata[0];
                    8'h04: image_addr     <= wdata;
                    8'h08: weight_addr    <= wdata;
                    8'h0C: feature_addr   <= wdata;
                    8'h10: input_width    <= wdata[15:0];
                    8'h14: input_height   <= wdata[15:0];
                    8'h18: channels       <= wdata[7:0];
                    8'h1C: kernel_size    <= wdata[7:0];
                    8'h20: num_filters    <= wdata[7:0];
                    8'h24: dma_src_addr   <= wdata;
                    8'h28: dma_dst_addr   <= wdata;
                    8'h2C: dma_length     <= wdata[15:0];
                    8'h30: dma_start      <= wdata[0];
                    8'h34: l2_channels    <= wdata[7:0];
                    8'h38: l2_num_filters <= wdata[7:0];
                    8'h3C: fc_num_inputs  <= wdata[15:0];
                    8'h40: fc_num_outputs <= wdata[7:0];
                    default: ;
                endcase
            end else if (ren) begin
                ready <= 1'b1;
                case (addr[7:0])
                    8'h00: rdata <= {30'd0, cnn_done, 1'b0};
                    8'h04: rdata <= image_addr;
                    8'h08: rdata <= weight_addr;
                    8'h0C: rdata <= feature_addr;
                    8'h10: rdata <= {16'd0, input_width};
                    8'h14: rdata <= {16'd0, input_height};
                    8'h18: rdata <= {24'd0, channels};
                    8'h1C: rdata <= {24'd0, kernel_size};
                    8'h20: rdata <= {24'd0, num_filters};
                    8'h24: rdata <= dma_src_addr;
                    8'h28: rdata <= dma_dst_addr;
                    8'h2C: rdata <= {16'd0, dma_length};
                    8'h34: rdata <= {24'd0, l2_channels};
                    8'h38: rdata <= {24'd0, l2_num_filters};
                    8'h3C: rdata <= {16'd0, fc_num_inputs};
                    8'h40: rdata <= {24'd0, fc_num_outputs};
                    default: rdata <= 32'hDEADBEEF;
                endcase
            end
        end
    end

    // Suppress unused-signal warning for upper address bits
    wire _unused = &{1'b0, addr[31:8], 1'b0};

endmodule
