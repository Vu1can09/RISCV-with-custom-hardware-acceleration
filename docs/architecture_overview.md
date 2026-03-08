# Architecture Overview

## RISC-V RV32I 5-Stage Pipeline Processor with Convolution Accelerator

### System Architecture

The system comprises a simplified RV32I processor core implementing the classic **5-stage pipeline** architecture, extended with a **custom convolution accelerator** for Edge AI workloads.

```
┌─────────────────────────────────────────────────────────────────────┐
│                        RISC-V Core Top                              │
│                                                                     │
│  ┌──────┐   ┌──────┐   ┌──────┐   ┌──────┐   ┌──────┐             │
│  │  IF   │──▶│  ID   │──▶│  EX   │──▶│  MEM  │──▶│  WB   │         │
│  │      │   │      │   │      │   │      │   │      │             │
│  │ PC   │   │ Ctrl │   │ ALU  │   │ Data │   │ Mux  │             │
│  │ IMEM │   │ RegF │   │ Fwd  │   │ Mem  │   │      │             │
│  └──────┘   └──────┘   └──┬───┘   └──────┘   └──────┘             │
│                            │                                        │
│                     ┌──────▼──────┐                                 │
│                     │ Convolution │                                  │
│                     │ Accelerator │                                  │
│                     │ (MAC Unit)  │                                  │
│                     └─────────────┘                                 │
│                                                                     │
│  Forwarding: EX/MEM → EX, MEM/WB → EX                              │
│  Hazard:     Load-use stall + NOP insertion                         │
└─────────────────────────────────────────────────────────────────────┘
```

### Pipeline Stages

| Stage | Name              | Components                          |
|-------|-------------------|-------------------------------------|
| IF    | Instruction Fetch | Program Counter, Instruction Memory |
| ID    | Instruction Decode| Control Unit, Register File, Imm Gen|
| EX    | Execute           | ALU, Forwarding Mux, Accelerator    |
| MEM   | Memory Access     | Data Memory (Read/Write)            |
| WB    | Write Back        | Writeback Mux (ALU/Mem/Accel)       |

### Pipeline Registers

- **IF/ID**: Latches PC and instruction. Supports stall and flush.
- **ID/EX**: Carries control signals, register data, immediate, rd address.
- **EX/MEM**: Carries ALU result, write data, accelerator result.
- **MEM/WB**: Carries memory data, ALU result, accelerator result.

### Supported Instructions

| Type   | Instruction | Opcode    | funct3 | funct7    |
|--------|-------------|-----------|--------|-----------|
| R-type | ADD         | 0110011   | 000    | 0000000   |
| R-type | SUB         | 0110011   | 000    | 0100000   |
| R-type | AND         | 0110011   | 111    | 0000000   |
| R-type | OR          | 0110011   | 110    | 0000000   |
| I-type | ADDI        | 0010011   | 000    | —         |
| Custom | CONV        | 0001011   | 000    | —         |

### Hazard Handling

- **Data forwarding** from EX/MEM and MEM/WB stages to EX stage
- **Load-use hazard detection** with pipeline stall (1-cycle bubble)
- **NOP insertion** via IF/ID and ID/EX flush

### Convolution Accelerator

The accelerator performs a **3×3 dot product** using an FSM-driven MAC unit:

1. **IDLE**: Waiting for start signal (triggered by custom instruction)
2. **COMPUTE**: Iterates through 9 elements, computing `acc += input[i] * kernel[i]`
3. **DONE**: Outputs result back into the pipeline's writeback path

The result is written to the destination register specified in the custom instruction.

### Custom Instruction Format

```
[31:25]  [24:20] [19:15] [14:12] [11:7]  [6:0]
0000000  00000   00000   000     rd      0001011
```

Opcode `0001011` triggers the convolution accelerator. The result is written to register `rd`.
