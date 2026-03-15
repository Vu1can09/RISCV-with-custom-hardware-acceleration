# FPGA / ASIC Implementation Flow

## Setup & Compatibility
This RTL relies entirely on synthesizable Verilog 2001 constructs. There are no ambiguous initial blocks used in the standard modules (only in testbenches), and resets are handled via active-low `rst_n` asynchronous clears. Memory is inferred utilizing basic array structures which both Quartus and Vivado map cleanly to native M20K / Block-RAM memory primitives. The `system_top.v` module exposes only `clk`, `reset`, and `done` — ideal for both FPGA and ASIC synthesis flows.

## Xilinx Vivado Synthesis
1. Create a Vivado RTL project targeting your board.
2. Copy all files from `rtl/` into your `Design Sources`. 
3. Select `system_top.v` as `Top Module`.
4. Run `Synthesis → Implementation → Generate Bitstream`.

## Yosys / OpenLane (ASIC Flow)
1. Use `system_top.v` as the top module.
2. Read all RTL files: `read_verilog rtl/*.v`
3. Run synthesis: `synth -top system_top`
4. Map to your target library: `dfflibmap` / `abc`
5. Write netlist: `write_verilog synth/system_top_netlist.v`

## Common Constraints
- You will need a standard `clk` definition in your XDC/SDC file (`create_clock -period 10.0 [get_ports clk]`).
- The `reset` pin should be constrained to a physical button or POR circuit.
- The `done` output can be mapped to an LED for visual confirmation.

## Resource Estimation

### DSP Blocks
- **MAC Array**: Each `mac_array` infers 9 DSP blocks (8×8→16-bit multiplies). With 2 layer pipelines, expect **18 DSP blocks** total.
- **FC Layer**: The FC MAC uses a single DSP for sequential accumulation.

### Block RAM (BRAM)
- **Feature Map RAM** (×3 instances): Each 64KB → ~32 BRAM18 blocks per instance.
- **Weight RAM**: Minimal — 4 × 72-bit entries.
- **Line Buffers** (×2 instances): 2048 × 8-bit × 2 FIFOs per layer = ~8 BRAM18 blocks per layer.
- **Max Pool Line Buffers** (×2 instances): 1024 × 32-bit per layer.

### LUT / Register Usage
- **ReLU**: ~32 LUTs (pure combinational mux)
- **Max Pool**: ~200 LUTs (comparators + counters)
- **DMA Controller**: ~150 LUTs (FSM + address pointers)
- **CNN Controller**: ~100 LUTs (multi-layer FSM)
- **RISC-V Core**: ~3000–5000 LUTs (full 5-stage pipeline)

## Potential Bottlenecks
- **Multiplier logic**: The `mac_array` will infer DSP blocks. Large multi-instantiation scaling requires analyzing DSP utilization vs LUT-based inferences.
- **Line Buffer BRAM**: The `MAX_IMAGE_WIDTH` parameter is set to 2048. If targeting smaller FPGAs, reduce this to prevent routing congestion.
- **Intermediate SRAM**: Three 64KB feature map RAMs dominate BRAM usage. On smaller FPGAs, reduce `ADDR_WIDTH` parameters accordingly.
- **FC Weight Memory**: For production, connect the FC layer's `weight_in` and `bias_in` to dedicated BRAM storing pre-trained model parameters.
