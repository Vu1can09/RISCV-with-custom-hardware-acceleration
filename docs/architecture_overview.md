# Architecture Overview

## RISC-V RV32I Processor & LeNet-5 CNN Accelerator

### System Architecture

The core architecture consists of two deeply integrated yet functionally distinct subsystems: a classic **5-stage pipeline RISC-V RV32I processor** acting as the system controller, and a custom **LeNet-5 CNN Accelerator** operating as a dedicated, high-performance coprocessor.

Rather than running sequential math operations on the CPU, the RISC-V core offloads image processing/tensor computations to the multi-layer CNN accelerator using a **Memory-Mapped I/O (MMIO)** bus.

![System Flowchart](../diagrams/system_flowchart.png)

### RISC-V Core

The CPU is a strict 5-stage pipeline design:
| Stage | Name              | Components                          |
|-------|-------------------|-------------------------------------|
| IF    | Instruction Fetch | Program Counter, Instruction Memory |
| ID    | Instruction Decode| Control Unit, Register File, Imm Gen|
| EX    | Execute           | ALU, Forwarding Mux                 |
| MEM   | Memory Access     | MMIO Controller, Data Memory (SRAM) |
| WB    | Write Back        | Writeback Mux (ALU/Mem/MMIO)        |

The CPU supports the base `RV32I` integer instruction set and implements sophisticated hazard handling:
- **Data forwarding** from EX/MEM and MEM/WB stages to EX stage
- **Load-use hazard detection** with pipeline stall (1-cycle bubble)
- **NOP insertion** via IF/ID and ID/EX flush

---

### CNN Accelerator Subsystem

The accelerator implements a full **LeNet-5** inference pipeline, sequenced by a multi-layer FSM controller. It features an **AXI4 Master** interface for high-speed DMA data fetching and an **AXI4-Lite Slave** interface for robust register control. The entire datapath is optimized for Power, Performance, and Area (PPA), utilizing **Operand Isolation** and **Clock Gating** to minimize dynamic power consumption.

```text
┌──────────────────────────────────────────────────────────┐
│                   system_top.v                            │
│  ┌────────────────────────────────────────────────────┐  │
│  │              riscv_core_top.v                      │  │
│  │  5-Stage Pipeline (IF → ID → EX → MEM → WB)       │  │
│  └──────────────────────┬─────────────────────────────┘  │
│                         │ MMIO Bus (addr ≥ 0x1000)        │
│  ┌──────────────────────▼─────────────────────────────┐  │
│  │           edge_ai_cnn_peripheral.v                  │  │
│  │                                                     │  │
│  │  ┌──────────────────────────────────────────────┐  │  │
│  │  │  cnn_register_interface (17 MMIO Registers)  │  │  │
│  │  └──────────────────┬───────────────────────────┘  │  │
│  │  ┌──────────────────▼───────────────────────────┐  │  │
│  │  │  cnn_controller (Multi-Layer FSM)            │  │  │
│  │  │  DMA_LOAD → CONV1 → CONV2 → FC → DONE       │  │  │
│  │  └───┬──────────┬──────────┬──────────┬─────────┘  │  │
│  │      │          │          │          │             │  │
│  │  ┌───▼──┐  ┌────▼───┐  ┌──▼────┐  ┌──▼─────┐      │  │
│  │  │ DMA  │  │Layer 1 │  │Layer 2│  │  FC    │      │  │
│  │  │Engine│  │Conv    │  │Conv   │  │ Layer  │      │  │
│  │  │      │  │ReLU    │  │ReLU   │  │(Dense) │      │  │
│  │  │      │  │MaxPool │  │MaxPool│  │        │      │  │
│  │  └──────┘  └────┬───┘  └──┬────┘  └────────┘      │  │
│  │                 │  INT8   │                         │  │
│  │            ┌────▼───┐ ┌──▼────┐                    │  │
│  │            │Inter FM│ │FC Buf │                    │  │
│  │            │ SRAM   │ │ SRAM  │                    │  │
│  │            └────────┘ └───────┘                    │  │
│  └─────────────────────────────────────────────────────┘  │
└──────────────────────────────────────────────────────────┘
```

#### Multi-Layer Controller FSM

The `cnn_controller` orchestrates the full inference pipeline:
1. **DMA_LOAD**: Burst-transfer image data from external memory into local SRAM
2. **CONV1**: Trigger Layer 1 pipeline (Conv3D → ReLU → MaxPool 2×2)
3. **CONV2**: Trigger Layer 2 pipeline on intermediate feature maps
4. **FC**: Run fully connected classification layer
5. **DONE**: Assert completion flag to RISC-V core

#### MMIO Register Map

The processor communicates with the accelerator through standard memory load (`lw`) and store (`sw`) instructions:

| Offset | Register | Description |
|--------|----------|-------------|
| `0x00` | CONTROL | START/DONE status |
| `0x04–0x0C` | Addresses | Image, weight, feature map base addresses |
| `0x10–0x20` | Layer 1 Config | Width, height, channels, kernel, filters |
| `0x24–0x30` | DMA Config | Source, destination, length, start |
| `0x34–0x38` | Layer 2 Config | Channels, filters |
| `0x3C–0x40` | FC Config | Input count, output classes |

#### Hardware Datapath

![CNN Datapath Architecture](../diagrams/pipeline_datapath_diagram.png)

Each convolution layer pipeline (`cnn_layer_pipeline.v`) internally chains:

1. **Line Buffers (BRAM):** Cache two full rows (up to 2048px) to produce a valid 3×3 window every clock cycle.
2. **Sliding Window:** Shifts a 3×3 frame spatially, generating 9 pixels simultaneously.
3. **Pipelined MAC Array:** 9 parallel hardware multipliers compute the 3×3 dot product. The multipliers are pipelined for high frequency (Fmax) and feature **Operand Isolation** to drastically reduce switching power when idle.
4. **Channel Accumulator:** Sums partial results across depth channels (e.g., RGB).
5. **ReLU:** Combinational activation — clamps negative values to zero.
6. **Max Pool 2×2:** Streaming pooling that halves spatial dimensions.

Between layers, INT8 quantization converts 32-bit accumulator outputs back to 8-bit for the next layer's input, matching industry-standard quantized inference (Google Edge TPU, Apple Neural Engine).

The **FC Layer** reads the flattened pool output, multiplies against weight memory, accumulates with bias, and produces final class scores.
