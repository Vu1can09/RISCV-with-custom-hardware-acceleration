# 🚀 RISC-V RV32I Processor & Custom Edge AI CNN Accelerator

A complete, from-scratch **RISC-V RV32I Pipelined Processor** combined with a custom **Memory-Mapped LeNet-5 CNN Hardware Accelerator** for Edge AI applications.

> **Educational Mini Project** — Designed to be a highly accessible learning resource for electronics, computer engineering, and computer science students exploring processor architecture, hardware acceleration, and FPGA/ASIC design flows.

---

## 📖 What is this project?

This repository bridges the gap between software instructions (RISC-V Assembly) and dedicated silicon hardware (Verilog). 

Instead of doing all the heavy lifting in software, the RISC-V processor acts as the "Brain" and offloads the intense math of Artificial Intelligence (AI) to a custom-designed **Convolutional Neural Network (CNN) Accelerator** — implementing a full **LeNet-5** inference pipeline in hardware!

### 🧠 Why Hardware Acceleration for CNNs?
CNNs are the backbone of modern AI image recognition (like autonomous driving or face ID). However, running them on a standard CPU is slow because CPUs compute math sequentially. 

By designing a **Hardware Accelerator**, we can utilize hundreds of parallel multipliers (a MAC Array) to compute an entire 3x3 window of image pixels simultaneously, drastically reducing the clock cycles needed for AI inference.

### ⚡ Key Features
- **Full LeNet-5 Pipeline**: Conv1 → ReLU → Pool → Conv2 → ReLU → Pool → FC → Classification
- **INT8 Quantized Inference**: 8-bit pixel/weight precision (same as Google Edge TPU)
- **DMA Engine**: Burst memory transfers without CPU stalling
- **HD Image Support**: Processes images up to 2048×2048 pixels
- **ASIC/FPGA Ready**: Pure synthesizable Verilog 2001, zero `$display` in RTL

---

## 📐 System Architecture

### 1. Top-Level Integration

The system centers around the RISC-V Controller acting as the "Brain", dispatching configuration and execution commands downstream to the multi-layer CNN subsystem via a Memory-Mapped I/O (MMIO) bus.

```text
┌──────────────────────────────────────┐
│          system_top.v                │
│  ┌────────────────────────────────┐  │
│  │      riscv_core_top.v         │  │
│  │  5-Stage Pipeline             │  │
│  │  IF → ID → EX → MEM → WB     │  │
│  └──────────────┬────────────────┘  │
│                 │ MMIO Bus           │
│                 │ (addr ≥ 0x1000)    │
│  ┌──────────────▼────────────────┐  │
│  │  edge_ai_cnn_peripheral.v     │  │
│  │                               │  │
│  │  ┌─────────────────────────┐  │  │
│  │  │   cnn_register_interface│  │  │
│  │  └────────────┬────────────┘  │  │
│  │  ┌────────────▼────────────┐  │  │
│  │  │   cnn_controller (FSM)  │  │  │
│  │  │  DMA→L1→L2→FC→DONE     │  │  │
│  │  └────────────┬────────────┘  │  │
│  │               │               │  │
│  │  ┌────────────▼────────────┐  │  │
│  │  │  DMA Controller         │  │  │
│  │  └────────────┬────────────┘  │  │
│  │               │               │  │
│  │  ┌────────────▼────────────┐  │  │
│  │  │ Layer 1 Pipeline        │  │  │
│  │  │ Conv3D → ReLU → Pool2x2│  │  │
│  │  └────────────┬────────────┘  │  │
│  │          INT8 Quantize        │  │
│  │  ┌────────────▼────────────┐  │  │
│  │  │ Layer 2 Pipeline        │  │  │
│  │  │ Conv3D → ReLU → Pool2x2│  │  │
│  │  └────────────┬────────────┘  │  │
│  │          Flatten              │  │
│  │  ┌────────────▼────────────┐  │  │
│  │  │ FC Layer (Dense)        │  │  │
│  │  │ MAC → Class Scores      │  │  │
│  │  └─────────────────────────┘  │  │
│  └────────────────────────────────┘  │
└──────────────────────────────────────┘
```

![LeNet-5 SoC Architecture](diagrams/lenet5_system_architecture.png)

> The original single-layer system flowchart is retained for reference: [system_flowchart.png](diagrams/system_flowchart.png)

### 2. LeNet-5 Inference Pipeline

The accelerator implements a complete neural network inference datapath:

```text
Input Image (up to 2048×2048)
      │
      ▼
┌──────────┐    ┌──────┐    ┌──────────┐
│  Conv1   │───▶│ ReLU │───▶│ MaxPool  │   Layer 1
│ (3×3×C)  │    │      │    │  (2×2)   │
└──────────┘    └──────┘    └────┬─────┘
                                 │ INT8 quantize
                                 ▼
┌──────────┐    ┌──────┐    ┌──────────┐
│  Conv2   │───▶│ ReLU │───▶│ MaxPool  │   Layer 2
│ (3×3×C)  │    │      │    │  (2×2)   │
└──────────┘    └──────┘    └────┬─────┘
                                 │ flatten
                                 ▼
                          ┌──────────┐
                          │    FC    │      Fully Connected
                          │ (Dense)  │
                          └────┬─────┘
                               │
                          Class Scores
```

### 3. Single-Layer Datapath Detail

Each convolution layer internally contains:

![CNN Datapath Architecture](diagrams/lenet5_pipeline_datapath.png)

> The original single-layer datapath diagram is retained: [pipeline_datapath_diagram.png](diagrams/pipeline_datapath_diagram.png)

1. **Line Buffers (BRAM):** Cache two full rows of the image to produce a 2D spatial window — supports up to 2048px wide.
2. **Sliding Window:** Automatically shifts a 3×3 frame across the image, generating 9 pixels per clock.
3. **MAC Array (Multiply-Accumulate):** 9 parallel multipliers compute the 3×3 convolution in a single cycle.
4. **Channel Accumulator:** Sums partial results across depth channels (e.g., RGB) before emitting the final value.
5. **ReLU:** Combinational activation — clamps negative values to zero with zero latency.
6. **Max Pool 2×2:** Streaming 2×2 max pooling that halves spatial dimensions using an internal line buffer.

---

## 📁 Repository Structure

```text
.
├── rtl/                              # Integrated System RTL
│   ├── system_top.v                  # ASIC/FPGA synthesis top module
│   ├── riscv_core_top.v              # 5-stage pipelined RV32I CPU
│   ├── edge_ai_cnn_peripheral.v      # LeNet-5 CNN accelerator wrapper
│   ├── cnn_controller.v              # Multi-layer FSM controller
│   ├── cnn_register_interface.v      # MMIO register map
│   ├── cnn_layer_pipeline.v          # Reusable Conv→ReLU→Pool wrapper
│   ├── conv3d_accelerator.v          # 3D convolution datapath
│   ├── relu.v                        # ReLU activation function
│   ├── max_pool_2x2.v               # 2×2 max pooling unit
│   ├── fc_layer.v                    # Fully connected classification layer
│   ├── dma_controller.v             # Burst DMA engine
│   ├── mac_array.v                   # 9-element parallel MAC array
│   ├── line_buffer.v                 # BRAM-inferred row caching
│   ├── sliding_window.v             # 3×3 spatial window generator
│   ├── channel_accumulator.v         # Multi-channel result accumulator
│   ├── feature_map_ram.v             # Dual-port SRAM (image data)
│   ├── weight_ram.v                  # Dual-port SRAM (kernel weights)
│   ├── image_buffer.v                # 4KB image staging buffer
│   ├── alu.v, control_unit.v, pc.v   # RISC-V core components
│   ├── register_file.v              # 32-register file (x0-x31)
│   ├── pipeline_register_*.v        # Pipeline stage registers
│   └── instruction_memory.v          # Boot ROM with instructions.mem
├── edge_ai_cnn_accelerator/          # Standalone CNN test environment
│   ├── rtl/                          # Standalone CNN modules
│   ├── tb/                           # Component testbenches
│   ├── scripts/                      # Automated sim & test scripts
│   ├── python_reference/             # NumPy ground truth models
│   └── docs/                         # Detailed architecture docs
├── synth/                            # Synthesis output netlists
├── diagrams/                         # High-res block diagrams
├── docs/                             # Project-level documentation
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

### 1. Compile the Full System
```bash
git clone https://github.com/Vu1can09/RISCV-with-custom-hardware-acceleration.git
cd RISCV-with-custom-hardware-acceleration

# Verify the entire RTL compiles cleanly
iverilog -o system_check.vvp rtl/*.v
```

### 2. Run the Hardware Simulation
Our custom batch script automatically compiles the Verilog code, runs the testbenches, and generates ultra-compressed `.fst` waveform files.

```bash
cd edge_ai_cnn_accelerator

# Run the complete top-level System Integration Test
./scripts/run_simulation.sh system_integration_tb
```
If successful, the terminal will print `PASS: System integration test complete. CNN asserted done.`

### 3. View the Signals in GTKWave
You can visually inspect the electrical signals, clock ticks, and data pipelines!
```bash
gtkwave sim_out/waveforms/system.fst
```

### 4. Verify Against Python Ground Truth
Want to prove the hardware math is correct? Run our Python model to see the exact arrays the hardware is computing:
```bash
python3 python_reference/cnn_reference_model.py
```

---

## 🔍 Module Breakdown (For Students)

If you are reading the Verilog code, start here to understand the hierarchy:

### System Level
1. **`system_top.v`**: The absolute top-level ASIC/FPGA wrapper. Exposes `clk`, `reset`, and `done`.
2. **`riscv_core_top.v`**: The 5-stage pipelined RV32I CPU with data forwarding, hazard detection, and memory-mapped CNN integration.

### CNN Accelerator
3. **`edge_ai_cnn_peripheral.v`**: The full LeNet-5 CNN peripheral. Contains Layer 1, Layer 2, FC, DMA, and all intermediate SRAM buffers.
4. **`cnn_controller.v`**: The multi-layer FSM that sequences `DMA → Conv1 → Conv2 → FC → DONE`.

![Controller FSM](diagrams/controller_fsm_diagram.png)
5. **`cnn_register_interface.v`**: The MMIO register map — allows the CPU to configure image size, channels, filters, DMA parameters, and trigger inference.
6. **`cnn_layer_pipeline.v`**: Reusable single-layer wrapper chaining `conv3d_accelerator → ReLU → max_pool_2x2`.

### Datapath Components
7. **`conv3d_accelerator.v`**: The 3D convolution core — line buffers, sliding window, MAC array, and channel accumulator.
8. **`relu.v`**: Combinational ReLU activation. Zero latency.
9. **`max_pool_2x2.v`**: Streaming 2×2 max pooling with internal line buffer.
10. **`fc_layer.v`**: Sequential MAC fully connected layer producing output class scores.
11. **`mac_array.v`**: 9 parallel multipliers + adder tree for the 3×3 kernel convolution.
12. **`dma_controller.v`**: Burst DMA engine for CPU-free memory block transfers.

Every major module has its own dedicated testbench in the `tb/` folder (e.g., `mac_array_tb.v`). You can simulate any of them individually:
```bash
./scripts/run_simulation.sh mac_array_tb
```

---

## 🗺️ MMIO Register Map

The RISC-V CPU configures the CNN accelerator by writing to these memory-mapped registers (base address `0x1000`):

| Offset | Register | Width | Description |
|--------|----------|-------|-------------|
| `0x00` | CONTROL  | 1-bit | `[0]` START pulse, `[1]` DONE status |
| `0x04` | IMAGE_ADDR | 32-bit | Base address of input image |
| `0x08` | WEIGHT_ADDR | 32-bit | Base address of weight memory |
| `0x0C` | FEATURE_ADDR | 32-bit | Base address of output feature map |
| `0x10` | INPUT_WIDTH | 16-bit | Image width in pixels |
| `0x14` | INPUT_HEIGHT | 16-bit | Image height in pixels |
| `0x18` | CHANNELS | 8-bit | Layer 1 input channels |
| `0x1C` | KERNEL_SIZE | 8-bit | Convolution kernel size |
| `0x20` | NUM_FILTERS | 8-bit | Layer 1 output filters |
| `0x24` | DMA_SRC | 32-bit | DMA source address |
| `0x28` | DMA_DST | 32-bit | DMA destination address |
| `0x2C` | DMA_LEN | 16-bit | DMA transfer length (words) |
| `0x30` | DMA_START | 1-bit | DMA start pulse |
| `0x34` | L2_CHANNELS | 8-bit | Layer 2 input channels |
| `0x38` | L2_FILTERS | 8-bit | Layer 2 output filters |
| `0x3C` | FC_INPUTS | 16-bit | FC flattened input size |
| `0x40` | FC_OUTPUTS | 8-bit | FC output classes |

![MMIO Register Map](diagrams/mmio_register_map.png)

---

## 📊 Performance Specifications

| Metric | Value |
|--------|-------|
| **Max Image Size** | 2048 × 2048 pixels |
| **Max Channels** | 255 |
| **Kernel Size** | 3×3 (fixed) |
| **Parallel MACs per cycle** | 9 |
| **Pixel Precision** | 8-bit unsigned (INT8) |
| **Weight Precision** | 8-bit unsigned (INT8) |
| **Accumulator Precision** | 32-bit signed |
| **Image SRAM** | 64 KB |
| **Pipeline Layers** | Conv→ReLU→Pool × 2 + FC |
| **DMA** | Burst transfer, 1 word/cycle |

---

## 📚 Further Reading & Documentation

Dive deeper into the engineering specifications:
1. [Detailed Module Architecture](docs/architecture_overview.md)
2. [CNN Datapath Descriptions](docs/module_description.md)
3. [LeNet-5 Pipeline Architecture](docs/CNN_Accelerator_Report.md)
4. [Methodology & Design Flow](docs/methodology.md)
5. [Verification & Testing Plan](docs/verification_plan.md)
6. [FPGA Synthesizability Guidelines](docs/fpga_implementation.md)

---

## 🎯 Real-World Applications

This system can power:
- **Smart Doorbell** — Face detection on low-res thermal camera
- **Industrial QC** — Defect detection on assembly line images
- **Agricultural Drone** — Crop health analysis from aerial RGB
- **Medical Wearable** — ECG anomaly detection via 1D convolution
- **Autonomous Robot** — Obstacle edge detection for navigation
- **IoT Sensor Hub** — Vibration pattern classification

---

## 📄 License
This project is open-source and intended to foster learning in open hardware, RISC-V, and Edge AI.

<p align="center">
  <i>Built to bridge the gap between Software AI and Hardware Silicon.</i>
</p>
