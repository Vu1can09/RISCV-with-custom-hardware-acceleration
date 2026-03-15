// -----------------------------------------------------------------------------
// Top-level wrapper for ASIC synthesis
//
// This module instantiates the pipelined RISC-V core with integrated CNN
// accelerator (memory-mapped) and exposes the top-level clock/reset pins.
//
// For ASIC implementation, replace the internal instruction/data memory
// in riscv_core_top with external SRAM/BRAM interfaces as needed.
// -----------------------------------------------------------------------------

module system_top (
    input  wire clk,
    input  wire reset,
    output wire done
);

    riscv_core_top u_riscv_core (
        .clk         (clk),
        .reset       (reset),
        .system_done (done)
    );

endmodule
