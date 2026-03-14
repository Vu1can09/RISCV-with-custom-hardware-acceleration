`timescale 1ns / 1ps

module cnn_controller (
    input clk,
    input rst_n,
    
    // Processor Interface
    input start,
    input [31:0] processor_config,
    output reg done,
    
    // Accelerator status
    input conv1_done,
    input conv2_done,
    input conv3_done,
    
    // Accelerator control
    output reg conv1_start,
    output reg conv2_start,
    output reg conv3_start
);

    // FSM States
    localparam ST_IDLE         = 3'd0;
    localparam ST_LOAD_CONFIG  = 3'd1;
    localparam ST_RUN_CONV1    = 3'd2;
    localparam ST_RUN_CONV2    = 3'd3;
    localparam ST_RUN_CONV3    = 3'd4;
    localparam ST_WRITE_OUTPUT = 3'd5;
    localparam ST_DONE         = 3'd6;

    reg [2:0] state, next_state;

    // FSM State Register
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= ST_IDLE;
        end else begin
            state <= next_state;
        end
    end

    // FSM Next State Logic
    always @(*) begin
        next_state = state;
        case (state)
            ST_IDLE: begin
                if (start)
                    next_state = ST_LOAD_CONFIG;
            end
            ST_LOAD_CONFIG: begin
                // In a full implementation, config loading takes time. 
                // We'll advance immediately for this simplified model.
                next_state = ST_RUN_CONV1;
            end
            ST_RUN_CONV1: begin
                if (conv1_done)
                    next_state = ST_RUN_CONV2;
            end
            ST_RUN_CONV2: begin
                if (conv2_done)
                    next_state = ST_RUN_CONV3;
            end
            ST_RUN_CONV3: begin
                if (conv3_done)
                    next_state = ST_WRITE_OUTPUT;
            end
            ST_WRITE_OUTPUT: begin
                // Output writing simulates sending data back to memory
                next_state = ST_DONE;
            end
            ST_DONE: begin
                if (start)
                    next_state = ST_LOAD_CONFIG; 
            end
            default: next_state = ST_IDLE;
        endcase
    end

    // FSM Output Logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            conv1_start <= 1'b0;
            conv2_start <= 1'b0;
            conv3_start <= 1'b0;
            done        <= 1'b0;
        end else begin
            // Defaults
            conv1_start <= 1'b0;
            conv2_start <= 1'b0;
            conv3_start <= 1'b0;
            done        <= 1'b0;
            
            case (next_state)
                ST_RUN_CONV1: if (state != ST_RUN_CONV1) conv1_start <= 1'b1;
                ST_RUN_CONV2: if (state != ST_RUN_CONV2) conv2_start <= 1'b1;
                ST_RUN_CONV3: if (state != ST_RUN_CONV3) conv3_start <= 1'b1;
                ST_DONE:      done <= 1'b1;
            endcase
        end
    end

endmodule
