# Verification Plan

## Overview
The verification logic ensures mathematical correctness before synthesizing the datapath. The environment utilizes standard Verilog testbenches. Python serves as the behavioral ground-truth generator.

### 1. Module-Level Verification
- **MAC Array (`mac_array_tb.v`)**: Tests combinational multiply-accumulate arithmetic logic on 3x3 sliding windows. Ensures no overflow and correct bit-widths.
- **Line Buffer (`line_buffer.v`)**: BRAM shift-register behavior verified manually inside the system and datapath simulations.

### 2. Subsystem Verification
- **3D Convolution Accelerator (`conv3d_accelerator_tb.v`)**: Validates the sequential logic of streaming image data, packing sliding windows, utilizing the MAC, and properly tracking the internal channel accumulator loop execution. Test benches force constant 1s into the inputs to verify the accumulated expected constant values.

### 3. State & Control Verification
- **CNN Controller FSM (`cnn_controller_tb.v`)**: Examines states `IDLE -> LOAD_WINDOW -> MULTIPLY -> ACCUMULATE -> WRITE_OUTPUT`.

### 4. Integration & Firmware Validation
- **RISC-V Control (`riscv_control_tb.v`)**: Ensures the pseudo-processor executes the register writes.
- **Top System (`system_integration_tb.v`)**: End-to-end dataflow.

### 5. Python Reference
- `cnn_reference_model.py`: Runs an unoptimized generic 3D N-channel mathematical convolution loop locally using NumPy to cross-validate constants. Run using `python3 cnn_reference_model.py`.
