//============================================================================
// Testbench: RISC-V 5-Stage Pipeline Processor
// Description: Instantiates the RISC-V processor, provides clock and reset,
//              loads instruction memory, runs simulation and records VCD.
//============================================================================

`timescale 1ns / 1ps

module riscv_testbench;

    //==========================================================================
    // Clock and Reset
    //==========================================================================
    reg clk;
    reg reset;

    // Clock generation: 10ns period (100 MHz)
    initial clk = 0;
    always #5 clk = ~clk;

    //==========================================================================
    // DUT Instantiation
    //==========================================================================
    riscv_core_top u_dut (
        .clk   (clk),
        .reset (reset)
    );

    //==========================================================================
    // VCD Waveform Dump
    //==========================================================================
    initial begin
        $dumpfile("waveform.vcd");
        $dumpvars(0, riscv_testbench);
    end

    //==========================================================================
    // Simulation Control
    //==========================================================================
    initial begin
        $display("===========================================");
        $display(" RISC-V RV32I 5-Stage Pipeline Simulation");
        $display("===========================================");
        $display("");

        // Assert reset
        reset = 1;
        #20;

        // Release reset
        reset = 0;
        $display("TIME=%0t | Reset released, starting execution...", $time);
        $display("");

        // Run for enough cycles to complete the test program
        // The test program has ~12 instructions + pipeline fill/drain
        #500;

        $display("");
        $display("===========================================");
        $display(" Register File Final State");
        $display("===========================================");

        // Display non-zero registers
        $display(" x1  = 0x%08h", u_dut.u_regfile.registers[1]);
        $display(" x2  = 0x%08h", u_dut.u_regfile.registers[2]);
        $display(" x3  = 0x%08h", u_dut.u_regfile.registers[3]);
        $display(" x4  = 0x%08h", u_dut.u_regfile.registers[4]);
        $display(" x5  = 0x%08h", u_dut.u_regfile.registers[5]);
        $display(" x6  = 0x%08h", u_dut.u_regfile.registers[6]);
        $display(" x7  = 0x%08h", u_dut.u_regfile.registers[7]);
        $display(" x8  = 0x%08h", u_dut.u_regfile.registers[8]);
        $display(" x9  = 0x%08h", u_dut.u_regfile.registers[9]);
        $display(" x10 = 0x%08h", u_dut.u_regfile.registers[10]);

        $display("");
        $display("===========================================");
        $display(" Expected Results");
        $display("===========================================");
        $display(" x1 = 10  (ADDI x1, x0, 10)");
        $display(" x2 = 20  (ADDI x2, x0, 20)");
        $display(" x3 = 30  (ADD  x3, x1, x2)  => 10 + 20 = 30");
        $display(" x4 = -10 (SUB  x4, x1, x2)  => 10 - 20 = -10 = 0xFFFFFFF6");
        $display(" x5 = 0   (AND  x5, x1, x2)  => 10 & 20 = 0x0A & 0x14 = 0");
        $display(" x6 = 30  (OR   x6, x1, x2)  => 10 | 20 = 0x0A | 0x14 = 0x1E = 30");
        $display(" x7 = 15  (ADDI x7, x1, 5)   => 10 + 5 = 15");
        $display(" x8 = 25  (CONV x8) accel result");

        $display("");
        $display("===========================================");
        $display(" Verification");
        $display("===========================================");

        // Verify results
        if (u_dut.u_regfile.registers[1] == 32'd10)
            $display(" [PASS] x1 = 10");
        else
            $display(" [FAIL] x1 = %0d (expected 10)", u_dut.u_regfile.registers[1]);

        if (u_dut.u_regfile.registers[2] == 32'd20)
            $display(" [PASS] x2 = 20");
        else
            $display(" [FAIL] x2 = %0d (expected 20)", u_dut.u_regfile.registers[2]);

        if (u_dut.u_regfile.registers[3] == 32'd30)
            $display(" [PASS] x3 = 30 (ADD)");
        else
            $display(" [FAIL] x3 = %0d (expected 30)", u_dut.u_regfile.registers[3]);

        if (u_dut.u_regfile.registers[4] == 32'hFFFFFFF6)
            $display(" [PASS] x4 = -10 / 0xFFFFFFF6 (SUB)");
        else
            $display(" [FAIL] x4 = 0x%08h (expected 0xFFFFFFF6)", u_dut.u_regfile.registers[4]);

        if (u_dut.u_regfile.registers[5] == 32'd0)
            $display(" [PASS] x5 = 0 (AND)");
        else
            $display(" [FAIL] x5 = %0d (expected 0)", u_dut.u_regfile.registers[5]);

        if (u_dut.u_regfile.registers[6] == 32'h0000001E)
            $display(" [PASS] x6 = 30 / 0x1E (OR)");
        else
            $display(" [FAIL] x6 = 0x%08h (expected 0x0000001E)", u_dut.u_regfile.registers[6]);

        if (u_dut.u_regfile.registers[7] == 32'd15)
            $display(" [PASS] x7 = 15 (ADDI)");
        else
            $display(" [FAIL] x7 = %0d (expected 15)", u_dut.u_regfile.registers[7]);

        if (u_dut.u_regfile.registers[8] == 32'h00000019)
            $display(" [PASS] x8 = 25 / 0x19 (CONV accelerator)");
        else
            $display(" [FAIL] x8 = 0x%08h (expected 0x00000019 = 25)", u_dut.u_regfile.registers[8]);

        $display("");
        $display("===========================================");
        $display(" Simulation Complete");
        $display("===========================================");

        $finish;
    end

    //==========================================================================
    // Pipeline stage monitor (optional detailed trace)
    //==========================================================================
    always @(posedge clk) begin
        if (!reset) begin
            $display("TIME=%0t | PC=0x%08h | IF_Instr=0x%08h",
                     $time, u_dut.pc_current, u_dut.instruction_fetched);
        end
    end

endmodule
