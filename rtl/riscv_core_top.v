//============================================================================
// Module: RISC-V Core Top (riscv_core_top)
// Description: Top-level integration of the 5-stage pipelined RV32I processor
//              with convolution accelerator.
//
// Pipeline Stages:
//   IF  -> IF/ID -> ID  -> ID/EX -> EX  -> EX/MEM -> MEM -> MEM/WB -> WB
//
// Features:
//   - Basic data hazard detection (stall on load-use)
//   - NOP insertion on stall
//   - Convolution accelerator integrated at EX stage
//   - Data forwarding from EX/MEM and MEM/WB stages
//============================================================================

module riscv_core_top (
    input  wire        clk,
    input  wire        reset
);

    //==========================================================================
    // Internal signals
    //==========================================================================

    // ---- IF Stage ----
    wire [31:0] pc_current;
    wire [31:0] instruction_fetched;

    // ---- IF/ID Pipeline Register outputs ----
    wire [31:0] ifid_pc;
    wire [31:0] ifid_instruction;

    // ---- ID Stage (decode) ----
    wire [6:0]  id_opcode;
    wire [4:0]  id_rd;
    wire [2:0]  id_funct3;
    wire [4:0]  id_rs1_addr;
    wire [4:0]  id_rs2_addr;
    wire [6:0]  id_funct7;
    wire [31:0] id_immediate;
    wire [31:0] id_rs1_data;
    wire [31:0] id_rs2_data;

    // Control signals from control unit
    wire        id_reg_write;
    wire        id_alu_src;
    wire [3:0]  id_alu_ctrl;
    wire        id_mem_read;
    wire        id_mem_write;
    wire [1:0]  id_mem_to_reg;
    wire        id_accel_start;

    // ---- ID/EX Pipeline Register outputs ----
    wire        idex_reg_write;
    wire        idex_alu_src;
    wire [3:0]  idex_alu_ctrl;
    wire        idex_mem_read;
    wire        idex_mem_write;
    wire [1:0]  idex_mem_to_reg;
    wire        idex_accel_start;
    wire [31:0] idex_pc;
    wire [31:0] idex_rs1_data;
    wire [31:0] idex_rs2_data;
    wire [31:0] idex_immediate;
    wire [4:0]  idex_rd_addr;
    wire [4:0]  idex_rs1_addr;
    wire [4:0]  idex_rs2_addr;

    // ---- EX Stage ----
    wire [31:0] ex_alu_operand_b;
    wire [31:0] ex_alu_result;
    wire        ex_zero_flag;
    wire [31:0] ex_forwarded_rs1;
    wire [31:0] ex_forwarded_rs2;

    // Accelerator signals
    wire        accel_done;
    wire        accel_busy;
    wire [31:0] accel_result;

    // ---- EX/MEM Pipeline Register outputs ----
    wire        exmem_reg_write;
    wire        exmem_mem_read;
    wire        exmem_mem_write;
    wire [1:0]  exmem_mem_to_reg;
    wire [31:0] exmem_alu_result;
    wire [31:0] exmem_rs2_data;
    wire [4:0]  exmem_rd_addr;
    wire [31:0] exmem_accel_result;

    // ---- MEM Stage ----
    wire [31:0] mem_read_data;

    // ---- MEM/WB Pipeline Register outputs ----
    wire        memwb_reg_write;
    wire [1:0]  memwb_mem_to_reg;
    wire [31:0] memwb_mem_data;
    wire [31:0] memwb_alu_result;
    wire [4:0]  memwb_rd_addr;
    wire [31:0] memwb_accel_result;

    // ---- WB Stage ----
    reg  [31:0] wb_write_data;

    // ---- Hazard Detection ----
    wire        stall;
    wire        id_flush;
    wire        load_use_stall;
    wire        accel_stall;

    //==========================================================================
    // Instruction Field Extraction (ID Stage)
    //==========================================================================
    assign id_opcode   = ifid_instruction[6:0];
    assign id_rd       = ifid_instruction[11:7];
    assign id_funct3   = ifid_instruction[14:12];
    assign id_rs1_addr = ifid_instruction[19:15];
    assign id_rs2_addr = ifid_instruction[24:20];
    assign id_funct7   = ifid_instruction[31:25];

    // Immediate generation (I-type sign extension)
    assign id_immediate = {{20{ifid_instruction[31]}}, ifid_instruction[31:20]};

    // Stall on load-use hazard: if the instruction in EX stage is a load
    // and the destination register matches a source in ID stage
    // Stall on load-use hazard OR accelerator busy
    assign load_use_stall = idex_mem_read &&
                   ((idex_rd_addr == id_rs1_addr) || (idex_rd_addr == id_rs2_addr)) &&
                   (idex_rd_addr != 5'd0);
    assign accel_stall = accel_busy;
    assign stall = load_use_stall || accel_stall;

    // Only flush ID/EX on load-use stall (insert bubble)
    // Don't flush on accelerator stall (keep custom instruction in ID/EX)
    assign id_flush = load_use_stall && !accel_stall;

    //==========================================================================
    // Data Forwarding Unit
    //==========================================================================
    // Forward from EX/MEM stage
    // Forward from MEM/WB stage
    assign ex_forwarded_rs1 =
        (exmem_reg_write && (exmem_rd_addr != 5'd0) && (exmem_rd_addr == idex_rs1_addr))
            ? exmem_alu_result :
        (memwb_reg_write && (memwb_rd_addr != 5'd0) && (memwb_rd_addr == idex_rs1_addr))
            ? wb_write_data :
        idex_rs1_data;

    assign ex_forwarded_rs2 =
        (exmem_reg_write && (exmem_rd_addr != 5'd0) && (exmem_rd_addr == idex_rs2_addr))
            ? exmem_alu_result :
        (memwb_reg_write && (memwb_rd_addr != 5'd0) && (memwb_rd_addr == idex_rs2_addr))
            ? wb_write_data :
        idex_rs2_data;

    //==========================================================================
    // Stage 1: Instruction Fetch (IF)
    //==========================================================================
    pc u_pc (
        .clk    (clk),
        .reset  (reset),
        .stall  (stall),
        .pc_out (pc_current)
    );

    instruction_memory u_imem (
        .addr        (pc_current),
        .instruction (instruction_fetched)
    );

    //==========================================================================
    // Pipeline Register: IF/ID
    //==========================================================================
    pipeline_register_if_id u_ifid (
        .clk             (clk),
        .reset           (reset),
        .stall           (stall),
        .flush           (1'b0),
        .pc_in           (pc_current),
        .instruction_in  (instruction_fetched),
        .pc_out          (ifid_pc),
        .instruction_out (ifid_instruction)
    );

    //==========================================================================
    // Stage 2: Instruction Decode (ID)
    //==========================================================================
    control_unit u_ctrl (
        .opcode      (id_opcode),
        .funct3      (id_funct3),
        .funct7      (id_funct7),
        .reg_write   (id_reg_write),
        .alu_src     (id_alu_src),
        .alu_ctrl    (id_alu_ctrl),
        .mem_read    (id_mem_read),
        .mem_write   (id_mem_write),
        .mem_to_reg  (id_mem_to_reg),
        .accel_start (id_accel_start)
    );

    register_file u_regfile (
        .clk       (clk),
        .reset     (reset),
        .rs1_addr  (id_rs1_addr),
        .rs2_addr  (id_rs2_addr),
        .rs1_data  (id_rs1_data),
        .rs2_data  (id_rs2_data),
        .wr_en     (memwb_reg_write),
        .rd_addr   (memwb_rd_addr),
        .rd_data   (wb_write_data)
    );

    //==========================================================================
    // Pipeline Register: ID/EX
    //==========================================================================
    pipeline_register_id_ex u_idex (
        .clk             (clk),
        .reset           (reset),
        .stall           (accel_stall),
        .flush           (id_flush),
        // Control in
        .reg_write_in    (id_reg_write),
        .alu_src_in      (id_alu_src),
        .alu_ctrl_in     (id_alu_ctrl),
        .mem_read_in     (id_mem_read),
        .mem_write_in    (id_mem_write),
        .mem_to_reg_in   (id_mem_to_reg),
        .accel_start_in  (id_accel_start),
        // Data in
        .pc_in           (ifid_pc),
        .rs1_data_in     (id_rs1_data),
        .rs2_data_in     (id_rs2_data),
        .immediate_in    (id_immediate),
        .rd_addr_in      (id_rd),
        .rs1_addr_in     (id_rs1_addr),
        .rs2_addr_in     (id_rs2_addr),
        // Control out
        .reg_write_out   (idex_reg_write),
        .alu_src_out     (idex_alu_src),
        .alu_ctrl_out    (idex_alu_ctrl),
        .mem_read_out    (idex_mem_read),
        .mem_write_out   (idex_mem_write),
        .mem_to_reg_out  (idex_mem_to_reg),
        .accel_start_out (idex_accel_start),
        // Data out
        .pc_out          (idex_pc),
        .rs1_data_out    (idex_rs1_data),
        .rs2_data_out    (idex_rs2_data),
        .immediate_out   (idex_immediate),
        .rd_addr_out     (idex_rd_addr),
        .rs1_addr_out    (idex_rs1_addr),
        .rs2_addr_out    (idex_rs2_addr)
    );

    //==========================================================================
    // Stage 3: Execute (EX)
    //==========================================================================

    // ALU operand B mux: rs2 forwarded data or immediate
    assign ex_alu_operand_b = idex_alu_src ? idex_immediate : ex_forwarded_rs2;

    alu u_alu (
        .operand_a  (ex_forwarded_rs1),
        .operand_b  (ex_alu_operand_b),
        .alu_ctrl   (idex_alu_ctrl),
        .alu_result (ex_alu_result),
        .zero_flag  (ex_zero_flag)
    );

    // Convolution Accelerator
    convolution_accelerator u_conv_accel (
        .clk    (clk),
        .reset  (reset),
        .start  (idex_accel_start),
        .done   (accel_done),
        .busy   (accel_busy),
        .result (accel_result)
    );

    //==========================================================================
    // Pipeline Register: EX/MEM
    //==========================================================================
    pipeline_register_ex_mem u_exmem (
        .clk              (clk),
        .reset            (reset),
        .stall            (accel_stall),
        // Control in
        .reg_write_in     (idex_reg_write),
        .mem_read_in      (idex_mem_read),
        .mem_write_in     (idex_mem_write),
        .mem_to_reg_in    (idex_mem_to_reg),
        // Data in
        .alu_result_in    (ex_alu_result),
        .rs2_data_in      (ex_forwarded_rs2),
        .rd_addr_in       (idex_rd_addr),
        .accel_result_in  (accel_result),
        // Control out
        .reg_write_out    (exmem_reg_write),
        .mem_read_out     (exmem_mem_read),
        .mem_write_out    (exmem_mem_write),
        .mem_to_reg_out   (exmem_mem_to_reg),
        // Data out
        .alu_result_out   (exmem_alu_result),
        .rs2_data_out     (exmem_rs2_data),
        .rd_addr_out      (exmem_rd_addr),
        .accel_result_out (exmem_accel_result)
    );

    //==========================================================================
    // Stage 4: Memory Access (MEM)
    //==========================================================================
    // Simple data memory (256 words)
    reg [31:0] data_memory [0:255];

    // Memory read
    assign mem_read_data = exmem_mem_read ? data_memory[exmem_alu_result[9:2]] : 32'd0;

    // Memory write
    always @(posedge clk) begin
        if (exmem_mem_write) begin
            data_memory[exmem_alu_result[9:2]] <= exmem_rs2_data;
        end
    end

    //==========================================================================
    // Pipeline Register: MEM/WB
    //==========================================================================
    pipeline_register_mem_wb u_memwb (
        .clk              (clk),
        .reset            (reset),
        // Control in
        .reg_write_in     (exmem_reg_write),
        .mem_to_reg_in    (exmem_mem_to_reg),
        // Data in
        .mem_data_in      (mem_read_data),
        .alu_result_in    (exmem_alu_result),
        .rd_addr_in       (exmem_rd_addr),
        .accel_result_in  (exmem_accel_result),
        // Control out
        .reg_write_out    (memwb_reg_write),
        .mem_to_reg_out   (memwb_mem_to_reg),
        // Data out
        .mem_data_out     (memwb_mem_data),
        .alu_result_out   (memwb_alu_result),
        .rd_addr_out      (memwb_rd_addr),
        .accel_result_out (memwb_accel_result)
    );

    //==========================================================================
    // Stage 5: Write Back (WB)
    //==========================================================================
    always @(*) begin
        case (memwb_mem_to_reg)
            2'b00:   wb_write_data = memwb_alu_result;    // From ALU
            2'b01:   wb_write_data = memwb_mem_data;      // From memory
            2'b10:   wb_write_data = memwb_accel_result;  // From accelerator
            default: wb_write_data = memwb_alu_result;
        endcase
    end

    //==========================================================================
    // Debug: Monitor register writes (for simulation)
    //==========================================================================
    /*always @(posedge clk) begin
        if (memwb_reg_write && (memwb_rd_addr != 5'd0)) begin
            $display("TIME=%0t | WB: x%0d = 0x%08h",
                    $time, memwb_rd_addr, wb_write_data);
      end
    end*/

endmodule
