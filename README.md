# 🖥️ RISC-V RV32I Processor with Custom Convolution Accelerator

A complete, from-scratch **RISC-V RV32I 5-stage pipelined processor** extended with a **custom hardware accelerator** for 3×3 convolution — built for Edge AI workloads.

> **Mini Project** — Designed to be a learning resource for students exploring processor architecture, custom instruction extensions, and hardware acceleration.

---

## ✨ What This Project Demonstrates

- **RISC-V microarchitecture design** — classic 5-stage pipeline (IF → ID → EX → MEM → WB)
- **Pipeline hazard handling** — data forwarding + load-use stall detection
- **Custom instruction extension** — adding a new opcode (`0001011`) to the ISA
- **Hardware acceleration** — FSM-driven multiply-accumulate convolution engine
- **Algorithm-to-hardware validation** — Python reference model vs. Verilog simulation
- **Full RTL simulation workflow** — Icarus Verilog → VCD → GTKWave

---

## 📐 Architecture

```
┌──────────────────────────────────────────────────────────────────┐
│                       RISC-V Core (5-Stage Pipeline)             │
│                                                                  │
│   ┌────┐  IF/ID  ┌────┐  ID/EX  ┌────┐  EX/MEM  ┌────┐  MEM/WB  ┌────┐  │
│   │ IF │───────▶│ ID │───────▶│ EX │────────▶│MEM │────────▶│ WB │  │
│   │    │        │    │        │    │         │    │         │    │  │
│   │ PC │        │Ctrl│        │ALU │         │Data│         │Mux │  │
│   │IMEM│        │RegF│        │Fwd │         │Mem │         │    │  │
│   └────┘        └────┘        └──┬─┘         └────┘         └────┘  │
│                                  │                                   │
│                         ┌────────▼────────┐                          │
│                         │  Convolution     │                         │
│                         │  Accelerator     │                         │
│                         │  (MAC Unit FSM)  │                         │
│                         └─────────────────┘                          │
│                                                                      │
│   Forwarding: EX/MEM → EX, MEM/WB → EX, WB → ID (write-first)      │
│   Hazards:    Load-use stall + Accelerator stall                     │
└──────────────────────────────────────────────────────────────────────┘
```

### Supported Instructions

| Type     | Instruction | Description                                  |
|----------|-------------|----------------------------------------------|
| I-type   | `ADDI`      | Add immediate                                |
| R-type   | `ADD`       | Register addition                            |
| R-type   | `SUB`       | Register subtraction                         |
| R-type   | `AND`       | Bitwise AND                                  |
| R-type   | `OR`        | Bitwise OR                                   |
| **Custom** | **`CONV`** | **Trigger convolution accelerator** (opcode `0001011`) |

---

## 📁 Project Structure

```
.
├── rtl/                              # Verilog RTL source files (Simulation-friendly)
├── OpenLane/src/                     # Synthesis-compliant RTL source files
├── scripts/                          # Custom EDA scripts
│   ├── synth.tcl                     #   Yosys Logic Synthesis script
│   └── physical_design.tcl           #   OpenROAD Physical Design script
├── build/                            # Generated physical design outputs
│   └── riscv_core_top.def            #   Final routed physical layout
├── tb/
│   └── riscv_testbench.v             # Testbench with auto pass/fail checks
├── sim/
│   ├── instructions.mem              # Hand-assembled test program (hex)
│   ├── run_simulation.sh             # One-command compile + simulate script
│   └── waveform.vcd                  # Generated waveform (after simulation)
├── python/                           # Reference models and validation
│   ├── convolution_reference.py      #   NumPy convolution reference model
│   ├── test_vector_generator.py      #   Generates hex test vectors for Verilog
│   └── validation_script.py          #   Compares Verilog output vs. Python
├── docs/                             # Documentation
│   ├── architecture_overview.md      #   Pipeline & accelerator architecture
│   ├── methodology.md                #   Design methodology flow
│   └── module_descriptions.md        #   Per-module signal tables
└── diagrams/                         # Architecture diagrams (PNG)
```

---

## 🚀 Quick Start

### Prerequisites

| Tool             | Install Command                              | Purpose                      |
|------------------|----------------------------------------------|------------------------------|
| **Icarus Verilog** | `brew install icarus-verilog`              | RTL Simulation               |
| **GTKWave 4.x**   | `brew install --HEAD randomplum/gtkwave/gtkwave` | Waveform Viewing           |
| **Python 3 + NumPy** | `pip3 install numpy`                     | Algorithm Validation         |
| **Docker Desktop** | [Install Here](https://www.docker.com/)     | Bare-Metal ASIC Flow        |

> **Note for macOS users:** The old GTKWave cask (3.3.107) is incompatible with macOS 14+. Use the `randomplum/gtkwave` tap shown above for version 4.x.

### 1. Clone & Simulate

```bash
git clone https://github.com/Vu1can09/RISCV-with-custom-hardware-acceleration.git
cd RISCV-with-custom-hardware-acceleration

# Compile + run simulation (one command)
bash sim/run_simulation.sh
```

You should see output like:

```
 [PASS] x1 = 10
 [PASS] x2 = 20
 [PASS] x3 = 30 (ADD)
 [PASS] x4 = -10 / 0xFFFFFFF6 (SUB)
 [PASS] x5 = 0 (AND)
 [PASS] x6 = 30 / 0x1E (OR)
 [PASS] x7 = 15 (ADDI)
 [PASS] x8 = 25 / 0x19 (CONV accelerator)
```

### 2. Bare-Metal Physical Design (ASIC Flow)

This project includes a custom, industrial-grade **Bare-Metal OpenROAD Flow** that transforms your RTL into a physical chip layout without the complexity of full OpenLane.

```bash
# Run logic synthesis and physical placement/routing
./run_custom_flow.sh
```

**Results:**
- **Logic synthesis:** Maps Verilog to Skywater 130nm standard cells.
- **Physical Design:** Automated Floorplan, PDN, Placement, and Routing.
- **Signoff:** Achieves **0 DRC violations** with 66MHz timing closure.
- **Output:** View the final design at `build/riscv_core_top.def` using KLayout.

### 3. View Waveforms

```bash
gtkwave sim/waveform.vcd
```

### 4. Run Python Reference Model

```bash
python3 python/convolution_reference.py       # See convolution math
python3 python/test_vector_generator.py       # Generate test vectors
python3 python/validation_script.py           # Validate against reference
```

---

## 🔍 How It Works

### The Pipeline

Each instruction flows through 5 stages over 5 clock cycles:

| Cycle | Stage | What Happens |
|-------|-------|-------------|
| 1     | **IF**  | Fetch instruction from memory using PC |
| 2     | **ID**  | Decode opcode, read registers, generate control signals |
| 3     | **EX**  | ALU computes result (or accelerator starts) |
| 4     | **MEM** | Read/write data memory (if needed) |
| 5     | **WB**  | Write result back to register file |

### Hazard Handling

- **Data Forwarding** — Results from EX/MEM and MEM/WB stages are forwarded back to EX stage inputs, avoiding stalls for most data dependencies
- **Write-First Register File** — When WB writes a register in the same cycle ID reads it, the new value is forwarded immediately
- **Load-Use Stall** — If an instruction in EX is a load and the next instruction in ID needs that value, the pipeline inserts a 1-cycle bubble

### The Convolution Accelerator

When the processor encounters the custom `CONV` instruction (opcode `0001011`):

1. The pipeline **stalls** (all stages freeze)
2. The accelerator's FSM moves from **IDLE → COMPUTE → DONE**
3. Over 9 cycles, it multiplies each element of a 3×3 input window with a 3×3 kernel and accumulates the result
4. When **DONE**, the result (e.g., `25`) is written back to the destination register
5. The pipeline **resumes** normal operation

**Example:** Input `[[1,2,3],[4,5,6],[7,8,9]]` × Kernel `[[1,0,1],[0,1,0],[1,0,1]]` = `1+3+5+7+9` = **25**

---

## 📝 Test Program

The test program in [`sim/instructions.mem`](sim/instructions.mem) executes:

```assembly
ADDI x1, x0, 10      # x1 = 10
ADDI x2, x0, 20      # x2 = 20
NOP                   # pipeline spacer
NOP                   # pipeline spacer
ADD  x3, x1, x2      # x3 = 10 + 20 = 30
SUB  x4, x1, x2      # x4 = 10 - 20 = -10
AND  x5, x1, x2      # x5 = 10 & 20 = 0
OR   x6, x1, x2      # x6 = 10 | 20 = 30
ADDI x7, x1, 5       # x7 = 10 + 5 = 15
CONV x8               # x8 = convolution result = 25
```

---

## 🧠 Key Design Decisions

| Decision | Why |
|----------|-----|
| **Write-first register file** | Solves WB→ID same-cycle read-after-write without extra forwarding logic |
| **Full pipeline stall for accelerator** | Simpler than out-of-order execution; accelerator takes ~12 cycles |
| **Edge-detected start signal** | Prevents re-triggering when pipeline is frozen and `accel_start` stays high |
| **Combinational busy on start** | Stall takes effect immediately in the same cycle the custom instruction enters EX |

---

## 📚 Further Reading

- [RISC-V ISA Specification](https://riscv.org/technical/specifications/)
- [Patterson & Hennessy — Computer Organization and Design (RISC-V Edition)](https://www.elsevier.com/books/computer-organization-and-design-risc-v-edition/patterson/978-0-12-820331-6)
- [Icarus Verilog Documentation](https://steveicarus.github.io/iverilog/)
- [GTKWave User Guide](https://gtkwave.sourceforge.net/gtkwave.pdf)

---

## 📄 License

This project is open-source and available for educational purposes.

---

<p align="center">
  Built with ❤️ for learning RISC-V architecture
</p>
