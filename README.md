# 🚀 RISC-V RV32I Processor & Custom Edge AI CNN Accelerator

A complete, from-scratch **RISC-V RV32I Pipelined Processor** combined with a custom **Memory-Mapped CNN Hardware Accelerator** for Edge AI applications.

> **Educational Mini Project** — Designed to be a highly accessible learning resource for electronics, computer engineering, and computer science students exploring processor architecture, hardware acceleration, and FPGA design flows.

---

## 📖 What is this project?

This repository bridges the gap between software instructions (RISC-V Assembly) and dedicated silicon hardware (Verilog). 

Instead of doing all the heavy lifting in software, the RISC-V processor acts as the "Brain" and offloads the intense math of Artificial Intelligence (AI) to a custom-designed **Convolutional Neural Network (CNN) Accelerator**!

### 🧠 Why Hardware Acceleration for CNNs?
CNNs are the backbone of modern AI image recognition (like autonomous driving or face ID). However, running them on a standard CPU is slow because CPUs compute math sequentially. 

By designing a **Hardware Accelerator**, we can utilize hundreds of parallel multipliers (a MAC Array) to compute an entire 3x3 window of image pixels simultaneously, drastically reducing the clock cycles needed for AI inference.

---

## 📐 System Architecture

### 1. Top-Level Integration
The system centers around the RISC-V Controller acting as the "Brain", dispatching configuration and execution commands downstream to a multi-stage Edge AI subsystem via a Memory-Mapped I/O (MMIO) bus.

```text
┌─────────────────────────┐
│       RISC-V Core       │
│        ("Brain")        │
└───────────┬─────────────┘
            │ MMIO Bus
            ▼
┌─────────────────────────┐
│     CNN Controller      │
│  (Config & Scheduling)  │
└───────────┬─────────────┘
            │ Datapath
      ┌─────┼─────┐
      ▼     ▼     ▼
  ┌──────┐┌──────┐┌──────┐
  │ Conv ││ Conv ││ Conv │
  │ Unit ││ Unit ││ Unit │
  │  1   ││  2   ││  3   │
  └──────┘└──────┘└──────┘
```

![Edge AI System Flowchart](diagrams/system_flowchart.png)

### 2. CNN Datapath (How the Accelerator Works)
Once the RISC-V core triggers the accelerator, pixels stream from the internal SRAM into the computation pipeline.

![CNN Datapath Architecture](diagrams/pipeline_datapath_diagram.png)

1. **Line Buffers:** Store rows of the image to create a 2D spatial view.
2. **Sliding Window:** Automatically shifts a 3x3 frame across the image.
3. **MAC Array (Multiply-Accumulate):** 9 Parallel multipliers compute the convolution math instantly.
4. **Channel Accumulator:** Adds up the depths of 3D tensors (like RGB channels) before writing the final result back to memory.

---

## 📁 Repository Structure

```text
.
├── rtl/                              # Core RISC-V Pipeline Modules
├── edge_ai_cnn_accelerator/          # Dedicated CNN Accelerator Project
│   ├── rtl/                          # 3D Convolution Datapath (Verilog)
│   ├── tb/                           # Individual component testbenches
│   ├── scripts/                      # Automated simulation & testing scripts
│   ├── python_reference/             # Mathematical ground truths (NumPy)
│   └── docs/                         # Detailed Architecture Documentation
├── diagrams/                         # High-res block diagrams
└── sim/                              # CPU simulation collateral
```

---

## 🚀 Quick Start Guide

We have set up a fully automated simulation environment so you can see the hardware in action without an actual FPGA board!

### Prerequisites
You need a Verilog simulator and a waveform viewer.
* **Mac Users:** `brew install icarus-verilog` and `brew install --HEAD randomplum/gtkwave/gtkwave`
* **Linux Users:** `sudo apt install iverilog gtkwave`
* **Python:** `pip3 install numpy`

### 1. Run the Hardware Simulation
Our custom batch script automatically compiles the Verilog code, runs the testbenches, and generates ultra-compressed `.fst` waveform files.

```bash
git clone https://github.com/Vu1can09/RISCV-with-custom-hardware-acceleration.git
cd RISCV-with-custom-hardware-acceleration/edge_ai_cnn_accelerator

# Run the complete top-level System Integration Test
./scripts/run_simulation.sh system_integration_tb
```
If successful, the terminal will print `PASS: System integration test complete. CNN asserted done.`

### 2. View the Signals in GTKWave
You can visually inspect the electrical signals, clock ticks, and data pipelines!
```bash
gtkwave sim_out/waveforms/system.fst
```

### 3. Verify Against Python Ground Truth
Want to prove the hardware math is correct? Run our Python model to see the exact arrays the hardware is computing:
```bash
python3 python_reference/cnn_reference_model.py
```

---

## 🔍 Module Breakdown (For Students)

If you are reading the Verilog code, start here to understand the hierarchy:

1. **`edge_ai_cnn_top.v`**: The absolute top of the design. Connects the processor to the CNN.
2. **`cnn_controller.v`**: The "Traffic Cop". A Finite State Machine (FSM) that dictates when to load memory, when to compute, and when to write back based on the `START` signal.
3. **`conv3d_accelerator.v`**: The computation wrapper. This holds the Line Buffers, Sliding Window, and MAC array.
4. **`mac_array.v`**: The raw mathematics. Nine `*` (multipliers) and a tree of `+` (adders).

Every major module has its own dedicated testbench in the `tb/` folder (e.g., `mac_array_tb.v`). You can simulate any of them individually:
```bash
./scripts/run_simulation.sh mac_array_tb
```

---

## 📚 Further Reading & Documentation

Dive deeper into the engineering specifications:
1. [Detailed Module Architecture](edge_ai_cnn_accelerator/docs/architecture.md)
2. [CNN Datapath Descriptions](edge_ai_cnn_accelerator/docs/module_description.md)
3. [Verification & Testing Plan](edge_ai_cnn_accelerator/docs/verification_plan.md)
4. [FPGA Synthesizability Guidelines](edge_ai_cnn_accelerator/docs/fpga_implementation.md)

---

## 📄 License
This project is open-source and intended to foster learning in open hardware, RISC-V, and Edge AI.

<p align="center">
  <i>Built to bridge the gap between Software AI and Hardware Silicon.</i>
</p>
