# Processor-Controlled CNN Convolution Accelerator for Edge AI on FPGA

## 1. Abstract
This project proposes a hardware-efficient Processor-Controlled CNN Convolution Accelerator optimized for Edge AI applications on Field Programmable Gate Arrays (FPGAs). As deep learning models push the boundaries of computational demand, running Convolutional Neural Networks (CNNs) strictly on general-purpose CPUs becomes inefficient in both power and performance. Our architecture resolves this limitation by introducing a custom multi-layer CNN acceleration pipeline explicitly managed by a processor. The design is restricted to an optimal set of 8 RTL modules, enabling a streamlined architecture that fits within a standard semester project timeframe while clearly demonstrating feature map processing, sliding window mechanics, parallel MAC arrays, and local memory hierarchies.

## 2. Introduction
Edge AI refers to deploying artificial intelligence algorithms locally on "edge" hardware devices natively, rather than relying on cloud computing. For computer vision tasks, CNNs are the predominant algorithm. However, executing CNNs requires immense parallel computations, specifically convolutions. General-purpose CPUs implement these via serial Multiply-Accumulate (MAC) loops, making real-time processing challenging under strict power budgets. A dedicated hardware accelerator utilizes spatial computation (like parallel MAC arrays and line buffers) to significantly increase throughput and reduce latency, enabling complex Edge AI vision applications.

## 3. Problem Statement
The primary limitations of standard software-based CPU CNN evaluation are poor localized memory reuse and sequential arithmetic limits. While single accelerator units exist, they often require complex central data movement per layer. Developing a multi-layer accelerator with integrated FSM scheduling tightly coupled with a processor register map attempts to solve these bottlenecks by handling intermediate layer propagation inherently, eliminating the need to stall processor software extensively over PCIe or system busses. 

## 4. Proposed Architecture
The proposed architecture features a localized multi-stage hardware pipeline commanded by processor-writable registers. It includes three layers of convolution, each fed incrementally by the output of the prior layer through dedicated feature map RAMs. A CNN Controller acts as the "brain," managing internal data movement and accelerator scheduling. A sliding window generator seamlessly buffers image segments to maintain a constant stream of 3x3 pixel ROIs (Regions of Interest) without reloading redundant data from main memory.

## 5. System Architecture
At a high level, the processor delegates a CNN workload by programming size, kernel configuration, and triggering the accelerator.

**Data Flow Pipeline:**
Processor -> CNN Controller -> Conv Accelerator 1 -> Conv Accelerator 2 -> Conv Accelerator 3

Inside the acceleration phase:
1. Input pixels stream into **Conv Accelerator 1**.
2. The generated feature map streams automatically into intermediate **Feature Map RAM**.
3. **Conv Accelerator 2** fetches from this RAM and computes its outputs, feeding the next layer.
4. **Conv Accelerator 3** generates the final resulting classifications or downsampled maps.

## 6. RTL Design
We designed the architecture explicitly limiting the complexity to 8 core modules:

- **cnn_controller**: Validates configuration, handles the overarching state machine (IDLE, CONFIG, RUN_L1, RUN_L2, RUN_L3), and routes startup/done signals to the respective conv units.
- **conv_accelerator**: Top-level computation wrapper for a single layer. Manages local FSM scheduling coordinates MACs with the sliding window stream.
- **mac_array**: Represents spatial computation; combinatorially computes 9 multiplications and sums the outputs in parallel for a 3x3 kernel.
- **sliding_window**: A specialized line buffer architecture. For an 8x8 input stream, caches overlapping rows such that a new 3x3 valid window is generated per clock cycle sequentially.
- **feature_map_ram**: Dual-port memory acting as high-bandwidth local caching for bounding layer output matrices.
- **weight_ram**: ROM/RAM blocks maintaining kernel geometries for inference operations.
- **cnn_register_interface**: The memory-mapped processor frontend exposing offsets for configuration (e.g. Dimensions, Start trigger, Done polling).
- **edge_ai_cnn_top**: The integration wrapper bounding the processor interface together with the CNN hardware elements.

## 7. FPGA Implementation
The intended workflow utilizes standard HDL synthesis via Vivado or physical implementation depending on the target system (e.g. Xilinx Artix-7/Zynq). The primary usage footprint lies within DSP slices (utilized predominantly by the MAC arrays) and Block RAMs (for feature maps and weight tables). Synthesis goals should balance maximum frequency against resource packing density by employing pipelining registers between MAC summation trees if Fmax goals are not met.

## 8. Simulation Results
RTL verification was managed via Verilator / ModelSim workflows through `edge_ai_cnn_top_tb.v`. We correctly observe: 
1. **FSM Operation**: Polling register verification confirms transitioning from IDLE to processing when START is asserted.
2. **Convolution Correctness**: The mac array accurately computes sliding window dot products across static weights.
3. **Data Movement**: Verification tracks successful pipelining wherein Conv 1 enables Conv 2 organically upon completion logic.

## 9. Applications
The proposed modular CNN framework acts as an IP base structure. It can be widely applied to:
- **Computer Vision**: Live video object detection bounds checking, facial recognition processing locally without cloud latency.
- **Signal Processing**: 1D and 2D signal denoising mapping.
- **Autonomous Systems**: Real-time edge inference for small robotic navigation control loops.

## 10. Conclusion
This semester project has successfully designed and proven a multi-layered processor-controlled Convolution Accelerator. By restricting the framework to 8 distinct Verilog modules, we demonstrated clear comprehension of spatial computation optimizations—namely MAC arrays and Line-Buffer Sliding Windows. Deploying a dedicated controller with memory-mapped interfaces allows for effective, high-throughput hardware-software co-design on modern FPGA platforms, opening pathways into low-power Edge AI applications.
