`timescale 1ns / 1ps

// -----------------------------------------------------------------------------
// Top-level wrapper for ASIC synthesis
//
// This module instantiates the pipelined RISC-V core with integrated CNN
// accelerator (memory-mapped) and exposes top-level ports for:
//   1. Clock and Reset
//   2. AXI4 Master Interface (for external DDR memory access)
//   3. Completion Status (done)
//
// For ASIC implementation, connect these AXI ports to your memory controller
// or NoC (Network-on-Chip).
// -----------------------------------------------------------------------------

module system_top (
    input  wire clk,
    input  wire reset,

    // ---- AXI4 Master Interface (External Memory) ----
    output wire [31:0] M_AXI_AWADDR,
    output wire [7:0]  M_AXI_AWLEN,
    output wire [2:0]  M_AXI_AWSIZE,
    output wire [1:0]  M_AXI_AWBURST,
    output wire        M_AXI_AWVALID,
    input  wire        M_AXI_AWREADY,
    output wire [31:0] M_AXI_WDATA,
    output wire [3:0]  M_AXI_WSTRB,
    output wire        M_AXI_WLAST,
    output wire        M_AXI_WVALID,
    input  wire        M_AXI_WREADY,
    input  wire [1:0]  M_AXI_BRESP,
    input  wire        M_AXI_BVALID,
    output wire        M_AXI_BREADY,
    output wire [31:0] M_AXI_ARADDR,
    output wire [7:0]  M_AXI_ARLEN,
    output wire [2:0]  M_AXI_ARSIZE,
    output wire [1:0]  M_AXI_ARBURST,
    output wire        M_AXI_ARVALID,
    input  wire        M_AXI_ARREADY,
    input  wire [31:0] M_AXI_RDATA,
    input  wire [1:0]  M_AXI_RRESP,
    input  wire        M_AXI_RLAST,
    input  wire        M_AXI_RVALID,
    output wire        M_AXI_RREADY,

    output wire        done
);

    riscv_core_top u_riscv_core (
        .clk         (clk),
        .reset       (reset),
        
        .M_AXI_AWADDR (M_AXI_AWADDR), .M_AXI_AWLEN  (M_AXI_AWLEN),  .M_AXI_AWSIZE (M_AXI_AWSIZE), 
        .M_AXI_AWBURST(M_AXI_AWBURST),.M_AXI_AWVALID(M_AXI_AWVALID),.M_AXI_AWREADY(M_AXI_AWREADY),
        .M_AXI_WDATA  (M_AXI_WDATA),  .M_AXI_WSTRB  (M_AXI_WSTRB),  .M_AXI_WLAST  (M_AXI_WLAST),
        .M_AXI_WVALID (M_AXI_WVALID), .M_AXI_WREADY (M_AXI_WREADY),
        .M_AXI_BRESP  (M_AXI_BRESP),  .M_AXI_BVALID (M_AXI_BVALID), .M_AXI_BREADY (M_AXI_BREADY),
        .M_AXI_ARADDR (M_AXI_ARADDR), .M_AXI_ARLEN  (M_AXI_ARLEN),  .M_AXI_ARSIZE (M_AXI_ARSIZE),
        .M_AXI_ARBURST(M_AXI_ARBURST),.M_AXI_ARVALID(M_AXI_ARVALID),.M_AXI_ARREADY(M_AXI_ARREADY),
        .M_AXI_RDATA  (M_AXI_RDATA),  .M_AXI_RRESP  (M_AXI_RRESP),  .M_AXI_RLAST  (M_AXI_RLAST),
        .M_AXI_RVALID (M_AXI_RVALID), .M_AXI_RREADY (M_AXI_RREADY),
        
        .system_done (done)
    );

endmodule
