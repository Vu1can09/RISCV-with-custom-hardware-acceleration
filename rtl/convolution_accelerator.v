//============================================================================
// Module: Convolution Accelerator
// Description: 3x3 convolution engine with internal kernel and input buffers.
//              Uses a MAC unit to perform multiply-accumulate over a 3x3 window.
//              FSM: IDLE -> COMPUTE -> DONE
//
//              The accelerator holds a fixed 3x3 kernel and a 3x3 input window.
//              These are preloaded at reset for demonstration purposes.
//              On receiving 'start', it computes the dot product of the two
//              3x3 matrices and outputs the result.
//============================================================================

module convolution_accelerator (
    input  wire        clk,
    input  wire        reset,
    input  wire        start,           // Start convolution computation
    output reg         done,            // Computation complete
    output wire        busy,            // Accelerator is computing
    output reg  [31:0] result           // Convolution result
);

    // FSM states
    localparam IDLE    = 2'b00;
    localparam COMPUTE = 2'b01;
    localparam DONE_ST = 2'b10;

    reg [1:0] state, next_state;

    // 3x3 kernel buffer (flattened, 8-bit values)
    reg [7:0] kernel [0:8];

    // 3x3 input window buffer (flattened, 8-bit values)
    reg [7:0] input_window [0:8];

    // MAC unit connections
    reg        mac_clear;
    reg        mac_enable;
    reg  [7:0] mac_a;
    reg  [7:0] mac_b;
    wire [31:0] mac_acc;

    // Element counter (0-8 for 3x3 = 9 elements)
    reg [3:0] elem_count;

    // Edge detection for start signal
    reg start_prev;
    wire start_pulse;
    always @(posedge clk or posedge reset) begin
        if (reset)
            start_prev <= 1'b0;
        else
            start_prev <= start;
    end
    assign start_pulse = start && !start_prev;

    // Instantiate MAC unit
    mac_unit u_mac (
        .clk         (clk),
        .reset       (reset),
        .clear       (mac_clear),
        .enable      (mac_enable),
        .operand_a   (mac_a),
        .operand_b   (mac_b),
        .accumulator (mac_acc)
    );

    // Initialize kernel and input window with fixed test values
    integer i;
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            // Sample kernel: [[1,0,1],[0,1,0],[1,0,1]]
            kernel[0] <= 8'd1; kernel[1] <= 8'd0; kernel[2] <= 8'd1;
            kernel[3] <= 8'd0; kernel[4] <= 8'd1; kernel[5] <= 8'd0;
            kernel[6] <= 8'd1; kernel[7] <= 8'd0; kernel[8] <= 8'd1;

            // Sample input window: [[1,2,3],[4,5,6],[7,8,9]]
            input_window[0] <= 8'd1; input_window[1] <= 8'd2; input_window[2] <= 8'd3;
            input_window[3] <= 8'd4; input_window[4] <= 8'd5; input_window[5] <= 8'd6;
            input_window[6] <= 8'd7; input_window[7] <= 8'd8; input_window[8] <= 8'd9;
        end
    end

    // FSM state register
    always @(posedge clk or posedge reset) begin
        if (reset)
            state <= IDLE;
        else
            state <= next_state;
    end

    // FSM next-state logic
    always @(*) begin
        next_state = state;
        case (state)
            IDLE: begin
                if (start_pulse)
                    next_state = COMPUTE;
            end
            COMPUTE: begin
                if (elem_count == 4'd9)
                    next_state = DONE_ST;
            end
            DONE_ST: begin
                next_state = IDLE;
            end
            default: next_state = IDLE;
        endcase
    end

    // Busy when computing or outputting result (pipeline should stall)
    // Include start_pulse so busy asserts immediately in the same cycle
    // the custom instruction enters EX stage (prevents it from advancing)
    assign busy = start_pulse || (state == COMPUTE) || (state == DONE_ST);

    // FSM output and datapath logic
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            elem_count <= 4'd0;
            mac_clear  <= 1'b0;
            mac_enable <= 1'b0;
            mac_a      <= 8'd0;
            mac_b      <= 8'd0;
            done       <= 1'b0;
            result     <= 32'd0;
        end else begin
            case (state)
                IDLE: begin
                    done       <= 1'b0;
                    mac_enable <= 1'b0;
                    elem_count <= 4'd0;
                    if (start_pulse) begin
                        mac_clear <= 1'b1; // Clear accumulator before starting
                    end else begin
                        mac_clear <= 1'b0;
                    end
                end

                COMPUTE: begin
                    mac_clear <= 1'b0;
                    if (elem_count < 4'd9) begin
                        mac_enable <= 1'b1;
                        mac_a      <= input_window[elem_count];
                        mac_b      <= kernel[elem_count];
                        elem_count <= elem_count + 4'd1;
                    end else begin
                        mac_enable <= 1'b0;
                    end
                end

                DONE_ST: begin
                    done   <= 1'b1;
                    result <= mac_acc;
                end

                default: begin
                    mac_enable <= 1'b0;
                end
            endcase
        end
    end

endmodule
