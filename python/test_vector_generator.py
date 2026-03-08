#!/usr/bin/env python3
"""
Test Vector Generator
=====================
Generates random input matrices and kernel weights, computes expected
convolution outputs, and exports hex test vectors for Verilog $readmemh.

Output files:
  - sim/test_input.mem    : Flattened input matrix (hex, 8-bit per line)
  - sim/test_kernel.mem   : Flattened kernel matrix (hex, 8-bit per line)
  - sim/test_expected.mem : Expected output values (hex, 32-bit per line)
"""

import numpy as np
import os


def convolve2d(input_matrix: np.ndarray, kernel: np.ndarray) -> np.ndarray:
    """2D convolution (valid mode)."""
    kh, kw = kernel.shape
    h, w = input_matrix.shape
    out_h = h - kh + 1
    out_w = w - kw + 1

    output = np.zeros((out_h, out_w), dtype=np.int64)
    for i in range(out_h):
        for j in range(out_w):
            output[i, j] = np.sum(input_matrix[i:i + kh, j:j + kw] * kernel)
    return output


def to_hex_8bit(value: int) -> str:
    """Convert integer to 2-digit hex string (unsigned 8-bit)."""
    return f"{value & 0xFF:02X}"


def to_hex_32bit(value: int) -> str:
    """Convert integer to 8-digit hex string (unsigned 32-bit)."""
    return f"{value & 0xFFFFFFFF:08X}"


def main():
    # Ensure sim directory exists
    sim_dir = os.path.join(os.path.dirname(os.path.dirname(__file__)), "sim")
    os.makedirs(sim_dir, exist_ok=True)

    print("=" * 50)
    print(" Test Vector Generator")
    print("=" * 50)
    print()

    # Generate test data
    np.random.seed(42)
    input_size = 5
    kernel_size = 3

    input_matrix = np.random.randint(0, 10, (input_size, input_size)).astype(np.int64)
    kernel = np.random.randint(0, 5, (kernel_size, kernel_size)).astype(np.int64)
    expected_output = convolve2d(input_matrix, kernel)

    print(f"Input Matrix ({input_size}x{input_size}):")
    print(input_matrix)
    print()
    print(f"Kernel ({kernel_size}x{kernel_size}):")
    print(kernel)
    print()
    print(f"Expected Output ({expected_output.shape[0]}x{expected_output.shape[1]}):")
    print(expected_output)
    print()

    # Export input matrix
    input_path = os.path.join(sim_dir, "test_input.mem")
    with open(input_path, "w") as f:
        f.write(f"// Input matrix ({input_size}x{input_size}), 8-bit hex values\n")
        for row in input_matrix:
            for val in row:
                f.write(to_hex_8bit(int(val)) + "\n")
    print(f"Written: {input_path}")

    # Export kernel
    kernel_path = os.path.join(sim_dir, "test_kernel.mem")
    with open(kernel_path, "w") as f:
        f.write(f"// Kernel ({kernel_size}x{kernel_size}), 8-bit hex values\n")
        for row in kernel:
            for val in row:
                f.write(to_hex_8bit(int(val)) + "\n")
    print(f"Written: {kernel_path}")

    # Export expected output
    expected_path = os.path.join(sim_dir, "test_expected.mem")
    with open(expected_path, "w") as f:
        f.write(f"// Expected convolution output, 32-bit hex values\n")
        for row in expected_output:
            for val in row:
                f.write(to_hex_32bit(int(val)) + "\n")
    print(f"Written: {expected_path}")

    print()
    print("Test vectors generated successfully!")


if __name__ == "__main__":
    main()
