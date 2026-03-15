`timescale 1ns / 1ps

// -----------------------------------------------------------------------------
// AXI4-Lite Slave Interface
//
// Standard AXI4-Lite slave wrapper for the CNN accelerator register interface.
// Translates AXI4-Lite read/write transactions to the simple wen/ren/addr/wdata
// signals expected by `cnn_register_interface.v`.
//
// This enables drop-in integration with ARM-based SoCs, Xilinx Zynq, and
// other AXI4 ecosystem designs.
//
// Simplified AXI4-Lite (single outstanding, no burst):
//   - Write: AWVALID+WVALID → complete in same cycle
//   - Read:  ARVALID → RVALID+RDATA next cycle
// -----------------------------------------------------------------------------

module axi4_lite_slave #(
    parameter ADDR_WIDTH = 32,
    parameter DATA_WIDTH = 32
)(
    input  wire                    ACLK,
    input  wire                    ARESETn,

    // Write Address Channel
    input  wire [ADDR_WIDTH-1:0]   AWADDR,
    input  wire                    AWVALID,
    output reg                     AWREADY,

    // Write Data Channel
    input  wire [DATA_WIDTH-1:0]   WDATA,
    input  wire [3:0]              WSTRB,
    input  wire                    WVALID,
    output reg                     WREADY,

    // Write Response Channel
    output reg  [1:0]              BRESP,
    output reg                     BVALID,
    input  wire                    BREADY,

    // Read Address Channel
    input  wire [ADDR_WIDTH-1:0]   ARADDR,
    input  wire                    ARVALID,
    output reg                     ARREADY,

    // Read Data Channel
    output reg  [DATA_WIDTH-1:0]   RDATA,
    output reg  [1:0]              RRESP,
    output reg                     RVALID,
    input  wire                    RREADY,

    // Internal register interface (to cnn_register_interface)
    output reg  [ADDR_WIDTH-1:0]   reg_addr,
    output reg  [DATA_WIDTH-1:0]   reg_wdata,
    output reg                     reg_wen,
    output reg                     reg_ren,
    input  wire [DATA_WIDTH-1:0]   reg_rdata
);

    // Write FSM
    localparam WR_IDLE = 2'd0, WR_DATA = 2'd1, WR_RESP = 2'd2;
    reg [1:0] wr_state;

    // Read FSM
    localparam RD_IDLE = 2'd0, RD_DATA = 2'd1;
    reg [1:0] rd_state;

    reg [ADDR_WIDTH-1:0] wr_addr_reg;

    // ---------- Write Path ----------
    always @(posedge ACLK or negedge ARESETn) begin
        if (!ARESETn) begin
            wr_state  <= WR_IDLE;
            AWREADY   <= 1'b0;
            WREADY    <= 1'b0;
            BVALID    <= 1'b0;
            BRESP     <= 2'b00;
            reg_wen   <= 1'b0;
            reg_addr  <= 0;
            reg_wdata <= 0;
            wr_addr_reg <= 0;
        end else begin
            reg_wen <= 1'b0;  // Pulse

            case (wr_state)
                WR_IDLE: begin
                    BVALID <= 1'b0;
                    if (AWVALID && WVALID) begin
                        // Both address and data arrive together
                        reg_addr  <= AWADDR;
                        reg_wdata <= WDATA;
                        reg_wen   <= 1'b1;
                        AWREADY   <= 1'b1;
                        WREADY    <= 1'b1;
                        wr_state  <= WR_RESP;
                    end else if (AWVALID) begin
                        wr_addr_reg <= AWADDR;
                        AWREADY     <= 1'b1;
                        wr_state    <= WR_DATA;
                    end
                end

                WR_DATA: begin
                    AWREADY <= 1'b0;
                    if (WVALID) begin
                        reg_addr  <= wr_addr_reg;
                        reg_wdata <= WDATA;
                        reg_wen   <= 1'b1;
                        WREADY    <= 1'b1;
                        wr_state  <= WR_RESP;
                    end
                end

                WR_RESP: begin
                    AWREADY <= 1'b0;
                    WREADY  <= 1'b0;
                    BVALID  <= 1'b1;
                    BRESP   <= 2'b00;  // OKAY
                    if (BREADY) begin
                        BVALID   <= 1'b0;
                        wr_state <= WR_IDLE;
                    end
                end

                default: wr_state <= WR_IDLE;
            endcase
        end
    end

    // ---------- Read Path ----------
    always @(posedge ACLK or negedge ARESETn) begin
        if (!ARESETn) begin
            rd_state <= RD_IDLE;
            ARREADY  <= 1'b0;
            RVALID   <= 1'b0;
            RDATA    <= 0;
            RRESP    <= 2'b00;
            reg_ren  <= 1'b0;
        end else begin
            reg_ren <= 1'b0;  // Pulse

            case (rd_state)
                RD_IDLE: begin
                    RVALID <= 1'b0;
                    if (ARVALID) begin
                        reg_addr <= ARADDR;
                        reg_ren  <= 1'b1;
                        ARREADY  <= 1'b1;
                        rd_state <= RD_DATA;
                    end
                end

                RD_DATA: begin
                    ARREADY <= 1'b0;
                    RDATA   <= reg_rdata;
                    RVALID  <= 1'b1;
                    RRESP   <= 2'b00;  // OKAY
                    if (RREADY) begin
                        RVALID   <= 1'b0;
                        rd_state <= RD_IDLE;
                    end
                end

                default: rd_state <= RD_IDLE;
            endcase
        end
    end

    // Suppress unused signals
    wire _unused = &{1'b0, WSTRB, 1'b0};

endmodule
