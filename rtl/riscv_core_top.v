//============================================================================
// Module: RISC-V Core Top (riscv_core_top)
// Description: Top-level integration of the 5-stage pipelined RV32I processor
//              with convolution accelerator and AXI DMA Master.
//
// Pipeline Stages:
//   IF  -> IF/ID -> ID  -> ID/EX -> EX  -> EX/MEM -> MEM -> MEM/WB -> WB
//
// Features:
//   - Basic data hazard detection
//   - Convolution accelerator integrated as MMIO peripheral
//   - AXI4 Master interface for external memory (DDR) access
//============================================================================

module riscv_core_top (
    input  wire        clk,
    input  wire        reset,

    // ---- AXI4 Master Interface (from internal CNN) ----
    output wire [31:0] M_AXI_AWADDR,
    output wire [7:0]  M_AXI_AWLEN,
    output wire [2:0]  M_AXI_AWSIZE,
    output wire [1:0]  M_AXI_AWBURST,
    output wire        M_AXI_AWVALID,
    input  wire        M_AXI_AWREADY,
    output wire [31:0] M_AXI_WDATA,
    output wire [3:0]  M_AXI_WSTRB,
    output wire        M_AXI_WLAST,
    output wire        M_AXI_WVALID,
    input  wire        M_AXI_WREADY,
    input  wire [1:0]  M_AXI_BRESP,
    input  wire        M_AXI_BVALID,
    output wire        M_AXI_BREADY,
    output wire [31:0] M_AXI_ARADDR,
    output wire [7:0]  M_AXI_ARLEN,
    output wire [2:0]  M_AXI_ARSIZE,
    output wire [1:0]  M_AXI_ARBURST,
    output wire        M_AXI_ARVALID,
    input  wire        M_AXI_ARREADY,
    input  wire [31:0] M_AXI_RDATA,
    input  wire [1:0]  M_AXI_RRESP,
    input  wire        M_AXI_RLAST,
    input  wire        M_AXI_RVALID,
    output wire        M_AXI_RREADY,

    output wire        system_done
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

    // ---- ID/EX Pipeline Register outputs ----
    wire        idex_reg_write;
    wire        idex_alu_src;
    wire [3:0]  idex_alu_ctrl;
    wire        idex_mem_read;
    wire        idex_mem_write;
    wire [1:0]  idex_mem_to_reg;
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

    // ---- EX/MEM Pipeline Register outputs ----
    wire        exmem_reg_write;
    wire        exmem_mem_read;
    wire        exmem_mem_write;
    wire [1:0]  exmem_mem_to_reg;
    wire [31:0] exmem_alu_result;
    wire [31:0] exmem_rs2_data;
    wire [4:0]  exmem_rd_addr;

    // ---- MEM Stage ----
    wire [31:0] mem_read_data;

    // ---- MEM/WB Pipeline Register outputs ----
    wire        memwb_reg_write;
    wire [1:0]  memwb_mem_to_reg;
    wire [31:0] memwb_mem_data;
    wire [31:0] memwb_alu_result;
    wire [4:0]  memwb_rd_addr;

    // ---- WB Stage ----
    reg  [31:0] wb_write_data;

    // ---- Hazard Detection ----
    wire        stall;
    wire        id_flush;
    wire        load_use_stall;

    //==========================================================================
    // Instruction Field Extraction (ID Stage)
    //==========================================================================
    assign id_opcode   = ifid_instruction[6:0];
    assign id_rd       = ifid_instruction[11:7];
    assign id_funct3   = ifid_instruction[14:12];
    assign id_rs1_addr = ifid_instruction[19:15];
    assign id_rs2_addr = ifid_instruction[24:20];
    assign id_funct7   = ifid_instruction[31:25];

    assign id_immediate = {{20{ifid_instruction[31]}}, ifid_instruction[31:20]};

    assign load_use_stall = idex_mem_read &&
                   ((idex_rd_addr == id_rs1_addr) || (idex_rd_addr == id_rs2_addr)) &&
                   (idex_rd_addr != 5'd0);
    assign stall = load_use_stall;
    assign id_flush = load_use_stall;

    //==========================================================================
    // Data Forwarding Unit
    //==========================================================================
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
    // Stage 1: IF
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
    // Stage 2: ID
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
        .mem_to_reg  (id_mem_to_reg)
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

    pipeline_register_id_ex u_idex (
        .clk             (clk),
        .reset           (reset),
        .stall           (1'b0),
        .flush           (id_flush),
        .reg_write_in    (id_reg_write),
        .alu_src_in      (id_alu_src),
        .alu_ctrl_in     (id_alu_ctrl),
        .mem_read_in     (id_mem_read),
        .mem_write_in    (id_mem_write),
        .mem_to_reg_in   (id_mem_to_reg),
        .pc_in           (ifid_pc),
        .rs1_data_in     (id_rs1_data),
        .rs2_data_in     (id_rs2_data),
        .immediate_in    (id_immediate),
        .rd_addr_in      (id_rd),
        .rs1_addr_in     (id_rs1_addr),
        .rs2_addr_in     (id_rs2_addr),
        .reg_write_out   (idex_reg_write),
        .alu_src_out     (idex_alu_src),
        .alu_ctrl_out    (idex_alu_ctrl),
        .mem_read_out    (idex_mem_read),
        .mem_write_out   (idex_mem_write),
        .mem_to_reg_out  (idex_mem_to_reg),
        .pc_out          (idex_pc),
        .rs1_data_out    (idex_rs1_data),
        .rs2_data_out    (idex_rs2_data),
        .immediate_out   (idex_immediate),
        .rd_addr_out     (idex_rd_addr),
        .rs1_addr_out    (idex_rs1_addr),
        .rs2_addr_out    (idex_rs2_addr)
    );

    //==========================================================================
    // Stage 3: EX
    //==========================================================================
    assign ex_alu_operand_b = idex_alu_src ? idex_immediate : ex_forwarded_rs2;

    alu u_alu (
        .operand_a  (ex_forwarded_rs1),
        .operand_b  (ex_alu_operand_b),
        .alu_ctrl   (idex_alu_ctrl),
        .alu_result (ex_alu_result),
        .zero_flag  (ex_zero_flag)
    );

    pipeline_register_ex_mem u_exmem (
        .clk              (clk),
        .reset            (reset),
        .stall            (1'b0),
        .reg_write_in     (idex_reg_write),
        .mem_read_in      (idex_mem_read),
        .mem_write_in     (idex_mem_write),
        .mem_to_reg_in    (idex_mem_to_reg),
        .alu_result_in    (ex_alu_result),
        .rs2_data_in      (ex_forwarded_rs2),
        .rd_addr_in       (idex_rd_addr),
        .reg_write_out    (exmem_reg_write),
        .mem_read_out     (exmem_mem_read),
        .mem_write_out    (exmem_mem_write),
        .mem_to_reg_out   (exmem_mem_to_reg),
        .alu_result_out   (exmem_alu_result),
        .rs2_data_out     (exmem_rs2_data),
        .rd_addr_out      (exmem_rd_addr)
    );

    //==========================================================================
    // Stage 4: MEM
    //==========================================================================
    reg [31:0] data_memory [0:255];

    wire is_cnn_addr  = (exmem_alu_result >= 32'h0000_1000) && (exmem_alu_result < 32'h0004_0000);
    wire is_dmem_addr = (exmem_alu_result <  32'h0000_0400);

    wire [31:0] dmem_read_data = (exmem_mem_read && is_dmem_addr) ? data_memory[exmem_alu_result[9:2]] : 32'd0;
    wire [31:0] cnn_read_data;
    
    assign mem_read_data = is_cnn_addr ? cnn_read_data : dmem_read_data;

    always @(posedge clk) begin
        if (exmem_mem_write && is_dmem_addr) begin
            data_memory[exmem_alu_result[9:2]] <= exmem_rs2_data;
        end
    end

    //==========================================================================
    // CNN Peripheral Integration with AXI Master Ports
    //==========================================================================
    wire cnn_done;
    wire cnn_bus_ren = exmem_mem_read && is_cnn_addr;

    edge_ai_cnn_peripheral u_cnn_accel (
        .clk      (clk),
        .rst_n    (~reset),
        .bus_we   (exmem_mem_write && is_cnn_addr),
        .bus_ren  (cnn_bus_ren),
        .bus_addr (exmem_alu_result - 32'h0000_1000),
        .bus_din  (exmem_rs2_data),
        .bus_dout (cnn_read_data),
        
        .M_AXI_AWADDR (M_AXI_AWADDR), .M_AXI_AWLEN  (M_AXI_AWLEN),  .M_AXI_AWSIZE (M_AXI_AWSIZE), 
        .M_AXI_AWBURST(M_AXI_AWBURST),.M_AXI_AWVALID(M_AXI_AWVALID),.M_AXI_AWREADY(M_AXI_AWREADY),
        .M_AXI_WDATA  (M_AXI_WDATA),  .M_AXI_WSTRB  (M_AXI_WSTRB),  .M_AXI_WLAST  (M_AXI_WLAST),
        .M_AXI_WVALID (M_AXI_WVALID), .M_AXI_WREADY (M_AXI_WREADY),
        .M_AXI_BRESP  (M_AXI_BRESP),  .M_AXI_BVALID (M_AXI_BVALID), .M_AXI_BREADY (M_AXI_BREADY),
        .M_AXI_ARADDR (M_AXI_ARADDR), .M_AXI_ARLEN  (M_AXI_ARLEN),  .M_AXI_ARSIZE (M_AXI_ARSIZE),
        .M_AXI_ARBURST(M_AXI_ARBURST),.M_AXI_ARVALID(M_AXI_ARVALID),.M_AXI_ARREADY(M_AXI_ARREADY),
        .M_AXI_RDATA  (M_AXI_RDATA),  .M_AXI_RRESP  (M_AXI_RRESP),  .M_AXI_RLAST  (M_AXI_RLAST),
        .M_AXI_RVALID (M_AXI_RVALID), .M_AXI_RREADY (M_AXI_RREADY),
        
        .cnn_done (cnn_done)
    );

    assign system_done = cnn_done;

    //==========================================================================
    // Stage 5: WB
    //==========================================================================
    pipeline_register_mem_wb u_memwb (
        .clk              (clk),
        .reset            (reset),
        .reg_write_in     (exmem_reg_write),
        .mem_to_reg_in    (exmem_mem_to_reg),
        .mem_data_in      (mem_read_data),
        .alu_result_in    (exmem_alu_result),
        .rd_addr_in       (exmem_rd_addr),
        .reg_write_out    (memwb_reg_write),
        .mem_to_reg_out   (memwb_mem_to_reg),
        .mem_data_out     (memwb_mem_data),
        .alu_result_out   (memwb_alu_result),
        .rd_addr_out      (memwb_rd_addr)
    );

    always @(*) begin
        case (memwb_mem_to_reg)
            2'b00:   wb_write_data = memwb_alu_result;
            2'b01:   wb_write_data = memwb_mem_data;
            default: wb_write_data = memwb_alu_result;
        endcase
    end

endmodule
