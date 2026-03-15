`timescale 1ns / 1ps

// -----------------------------------------------------------------------------
// Fully Connected (Dense) Layer
//
// Sequentially reads input features and weights, multiplies, and accumulates
// to produce output class scores. Operates as a streaming MAC engine.
//
// Operation:
//   For each output neuron j:
//     score[j] = SUM_i ( input[i] * weight[j][i] ) + bias[j]
//
// Interface:
//   - Input feature values are streamed in one per clock via `feature_in`
//   - Weights are provided synchronously via `weight_in`
//   - Bias is added at the end of each neuron accumulation
//   - Output scores are emitted one per neuron via `score_out`
// -----------------------------------------------------------------------------

module fc_layer #(
    parameter FEATURE_WIDTH = 8,       // Input feature precision
    parameter WEIGHT_WIDTH  = 8,       // Weight precision
    parameter ACC_WIDTH     = 32,      // Accumulator precision
    parameter MAX_INPUTS    = 576,     // Max flattened input size (e.g. 6x6x16)
    parameter MAX_OUTPUTS   = 10       // Max number of output classes/neurons
)(
    input  wire                           clk,
    input  wire                           rst_n,

    // Control
    input  wire                           start,
    input  wire [15:0]                    num_inputs,    // Actual input count
    input  wire [7:0]                     num_outputs,   // Actual output count

    // Streaming input features (from flattened pool2 output buffer)
    input  wire signed [FEATURE_WIDTH-1:0] feature_in,
    input  wire                           feature_valid,

    // Weight memory interface (external RAM read port)
    output reg  [15:0]                    weight_addr,   // Address into weight memory
    input  wire signed [WEIGHT_WIDTH-1:0] weight_in,

    // Bias input (one per output neuron)
    input  wire signed [ACC_WIDTH-1:0]    bias_in,

    // Output
    output reg  signed [ACC_WIDTH-1:0]    score_out,
    output reg                            score_valid,
    output reg                            done
);

    // FSM States
    localparam IDLE       = 2'd0;
    localparam COMPUTE    = 2'd1;
    localparam OUTPUT     = 2'd2;
    localparam DONE_STATE = 2'd3;

    reg [1:0]  state;
    reg signed [ACC_WIDTH-1:0] accumulator;
    reg [15:0] input_idx;      // Current input feature index
    reg [7:0]  output_idx;     // Current output neuron index

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state       <= IDLE;
            accumulator <= 0;
            input_idx   <= 0;
            output_idx  <= 0;
            weight_addr <= 0;
            score_out   <= 0;
            score_valid <= 0;
            done        <= 0;
        end else begin
            score_valid <= 1'b0;  // Default

            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        state       <= COMPUTE;
                        accumulator <= 0;
                        input_idx   <= 0;
                        output_idx  <= 0;
                        weight_addr <= 0;
                    end
                end

                COMPUTE: begin
                    if (feature_valid) begin
                        // MAC: accumulate feature * weight
                        accumulator <= accumulator +
                            ({{(ACC_WIDTH-FEATURE_WIDTH){feature_in[FEATURE_WIDTH-1]}}, feature_in} *
                             {{(ACC_WIDTH-WEIGHT_WIDTH){weight_in[WEIGHT_WIDTH-1]}}, weight_in});

                        weight_addr <= weight_addr + 1;
                        input_idx   <= input_idx + 1;

                        if (input_idx == num_inputs - 1) begin
                            state <= OUTPUT;
                        end
                    end
                end

                OUTPUT: begin
                    // Emit accumulated score + bias for this neuron
                    score_out   <= accumulator + bias_in;
                    score_valid <= 1'b1;

                    // Prepare for next neuron
                    accumulator <= 0;
                    input_idx   <= 0;
                    output_idx  <= output_idx + 1;

                    if (output_idx == num_outputs - 1) begin
                        state <= DONE_STATE;
                    end else begin
                        state <= COMPUTE;
                    end
                end

                DONE_STATE: begin
                    done  <= 1'b1;
                    state <= IDLE;
                end
            endcase
        end
    end

endmodule
