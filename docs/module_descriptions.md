# Module Descriptions

Detailed signal-level descriptions for each RTL module in the RISC-V 5-stage pipeline processor.

---

## pc.v — Program Counter

Increments by 4 each cycle. Holds current value when pipeline is stalled.

| Signal   | Direction | Width | Description                     |
|----------|-----------|-------|---------------------------------|
| clk      | Input     | 1     | System clock                    |
| reset    | Input     | 1     | Synchronous reset (active high) |
| stall    | Input     | 1     | Pipeline stall signal           |
| pc_out   | Output    | 32    | Current program counter value   |

---

## instruction_memory.v — Instruction Memory

ROM loaded from `sim/instructions.mem`. Word-addressed (byte addr >> 2).

| Signal      | Direction | Width | Description           |
|-------------|-----------|-------|-----------------------|
| addr        | Input     | 32    | Byte address          |
| instruction | Output    | 32    | Fetched instruction   |

---

## register_file.v — Register File

32×32-bit register file. x0 hardwired to zero.

| Signal   | Direction | Width | Description                     |
|----------|-----------|-------|---------------------------------|
| clk      | Input     | 1     | System clock                    |
| reset    | Input     | 1     | Reset (clears all regs)         |
| rs1_addr | Input     | 5     | Source register 1 address       |
| rs2_addr | Input     | 5     | Source register 2 address       |
| rs1_data | Output    | 32    | Source register 1 data          |
| rs2_data | Output    | 32    | Source register 2 data          |
| wr_en    | Input     | 1     | Write enable                    |
| rd_addr  | Input     | 5     | Destination register address    |
| rd_data  | Input     | 32    | Write-back data                 |

---

## alu.v — ALU

4-operation ALU with zero flag.

| Signal     | Direction | Width | Description           |
|------------|-----------|-------|-----------------------|
| operand_a  | Input     | 32    | First operand         |
| operand_b  | Input     | 32    | Second operand        |
| alu_ctrl   | Input     | 4     | Operation selector    |
| alu_result | Output    | 32    | Computation result    |
| zero_flag  | Output    | 1     | Result == 0           |

ALU operations: `0000`=ADD, `0001`=SUB, `0010`=AND, `0011`=OR.

---

## control_unit.v — Control Unit

Decodes opcode and generates pipeline control signals.

| Signal      | Direction | Width | Description                        |
|-------------|-----------|-------|------------------------------------|
| opcode      | Input     | 7     | Instruction opcode field           |
| funct3      | Input     | 3     | Function code 3                    |
| funct7      | Input     | 7     | Function code 7                    |
| reg_write   | Output    | 1     | Register write enable              |
| alu_src     | Output    | 1     | ALU source (0=rs2, 1=imm)         |
| alu_ctrl    | Output    | 4     | ALU operation                      |
| mem_read    | Output    | 1     | Memory read enable                 |
| mem_write   | Output    | 1     | Memory write enable                |
| mem_to_reg  | Output    | 2     | WB source (00=ALU, 01=mem, 10=acc) |
| accel_start | Output    | 1     | Start convolution accelerator      |

---

## Pipeline Register Modules

### pipeline_register_if_id.v

| Signal          | Direction | Width | Description                |
|-----------------|-----------|-------|----------------------------|
| stall           | Input     | 1     | Hold values                |
| flush           | Input     | 1     | Insert NOP bubble          |
| pc_in/out       | I/O       | 32    | Program counter            |
| instruction_in/out | I/O    | 32    | Instruction word           |

### pipeline_register_id_ex.v

Passes all control signals + register data + immediate + addresses.

### pipeline_register_ex_mem.v

Passes ALU result + write data + accelerator result + control signals.

### pipeline_register_mem_wb.v

Passes memory data + ALU result + accelerator result for writeback mux.

---

## mac_unit.v — Multiply-Accumulate Unit

Single-cycle MAC: `acc += a × b`.

| Signal      | Direction | Width | Description                |
|-------------|-----------|-------|----------------------------|
| clk         | Input     | 1     | System clock               |
| reset       | Input     | 1     | Reset accumulator          |
| clear       | Input     | 1     | Clear accumulator to 0     |
| enable      | Input     | 1     | Enable MAC operation       |
| operand_a   | Input     | 8     | Input value (pixel)        |
| operand_b   | Input     | 8     | Kernel weight              |
| accumulator | Output    | 32    | Accumulated result         |

---

## convolution_accelerator.v — Convolution Engine

FSM-driven 3×3 convolution using MAC unit.

| Signal | Direction | Width | Description                    |
|--------|-----------|-------|--------------------------------|
| clk    | Input     | 1     | System clock                   |
| reset  | Input     | 1     | Reset FSM and buffers          |
| start  | Input     | 1     | Begin convolution              |
| done   | Output    | 1     | Computation complete           |
| result | Output    | 32    | Final convolution dot product  |

FSM states: IDLE (00) → COMPUTE (01) → DONE (10) → IDLE.

---

## custom_instruction_decoder.v — Custom Instruction Decoder

Detects opcode `0001011` and generates accelerator control.

| Signal          | Direction | Width | Description                |
|-----------------|-----------|-------|----------------------------|
| opcode          | Input     | 7     | Instruction opcode         |
| accel_done      | Input     | 1     | Accelerator done flag      |
| accel_result    | Input     | 32    | Accelerator output         |
| accel_start     | Output    | 1     | Trigger accelerator        |
| is_custom_instr | Output    | 1     | Custom instruction flag    |
| custom_result   | Output    | 32    | Result for pipeline        |

---

## riscv_core_top.v — Top-Level Integration

Wires all pipeline stages, registers, forwarding, hazard detection, and accelerator.

**Key features:**
- **Data forwarding** from EX/MEM and MEM/WB to EX-stage operands
- **Load-use hazard** stall: inserts 1-cycle bubble when EX-stage load destination matches ID-stage source
- **Embedded data memory** (256 words) for MEM stage
- **Debug monitor** printing register writes during simulation
