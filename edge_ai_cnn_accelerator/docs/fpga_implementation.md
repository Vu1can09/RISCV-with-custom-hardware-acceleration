# FPGA Implementation Flow

## Setup & Compatibility
This RTL relies entirely on synthesizable Verilog 2001 / SystemVerilog constructs.
There are no ambiguous initial blocks used in the standard modules (only in testbenches), and resets are handled natively via active-low `rst_n` synchronous and asynchronous clears. Memory is inferred utilizing basic array structures which both Quartus and Vivado map cleanly to native M20K / Block-RAM memory primitives. 

## Xilinx Vivado Synthesis
1. Create a Vivado RTL targeting your board.
2. Copy `rtl/` into your `Design Sources`. 
3. Select `edge_ai_cnn_top.v` as `Top Module`.
4. Run `Synthesis -> Implementation -> Generate Bitstream`.

## Common Constraints
- You will need a standard `clk` definition in your XDC/SDC file (`create_clock -period 10.0 [get_ports clk]`).
- The processor IO must be bound if not integrated.

## Potential Bottlenecks for Implementation
- **Multiplier logic**: The `mac_array` will infer 9 DSP blocks (since it compiles 8x8->16 multiplies). Large multi-instantiation scaling requires analyzing DSP utilization vs LUT based inferences.
- **Line Buffer BRAM**: Adjust the `MAX_IMAGE_WIDTH` properly. Extensive definitions will cause routing congestion if it spills to distributed FF networks rather than clean BRAM arrays.
