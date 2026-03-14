# 🖥️ RISC-V RV32I Processor with custom Edge AI CNN Accelerator

A complete, from-scratch **RISC-V RV32I 5-stage pipelined processor** combined with a custom **Processor-Controlled CNN Accelerator** for edge AI applications.

> **Mini Project** — Designed to be a learning resource for students exploring processor architecture, hardware acceleration, and FPGA implementation flows.

---

## ✨ What This Project Demonstrates

1. **RISC-V microarchitecture design** — classic 5-stage pipeline (IF → ID → EX → MEM → WB).
2. **Custom Hardware Acceleration** — MMIO-controlled 3D Convolution engine supporting LeNet-style inference.
3. **Pipeline hazard handling** — data forwarding + load-use stall detection.
4. **Full RTL & Python Verification workflow** — Icarus Verilog, GTKWave, and mathematical regression modeling via NumPy.

---

## 📐 Architecture

### Top-Level Integration

The system centers around the RISC-V Controller dispatching configuration and execution commands to the Edge AI subsystem via Memory-Mapped IO.

```text
                Input Image
                     │
                     ▼
                Image Buffer
                     │
                     ▼
                 RISC-V Core
           (CNN Controller / Brain)
                     │
           Control + Configuration
                     │
        ┌────────────┼────────────┐
        ▼            ▼            ▼

   Conv3D Layer1  Conv3D Layer2  Conv3D Layer3
        │            │            │
        ▼            ▼            ▼

     FeatureMap1  FeatureMap2  FeatureMap3
                     │
                     ▼
              Fully Connected
                     │
                     ▼
                Classification
```

### Supported RISC-V Instructions

| Type     | Instruction | Description                                  |
|----------|-------------|----------------------------------------------|
| I-type   | `ADDI`      | Add immediate                                |
| R-type   | `ADD`       | Register addition                            |
| R-type   | `SUB`       | Register subtraction                         |
| R-type   | `AND`       | Bitwise AND                                  |
| R-type   | `OR`        | Bitwise OR                                   |

---

## 📁 Project Structure

```text
.
├── rtl/                              # Core RISC-V Pipeline Modules
├── sim/                              # Core RISC-V simulation collateral
├── tb/                               # Core RISC-V and Top-level integration testbenches
├── docs/                             # Core RISC-V design methodology
├── edge_ai_cnn_accelerator/          # Dedicated CNN Accelerator Subsystem
│   ├── rtl/                          # 3D Convolution Datapath and Controllers
│   ├── tb/                           # CNN Component testbenches
│   ├── scripts/                      # Regression testing pipelines
│   ├── python_reference/             # Mathematical verification ground truths
│   └── docs/                         # Detailed Accelerator Architecture
```

---

## 🚀 Quick Start (CNN Accelerator Environment)

### Prerequisites

| Tool             | Install Command                              |
|------------------|----------------------------------------------|
| **Icarus Verilog** | `brew install icarus-verilog`              |
| **GTKWave 4.x**   | `brew install --HEAD randomplum/gtkwave/gtkwave` |
| **Python 3 + NumPy** | `pip3 install numpy`                     |

> **Note for macOS users:** The old GTKWave cask (3.3.107) is incompatible with macOS 14+. Use the `randomplum/gtkwave` tap shown above.

### 1. Clone & Simulate

```bash
git clone https://github.com/Vu1can09/RISCV-with-custom-hardware-acceleration.git
cd RISCV-with-custom-hardware-acceleration

# Run complete CNN verification pipeline
cd edge_ai_cnn_accelerator/scripts
./regression_test.sh
```

You should see regression output indicating `PASS` for components such as the **MAC Array**, **Conv3D Pipeline**, and **RISC-V Integrations**.

### 2. Verify against mathematical truths
```bash
cd edge_ai_cnn_accelerator
python3 python_reference/cnn_reference_model.py
```
Outputs the standard convolution validation arrays matching the expected sums computed in `tb/conv3d_accelerator_tb.v`.

---

## 🔍 How It Works: CNN Hardware Accelerator

### MMIO Interfaces

The RISC-V writes parameters like `INPUT_WIDTH`, `INPUT_HEIGHT`, and `CHANNELS` through a dedicated memory-mapped interface. Once initialized, the firmware pulses the `START` register to trigger computation.

### Complete RTL Modules Breakdown

The hardware is modularized into specialized functional block designs, all written in synthesizable Verilog:

1. **`mac_array.v`**: The core math unit. Implements 9 pipelined multipliers computing `a[i] * w[i]` followed by an adder tree accumulating them into a single 20-bit product.
2. **`line_buffer.v`**: Utilizes dual FIFOs maintaining historical row vectors to construct 2D spatial context dynamically across varying image widths.
3. **`sliding_window.v`**: Receives 3 column vectors every clock, shifts previous variables right, and exposes a flattened vector of 9 simultaneous spatial variables to the MAC Array.
4. **`channel_accumulator.v`**: Maintains a running tally of intermediate MAC array outputs. It asserts `clear` at the completion of spatial tensor boundaries.
5. **`conv3d_accelerator.v`**: The structural wrapper organizing the line buffers, sliding windows, and MAC units into a single cohesive data stream.
6. **`cnn_controller.v`**: A Moore Finite State Machine (FSM) spanning `IDLE` -> `LOAD_WINDOW` -> `MULTIPLY` -> `ACCUMULATE` -> `WRITE_OUTPUT`. It coordinates memory read requests and enables accelerator modules.
7. **`cnn_register_interface.v`**: An adaptable MMIO address map exposing software configurations (`input_width`, `channels`, etc.) to the CNN Controller hardware.
8. **`riscv_core_controller.v`**: A soft-core module driving a predefined instruction sequence mimicking firmware execution. 
9. **`edge_ai_cnn_top.v`**: The primary integration wrapper tying the RISC-V controller to the CNN datapath.

### Verification Environment (Testbenches)

A multi-tiered testbench setup systematically proves correctness mapping from fundamental arithmetic up to full system integration:

1. **`mac_array_tb.v`**: Tests combinational multiply-accumulate arithmetic logic on 3x3 sliding windows, pushing constant values and complex vectors to ensure no overflow and correct bit-width mapping.
2. **`sliding_window_tb.v`**: Isolates the vector generation logic, feeding rows of pixels and monitoring the resulting flattened 3x3 window vector outputs across clock cycles.
3. **`conv3d_accelerator_tb.v`**: Validates the sequential streaming logic, packing sliding windows, utilizing the MAC, and tracking internal channel accumulator loops.
4. **`cnn_controller_tb.v`**: Tracks FSM transition validity across control signal boundaries ensuring correct state tracking.
5. **`riscv_control_tb.v`**: Examines hardware/software boundary, making sure register writes target correct memory map addresses over the system bus.
6. **`system_integration_tb.v`**: The capstone integration test running the instantiated RISC-V controller orchestrating the full sub-pipeline until a theoretical `DONE` interrupt flag pulses.

### Verification against mathematical truths
The testbenches mirror expected results tracked in pure python.
```bash
cd edge_ai_cnn_accelerator
python3 python_reference/cnn_reference_model.py
```
This Python script runs a generic 3D N-channel mathematical convolution loop locally using NumPy to cross-validate convolution constants with RTL outputs.

---

## 📚 Further Reading

Looking to synthesize? Check out the specific detailed FPGA strategies in `edge_ai_cnn_accelerator/docs/fpga_implementation.md`.

- [RISC-V ISA Specification](https://riscv.org/technical/specifications/)
- [Patterson & Hennessy — Computer Organization and Design (RISC-V Edition)](https://www.elsevier.com/books/computer-organization-and-design-risc-v-edition/patterson/978-0-12-820331-6)
- [Icarus Verilog Documentation](https://steveicarus.github.io/iverilog/)

---

## 📄 License

This project is open-source and available for educational purposes.

---

<p align="center">
  Built with 🥀 for learning RISC-V and Edge AI architecture
</p>
