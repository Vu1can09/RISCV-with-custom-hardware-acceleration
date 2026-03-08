# Design Methodology

## Algorithm-to-Hardware Flow

This project follows a structured design methodology from algorithm modeling through RTL verification.

```
┌──────────────────┐
│  1. Algorithm     │   Python/NumPy convolution reference model
│     Modeling      │   → Defines correct behavior
└────────┬─────────┘
         ▼
┌──────────────────┐
│  2. RTL Design    │   Verilog modules: MAC unit, accelerator FSM,
│                   │   pipeline stages, control unit
└────────┬─────────┘
         ▼
┌──────────────────┐
│  3. Integration   │   Top-level module wiring all stages,
│                   │   custom instruction decoder, forwarding
└────────┬─────────┘
         ▼
┌──────────────────┐
│  4. Simulation    │   Icarus Verilog compilation + VVP execution
│                   │   → VCD waveform generation
└────────┬─────────┘
         ▼
┌──────────────────┐
│  5. Verification  │   Compare Verilog output vs. Python reference
│                   │   → GTKWave waveform inspection
└──────────────────┘
```

## Phase Details

### Phase 1: Algorithm Modeling
- Implement 2D convolution in Python using NumPy
- Generate golden reference outputs
- Export test vectors in hex format for Verilog `$readmemh`

### Phase 2: RTL Design
- Design individual modules with clean interfaces
- Follow synthesizable RTL coding style
- Ensure each module is independently testable

### Phase 3: Integration
- Wire all pipeline stages with pipeline registers
- Add hazard detection and data forwarding
- Integrate convolution accelerator at Execute stage
- Define custom instruction opcode and control signals

### Phase 4: Simulation
- Compile with Icarus Verilog (`iverilog`)
- Run with VVP (`vvp`)
- Dump waveforms to VCD format

### Phase 5: Verification
- Automated testbench self-checks with `$display` pass/fail
- Visual waveform inspection in GTKWave
- Python validation script comparing outputs

## Tools

| Tool           | Purpose                          |
|----------------|----------------------------------|
| Icarus Verilog | Open-source Verilog simulator    |
| VVP            | Simulation runtime engine        |
| GTKWave        | Waveform viewer                  |
| Python + NumPy | Algorithm modeling & validation  |
| VS Code/Cursor | Code editor and development IDE  |
