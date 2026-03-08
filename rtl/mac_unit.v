//============================================================================
// Module: MAC Unit (Multiply-Accumulate)
// Description: Single-cycle multiply-accumulate unit.
//              acc = acc + (a * b) when enabled.
//              Clears accumulator on clear signal.
//============================================================================

module mac_unit (
    input  wire        clk,
    input  wire        reset,
    input  wire        clear,       // Clear accumulator
    input  wire        enable,      // Enable MAC operation
    input  wire [7:0]  operand_a,   // 8-bit input (pixel value)
    input  wire [7:0]  operand_b,   // 8-bit input (kernel weight)
    output reg  [31:0] accumulator  // 32-bit accumulated result
);

    wire [15:0] product;
    assign product = operand_a * operand_b;

    always @(posedge clk or posedge reset) begin
        if (reset || clear) begin
            accumulator <= 32'd0;
        end else if (enable) begin
            accumulator <= accumulator + {16'd0, product};
        end
    end

endmodule
