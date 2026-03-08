#!/usr/bin/env python3
"""
Convolution Reference Model
============================
NumPy-based 2D convolution reference implementation.
Demonstrates sliding-window 3x3 convolution on a 5x5 input matrix.

Used to generate golden reference outputs for validating the
Verilog convolution accelerator.
"""

import numpy as np


def convolve2d(input_matrix: np.ndarray, kernel: np.ndarray) -> np.ndarray:
    """
    Perform 2D convolution (valid mode) of input_matrix with kernel.

    Args:
        input_matrix: 2D array of shape (H, W)
        kernel:       2D array of shape (kH, kW)

    Returns:
        output: 2D array of shape (H - kH + 1, W - kW + 1)
    """
    kh, kw = kernel.shape
    h, w = input_matrix.shape
    out_h = h - kh + 1
    out_w = w - kw + 1

    output = np.zeros((out_h, out_w), dtype=np.int64)

    for i in range(out_h):
        for j in range(out_w):
            window = input_matrix[i:i + kh, j:j + kw]
            output[i, j] = np.sum(window * kernel)

    return output


def main():
    print("=" * 50)
    print(" Convolution Reference Model")
    print("=" * 50)
    print()

    # Example 1: Fixed values matching the Verilog accelerator
    print("--- Example 1: Fixed (matches Verilog accelerator) ---")
    input_window = np.array([
        [1, 2, 3],
        [4, 5, 6],
        [7, 8, 9]
    ], dtype=np.int64)

    kernel = np.array([
        [1, 0, 1],
        [0, 1, 0],
        [1, 0, 1]
    ], dtype=np.int64)

    # Single window dot product (what the accelerator computes)
    result = np.sum(input_window * kernel)
    print(f"Input window:\n{input_window}")
    print(f"Kernel:\n{kernel}")
    print(f"Dot product (accelerator result): {result}")
    print(f"Expected: 1*1 + 3*1 + 5*1 + 7*1 + 9*1 = 25")
    print()

    # Example 2: Full 5x5 convolution with 3x3 kernel
    print("--- Example 2: Full 5x5 Convolution ---")
    input_5x5 = np.array([
        [1, 2, 3, 4, 5],
        [6, 7, 8, 9, 10],
        [1, 2, 3, 4, 5],
        [6, 7, 8, 9, 10],
        [1, 2, 3, 4, 5]
    ], dtype=np.int64)

    kernel_3x3 = np.array([
        [1, 0, -1],
        [1, 0, -1],
        [1, 0, -1]
    ], dtype=np.int64)

    output = convolve2d(input_5x5, kernel_3x3)
    print(f"Input (5x5):\n{input_5x5}")
    print(f"Kernel (3x3):\n{kernel_3x3}")
    print(f"Output (3x3):\n{output}")
    print()

    # Example 3: Random inputs
    print("--- Example 3: Random Inputs ---")
    np.random.seed(42)
    rand_input = np.random.randint(0, 10, (5, 5))
    rand_kernel = np.random.randint(0, 5, (3, 3))
    rand_output = convolve2d(rand_input, rand_kernel)

    print(f"Random Input (5x5):\n{rand_input}")
    print(f"Random Kernel (3x3):\n{rand_kernel}")
    print(f"Convolution Output (3x3):\n{rand_output}")
    print()


if __name__ == "__main__":
    main()
