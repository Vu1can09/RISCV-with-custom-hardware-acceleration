# Module Description

## LeNet-5 Inference Pipeline

```text
Input Image → Conv1 → ReLU → Pool → Conv2 → ReLU → Pool → FC → Class Scores
```

Each convolution layer is encapsulated in `cnn_layer_pipeline.v`:
```text
pixel_in → [line_buffer → sliding_window → mac_array → channel_accumulator] → ReLU → MaxPool → pixel_out
```

---

## Datapath Components

1. **`mac_array.v`**: The core math unit. 9 pipelined multipliers computing `a[i] * w[i]` followed by an adder tree accumulating them into a single product.
2. **`line_buffer.v`**: Dual BRAM-inferred FIFOs maintaining historical row vectors. Supports up to 2048px wide images.
3. **`sliding_window.v`**: Receives 3 column vectors every clock, shifts previous variables right, and exposes a flattened vector of 9 simultaneous spatial variables to the MAC Array.
4. **`channel_accumulator.v`**: Maintains a running tally of intermediate MAC array outputs. Asserts `clear` at the completion of spatial tensor boundaries.
5. **`relu.v`**: Combinational ReLU activation. Clamps negative signed values to zero with zero latency.
6. **`max_pool_2x2.v`**: Streaming 2×2 max pooling with internal line buffer. Halves spatial dimensions (width and height).
7. **`fc_layer.v`**: Sequential MAC fully connected layer. Reads flattened features and weights, multiplies/accumulates, produces output class scores.

## Control and Wrappers

1. **`cnn_layer_pipeline.v`**: Reusable single-layer wrapper chaining `conv3d_accelerator → relu → max_pool_2x2`.
2. **`conv3d_accelerator.v`**: The wrapper that organizes `line_buffer`, `sliding_window`, `mac_array`, and `channel_accumulator` into an uninterrupted flow of data.
3. **`cnn_controller.v`**: Multi-layer FSM sequencing `DMA_LOAD → CONV1 → CONV2 → FC → DONE`. Also retains legacy single-layer states for backward compatibility.
4. **`cnn_register_interface.v`**: Extended MMIO address map with 17 registers covering image config, DMA, Layer 2, and FC parameters.
5. **`dma_controller.v`**: Burst DMA engine for CPU-free memory transfers between external memory and local CNN SRAM.
6. **`riscv_core_top.v`**: 5-stage pipelined RISC-V soft-core driving instruction sequences and memory-mapped reads/writes to the CNN.
7. **`system_top.v`**: The primary ASIC/FPGA synthesis wrapper tying the processor and CNN datapath to top-level pins.

## Memory Models
- **`feature_map_ram.v`**: 64KB dual-port SRAM for image data and intermediate feature maps (instantiated 3× for Layer 1 input, inter-layer buffer, and FC input buffer).
- **`image_buffer.v`**: 4KB image staging buffer.
- **`weight_ram.v`**: 72-bit wide dual-port SRAM for 3×3 kernel weights (9 × 8-bit).
