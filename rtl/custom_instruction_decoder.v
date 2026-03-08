//============================================================================
// Module: Custom Instruction Decoder
// Description: Detects the custom opcode (0001011) and generates the
//              accelerator start signal. Routes accelerator result back
//              into the pipeline's EX stage ALU result mux.
//============================================================================

module custom_instruction_decoder (
    input  wire [6:0]  opcode,
    input  wire        accel_done,      // Accelerator done signal
    input  wire [31:0] accel_result,    // Result from accelerator
    output wire        accel_start,     // Trigger accelerator
    output wire        is_custom_instr, // Flag: this is a custom instruction
    output wire [31:0] custom_result    // Result to feed into pipeline
);

    // Custom opcode for convolution accelerator
    localparam OP_CUSTOM = 7'b0001011;

    // Detect custom instruction
    assign is_custom_instr = (opcode == OP_CUSTOM);

    // Generate start signal when custom opcode is decoded
    assign accel_start = is_custom_instr;

    // Route accelerator result when done
    assign custom_result = accel_done ? accel_result : 32'd0;

endmodule
