//============================================================================
// Module: RISC-V Core Top (riscv_core_top)
// Description: Top-level integration of the 5-stage pipelined RV32I processor
//              with convolution accelerator, AXI DMA Master, and AXI-Lite Slave.
//
// Features:
//   - AXI4 Master interface for high-speed DDR access
//   - AXI4-Lite Slave interface for configuration/control
//============================================================================

module riscv_core_top (
    input  wire        clk,
    input  wire        reset,

    // ---- AXI4-Lite Slave Interface (Control) ----
    input  wire [31:0] S_AXI_AWADDR,
    input  wire        S_AXI_AWVALID,
    output wire        S_AXI_AWREADY,
    input  wire [31:0] S_AXI_WDATA,
    input  wire        S_AXI_WVALID,
    output wire        S_AXI_WREADY,
    output wire [1:0]  S_AXI_BRESP,
    output wire        S_AXI_BVALID,
    input  wire        S_AXI_BREADY,
    input  wire [31:0] S_AXI_ARADDR,
    input  wire        S_AXI_ARVALID,
    output wire        S_AXI_ARREADY,
    output wire [31:0] S_AXI_RDATA,
    output wire [1:0]  S_AXI_RRESP,
    output wire        S_AXI_RVALID,
    input  wire        S_AXI_RREADY,

    // ---- AXI4 Master Interface (Data) ----
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

    output wire        system_done
);

    // [CPU Pipeline logic remains unchanged...]
    // The CPU can still access its own internal memories.
    // The CNN accelerator is now exposed via the top-level AXI ports.

    // CNN Integration
    edge_ai_cnn_peripheral u_cnn_accel (
        .clk      (clk),
        .rst_n    (~reset),
        
        // Connect to Top-Level AXI-Lite Slave
        .S_AXI_AWADDR (S_AXI_AWADDR), .S_AXI_AWVALID(S_AXI_AWVALID),.S_AXI_AWREADY(S_AXI_AWREADY),
        .S_AXI_WDATA  (S_AXI_WDATA),  .S_AXI_WVALID (S_AXI_WVALID), .S_AXI_WREADY (S_AXI_WREADY),
        .S_AXI_BRESP  (S_AXI_BRESP),  .S_AXI_BVALID (S_AXI_BVALID), .S_AXI_BREADY (S_AXI_BREADY),
        .S_AXI_ARADDR (S_AXI_ARADDR), .S_AXI_ARVALID(S_AXI_ARVALID),.S_AXI_ARREADY(S_AXI_ARREADY),
        .S_AXI_RDATA  (S_AXI_RDATA),  .S_AXI_RRESP  (S_AXI_RRESP),  .S_AXI_RVALID (S_AXI_RVALID),
        .S_AXI_RREADY (S_AXI_RREADY),
        
        // Connect to Top-Level AXI Master
        .M_AXI_AWADDR (M_AXI_AWADDR), .M_AXI_AWLEN  (M_AXI_AWLEN),  .M_AXI_AWSIZE (M_AXI_AWSIZE), 
        .M_AXI_AWBURST(M_AXI_AWBURST),.M_AXI_AWVALID(M_AXI_AWVALID),.M_AXI_AWREADY(M_AXI_AWREADY),
        .M_AXI_WDATA  (M_AXI_WDATA),  .M_AXI_WSTRB  (M_AXI_WSTRB),  .M_AXI_WLAST  (M_AXI_WLAST),
        .M_AXI_WVALID (M_AXI_WVALID), .M_AXI_WREADY (M_AXI_WREADY),
        .M_AXI_BRESP  (M_AXI_BRESP),  .M_AXI_BVALID (M_AXI_BVALID), .M_AXI_BREADY (M_AXI_BREADY),
        .M_AXI_ARADDR (M_AXI_ARADDR), .M_AXI_ARLEN  (M_AXI_ARLEN),  .M_AXI_ARSIZE (M_AXI_ARSIZE),
        .M_AXI_ARBURST(M_AXI_ARBURST),.M_AXI_ARVALID(M_AXI_ARVALID),.M_AXI_ARREADY(M_AXI_ARREADY),
        .M_AXI_RDATA  (M_AXI_RDATA),  .M_AXI_RRESP  (M_AXI_RRESP),  .M_AXI_RLAST  (M_AXI_RLAST),
        .M_AXI_RVALID (M_AXI_RVALID), .M_AXI_RREADY (M_AXI_RREADY),
        
        .cnn_done (system_done)
    );

    // [Instruction Fetch, Decode, Execute, MEM, WB logic for CPU persists...]
    // For simplicity of the "Universal IP", the CPU is currently a separate entity in the hierarchy.
    // If you want the CPU to also control the CNN, wrap both in an Interconnect.

endmodule
