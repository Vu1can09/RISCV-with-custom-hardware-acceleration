# Processor-Controlled CNN Convolution Accelerator for Edge AI

## 1. Abstract
This project proposes a hardware-efficient Convolutional Neural Network (CNN) Accelerator optimized for Edge AI applications. As deep learning models push the boundaries of computational demand, running CNNs strictly on general-purpose CPUs becomes inefficient in both power and performance. Our architecture resolves this limitation by introducing a custom feature map processing pipeline explicitly managed by a RISC-V processor over a Memory-Mapped I/O (MMIO) bus. The design utilizes purely digital RTL modules, enabling a streamlined architecture that clearly demonstrates feature map processing, sliding window mechanics, parallel MAC arrays, and local memory caching hierarchies.

## 2. Introduction
Edge AI refers to deploying artificial intelligence algorithms locally on "edge" hardware devices natively, rather than relying on cloud computing. For computer vision tasks, CNNs are the predominant algorithm. However, executing CNNs requires immense parallel computations, specifically convolutions. General-purpose CPUs implement these via serial Multiply-Accumulate (MAC) loops, making real-time processing challenging under strict clock budgets. A dedicated hardware accelerator utilizes spatial computation (like parallel MAC arrays and line buffers) to significantly increase throughput and reduce latency, enabling complex Edge AI vision applications.

## 3. Problem Statement
The primary limitations of standard software-based CPU CNN evaluation are poor localized memory reuse and sequential arithmetic limits. While single accelerator units exist, they often require complex central data movement per layer. Developing a decoupled hardware accelerator with an integrated Control FSM tightly coupled with a processor memory bus attempts to solve these bottlenecks by handling memory propagation natively, eliminating the need to stall processor software extensively over system busses.

## 4. Proposed Architecture
The proposed architecture features a localized multi-stage hardware pipeline commanded by processor-writable registers. It processes multidimensional arrays incrementally. A central `cnn_controller` acts as the "Traffic Cop," managing internal data movement and accelerator scheduling. Inside the datapath, a `line_buffer` generator seamlessly catches image segments to maintain a constant stream of 3x3 pixel windows without reloading redundant data from main memory.

## 5. System Architecture
At a high level, the processor delegates a CNN workload by programming sizes, kernel weight paths, and triggering the accelerator.

**Data Flow Pipeline:**
`RISC-V Host -> MMIO Bus -> CNN Controller -> Memory Buffers -> 3D Conv Datapath`

Inside the acceleration phase:
1. Input pixels stream from local SRAM into the **Line Buffers**.
2. The Line Buffers spit out a 3x3 receptive window every single clock cycle.
3. The **MAC Array** natively computes the multiplication mathematics against the requested Kernels.
4. An iterative **Channel Accumulator** loops over deep dimensions (like RGB or deep feature layers) and aggregates the partial sums.
5. The processed pixel is written back out via the MMIO memory bridge.

## 6. RTL Design
We designed the architecture hierarchically through distinct component Verilog modules:

- **`riscv_core_top`** & **`system_top`**: The integration wrappers bounding the processor MMIO interface together with the CNN hardware elements.
- **`cnn_controller`**: Validates configuration, handles the overarching state machine (IDLE, MEM_LOAD, COMPUTE, WRITE_OUT), and routes signals to the datapath.
- **`conv3d_accelerator`**: Top-level computation wrapper for a single convolution stage. 
- **`mac_array`**: Represents spatial computation; combinatorially computes 9 multiplications and sums the outputs in parallel for a 3x3 kernel.
- **`line_buffer`**: Caches overlapping rows such that a new 3x3 valid window is generated per clock cycle sequentially.

## 7. Simulation & Verification
RTL verification was managed via completely automated scripts relying on **Icarus Verilog (`iverilog`)** and **GTKWave**. We cleanly test:
1. **FSM Operation**: Polling register verification confirms transitioning from IDLE to processing when the system START register is pulsed.
2. **Mathematical Correctness**: A Python verification subsystem utilizes NumPy to generate identically shaped multidimensional arrays, proving that the hardware datapath identically replicates the mathematics defined by the Python reference model.
3. **Data Movement**: Top-level System Integration Testbenches force stimuli down the MMIO data buses, mimicking real firmware C-code executing down across the wires.

## 8. Applications
The proposed modular CNN framework acts as a foundational IP struct. It can be widely applied to:
- **Computer Vision**: Live video object detection bounds checking, facial recognition processing locally without cloud latency.
- **Signal Processing**: 1D and 2D signal denoising mapping.
- **Autonomous Systems**: Real-time edge inference for small robotic navigation control loops.

## 9. Conclusion
This project successfully designed and proved a high-speed, processor-controlled Convolution Accelerator subsystem. By decoupling the hardware arithmetic logic into discrete functional chunks—namely MAC arrays, Channel Accumulators, and Line-Buffer Sliding Windows—we demonstrated clear comprehension of spatial computer architecture scaling. Deploying a dedicated traffic controller with memory-mapped interfaces allows for effective, high-throughput hardware-software co-design implementations without physically stalling the primary CPU.
