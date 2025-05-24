// CoprocessorControlUnit (CCU) Module Stub
// Date: 2024-03-14

`timescale 1ns / 1ps

module CoprocessorControlUnit (
    // AXI4-Lite Slave Interface (for CPU commands/status)
    input  wire         s_axi_aclk,
    input  wire         s_axi_aresetn,
    // Add specific AXI signals used by CCU for register access
    // For example:
    input  wire [31:0]  s_axi_awaddr, // For write address
    input  wire         s_axi_awvalid,
    output wire         s_axi_awready,
    input  wire [31:0]  s_axi_wdata,   // For write data
    input  wire         s_axi_wvalid,
    output wire         s_axi_wready,
    input  wire [31:0]  s_axi_araddr, // For read address
    input  wire         s_axi_arvalid,
    output wire         s_axi_arready,
    output wire [31:0]  s_axi_rdata,   // For read data
    output wire         s_axi_rvalid,
    input  wire         s_axi_rready,
    // ... (bresp, rresp signals as needed)


    // AXI4 Master Interface (for DMA to main memory - conceptual)
    // Connections to the m_axi ports of the KeystoneCoprocessor
    // These will be driven by the DMA logic, which might be part of CCU or a separate module.
    output wire [31:0]  m_axi_awaddr,
    output wire         m_axi_awvalid,
    input  wire         m_axi_awready,
    output wire [31:0]  m_axi_wdata,
    output wire         m_axi_wlast,
    output wire         m_axi_wvalid,
    input  wire         m_axi_wready,
    // ... (other master AXI signals as needed for DMA write/read)
    output wire [31:0]  m_axi_araddr,
    output wire         m_axi_arvalid,
    input  wire         m_axi_arready,
    input  wire [31:0]  m_axi_rdata,
    input  wire         m_axi_rlast,
    input  wire         m_axi_rvalid,
    output wire         m_axi_rready,


    // VM Control Outputs (for 8 eBPF_VM_Slots)
    output wire [7:0]   vm_start,                // Per VM start signal
    output wire [7:0]   vm_stop,                 // Per VM stop signal
    output wire [7:0]   vm_reset,                // Per VM reset signal
    output wire [31:0]  vm_load_program_addr [NUM_VM_SLOTS-1:0], // Not directly used by VM, but CCU uses info
    output wire [31:0]  vm_data_in_addr [NUM_VM_SLOTS-1:0],      // Not directly used by VM, but CCU uses info

    // VM Program Memory Write Interface Outputs
    output wire [VM_PROG_MEM_ADDR_WIDTH-1:0] vm_wr_prog_addr [NUM_VM_SLOTS-1:0],
    output wire [DATA_WIDTH_AXI-1:0]         vm_wr_prog_data [NUM_VM_SLOTS-1:0],
    output wire [NUM_VM_SLOTS-1:0]             vm_wr_prog_en,

    // VM Mailbox Interface with CCU (PicoRV32 access)
    // VM writes to its OUT mailbox (which CPU reads from CCU)
    input  wire [$clog2(NUM_MAILBOX_REGS)-1:0]    vm_mailbox_out_idx_i [NUM_VM_SLOTS-1:0],
    input  wire [DATA_WIDTH_AXI-1:0]              vm_mailbox_out_wdata_i [NUM_VM_SLOTS-1:0],
    input  wire                                 vm_mailbox_out_wen_i [NUM_VM_SLOTS-1:0],
    // VM reads from its IN mailbox (which CPU writes to CCU)
    input  wire [$clog2(NUM_MAILBOX_REGS)-1:0]    vm_mailbox_in_idx_i [NUM_VM_SLOTS-1:0],
    output wire [DATA_WIDTH_AXI-1:0]              vm_mailbox_in_rdata_o [NUM_VM_SLOTS-1:0],
    // output wire                               vm_mailbox_in_valid_o [NUM_VM_SLOTS-1:0], // Optional for now

    // VM Status Inputs (from 8 eBPF_VM_Slots)
    input  wire [7:0]   vm_ready,                // Per VM ready signal
    input  wire [7:0]   vm_done,                 // Per VM done signal
    input  wire [7:0]   vm_error,                // Per VM error signal
    input  wire [31:0]  vm_data_out_addr [7:0],   // Per VM output data address

    // Interrupt Output to KeystoneCoprocessor
    output wire         interrupt_out,

    // Global Clock and Reset
    input  wire         clk,
    input  wire         reset
);

    // Parameters
    localparam NUM_VM_SLOTS = 8;
    localparam ADDR_WIDTH_CPU_IF_AXI = 8; // Address width for AXI interface (e.g., 8 bits for 256 bytes)
    localparam DATA_WIDTH_AXI = 32;
    localparam VM_PROG_MEM_ADDR_WIDTH = 11; // $clog2(2048 words for prog_mem in eBPF_VM_Slot)

    // Memory Map Address Parameters
    localparam ADDR_COPRO_CMD_REG                = 8'h00;
    localparam ADDR_VM_SELECT_REG                = 8'h04;
    localparam ADDR_COPRO_STATUS_REG             = 8'h08;
    localparam ADDR_PROG_ADDR_LOW_REG            = 8'h0C;
    localparam ADDR_PROG_ADDR_HIGH_REG           = 8'h10;
    localparam ADDR_DATA_IN_ADDR_LOW_REG         = 8'h14;
    localparam ADDR_DATA_IN_ADDR_HIGH_REG        = 8'h18;
    localparam ADDR_DATA_OUT_ADDR_LOW_REG        = 8'h1C;
    localparam ADDR_DATA_OUT_ADDR_HIGH_REG       = 8'h20;
    localparam ADDR_DATA_LEN_REG                 = 8'h24;
    localparam ADDR_INT_STATUS_REG               = 8'h28;
    localparam ADDR_INT_ENABLE_REG               = 8'h2C;
    localparam ADDR_SELECTED_VM_STATUS_REG       = 8'h30;
    localparam ADDR_SELECTED_VM_PC_REG           = 8'h34;
    localparam ADDR_SELECTED_VM_DATA_OUT_ADDR_REG = 8'h38;
    localparam ADDR_MAILBOX_DATA_IN_0_REG        = 8'h80; // Start of Mailbox IN regs
    localparam ADDR_MAILBOX_DATA_OUT_0_REG       = 8'hA0; // Start of Mailbox OUT regs
    localparam ADDR_COPRO_VERSION_REG            = 8'hFC;

    localparam NUM_MAILBOX_REGS = 4; // Example: 4 mailbox registers (16 bytes)

    // Internal Registers
    reg [DATA_WIDTH_AXI-1:0] copro_cmd_reg_r;
    reg [2:0]                vm_select_id_r; // VM_ID is bits [2:0]
    // COPRO_STATUS_REG: [0] BUSY, [15:8] ACTIVE_VM_MASK (Read-Only by CPU)
    reg                      copro_busy_status_r; // Internal signal driving COPRO_STATUS_REG[0]
    reg [NUM_VM_SLOTS-1:0]   active_vm_mask_r;  // Internal signal driving COPRO_STATUS_REG[15:8]
    reg [DATA_WIDTH_AXI-1:0] prog_addr_low_reg_r;
    reg [DATA_WIDTH_AXI-1:0] prog_addr_high_reg_r;
    reg [DATA_WIDTH_AXI-1:0] data_in_addr_low_reg_r;
    reg [DATA_WIDTH_AXI-1:0] data_in_addr_high_reg_r;
    reg [DATA_WIDTH_AXI-1:0] data_out_addr_low_reg_r;
    reg [DATA_WIDTH_AXI-1:0] data_out_addr_high_reg_r;
    reg [DATA_WIDTH_AXI-1:0] data_len_reg_r;
    reg [DATA_WIDTH_AXI-1:0] int_status_reg_r;    // Bits [17:0] used
    reg [DATA_WIDTH_AXI-1:0] int_enable_reg_r;    // Bits [17:0] used

    // Per-VM status registers are read-only by CPU and reflect internal state based on vm_select_id_r
    // These are not directly writable registers but muxed outputs.
    // For simplicity, we will model placeholder sources for these read values.
    reg [DATA_WIDTH_AXI-1:0] selected_vm_status_val_r; // Placeholder
    reg [DATA_WIDTH_AXI-1:0] selected_vm_pc_val_r;       // Placeholder
    reg [DATA_WIDTH_AXI-1:0] selected_vm_data_out_addr_val_r; // Placeholder

    reg [DATA_WIDTH_AXI-1:0] mailbox_data_in_regs_r [NUM_MAILBOX_REGS-1:0];
    reg [DATA_WIDTH_AXI-1:0] mailbox_data_out_regs_r [NUM_MAILBOX_REGS-1:0]; // VM writes, CPU reads

    // COPRO_VERSION_REG is Read-Only
    localparam COPRO_VERSION = 32'h01000000; // Major 1, Minor 0, Patch 0

    // AXI4-Lite slave interface signals for internal logic
    reg                         axi_awready_r;
    reg                         axi_wready_r;
    reg  [1:0]                  axi_bresp_r;
    reg                         axi_bvalid_r;
    reg                         axi_arready_r;
    reg  [DATA_WIDTH_AXI-1:0]   axi_rdata_r;
    reg  [1:0]                  axi_rresp_r;
    reg                         axi_rvalid_r;

    // Internal signals for register access
    wire [ADDR_WIDTH_CPU_IF_AXI-1:0] axi_awaddr_internal; // Extracted address for write
    wire [ADDR_WIDTH_CPU_IF_AXI-1:0] axi_araddr_internal; // Extracted address for read
    reg [ADDR_WIDTH_CPU_IF_AXI-1:0] awaddr_latched_r; // Latched write address
    reg [ADDR_WIDTH_CPU_IF_AXI-1:0] araddr_latched_r; // Latched read address
    
    // State machine for AXI write
    localparam WRITE_IDLE = 0, WRITE_DATA = 1, WRITE_RESP = 2;
    reg [1:0] write_state_r;
    
    // State machine for AXI read
    localparam READ_IDLE = 0, READ_DATA = 1;
    reg read_state_r;

    // Placeholder for per-VM status (array of registers)
    // These would be updated by the actual VM slot status inputs
    reg [DATA_WIDTH_AXI-1:0] vm_status_regs_array_r [NUM_VM_SLOTS-1:0];
    reg [DATA_WIDTH_AXI-1:0] vm_pc_regs_array_r [NUM_VM_SLOTS-1:0];
    reg [DATA_WIDTH_AXI-1:0] vm_data_out_addr_regs_array_r [NUM_VM_SLOTS-1:0];

    // Placeholder for VM control signals (driven by CCU internal logic)
    reg [NUM_VM_SLOTS-1:0]   internal_vm_start_r; // These become the pulsed outputs
    reg [NUM_VM_SLOTS-1:0]   internal_vm_stop_r;  // These become the pulsed outputs
    reg [NUM_VM_SLOTS-1:0]   internal_vm_reset_r; // These become the pulsed outputs

    wire dma_busy_actual_w; // Actual DMA busy signal
    assign dma_busy_placeholder_w = dma_busy_actual_w; // Connect actual to placeholder for now

    // DMA State Machine
    localparam DMA_IDLE        = 3'd0;
    localparam DMA_START_REQ   = 3'd1; // Check request and latch parameters
    localparam DMA_CALC_BURST  = 3'd2; // Calculate burst parameters
    localparam DMA_INIT_READ   = 3'd3; // Assert ARVALID
    localparam DMA_READ_BURST  = 3'd4; // Wait for RVALID, RLAST
    localparam DMA_DONE        = 3'd5;
    localparam DMA_ERROR       = 3'd6;
    reg [2:0] dma_state_r;

    // DMA Internal Configuration Registers
    reg [DATA_WIDTH_AXI-1:0] dma_addr_r;         // Current DMA address (from CPU regs)
    reg [DATA_WIDTH_AXI-1:0] dma_len_bytes_r;    // Total length in bytes (from CPU regs)
    reg [2:0]                dma_target_vm_id_r; // Selected VM for this DMA op
    reg                      dma_op_is_prog_load_r; // True if program load, false if data_in load

    // AXI Master Read Channel Internal Signals (registers to drive m_axi_ar*)
    reg [DATA_WIDTH_AXI-1:0] m_axi_araddr_r;
    reg [7:0]                m_axi_arlen_r;    // Burst length (number of transfers - 1)
    reg [2:0]                m_axi_arsize_r;   // Transfer size (e.g., 3'b010 for 32-bit)
    reg [1:0]                m_axi_arburst_r;  // Burst type (e.g., 2'b01 for INCR)
    reg                      m_axi_arvalid_r;
    reg                      m_axi_rready_r;   // DMA ready to accept read data

    // DMA operation tracking
    reg [DATA_WIDTH_AXI-1:0] dma_bytes_transferred_r;
    reg [DATA_WIDTH_AXI-1:0] dma_current_burst_len_bytes_r; // Length of current AXI burst in bytes

    reg [DATA_WIDTH_AXI-1:0] dma_temp_rdata_r; // Temporary holding for last read data word
    
    // Internal registers for VM Program Memory Write
    reg [VM_PROG_MEM_ADDR_WIDTH-1:0] vm_wr_prog_addr_r [NUM_VM_SLOTS-1:0];
    reg [DATA_WIDTH_AXI-1:0]         vm_wr_prog_data_r [NUM_VM_SLOTS-1:0];
    reg [NUM_VM_SLOTS-1:0]             vm_wr_prog_en_r;
    reg [VM_PROG_MEM_ADDR_WIDTH-1:0] dma_vm_prog_mem_wr_addr_r; // Write address counter for VM's prog mem

    // Internal Mailbox Storage for each VM
    reg [DATA_WIDTH_AXI-1:0] vm_mailboxes_in[NUM_VM_SLOTS-1:0][NUM_MAILBOX_REGS-1:0];
    reg [DATA_WIDTH_AXI-1:0] vm_mailboxes_out[NUM_VM_SLOTS-1:0][NUM_MAILBOX_REGS-1:0];

    // Wire for VM Mailbox Read Data
    wire [DATA_WIDTH_AXI-1:0] vm_mailbox_in_rdata_internal [NUM_VM_SLOTS-1:0];
    assign vm_mailbox_in_rdata_o = vm_mailbox_in_rdata_internal;

    // Command Signals (pulsed for one clock cycle)
    wire start_vm_cmd_w;
    wire stop_vm_cmd_w;
    wire reset_vm_cmd_w;
    wire load_prog_cmd_w;
    wire load_data_in_cmd_w;

    //--------------------------------------------------------------------------
    // AXI4-Lite Slave Interface Logic
    //--------------------------------------------------------------------------

    assign s_axi_awready = axi_awready_r;
    assign s_axi_wready  = axi_wready_r;
    assign s_axi_bresp   = axi_bresp_r;
    assign s_axi_bvalid  = axi_bvalid_r;
    assign s_axi_arready = axi_arready_r;
    assign s_axi_rdata   = axi_rdata_r;
    assign s_axi_rresp   = axi_rresp_r;
    assign s_axi_rvalid  = axi_rvalid_r;

    // Internal address signals (lower bits for register selection)
    assign axi_awaddr_internal = s_axi_awaddr[ADDR_WIDTH_CPU_IF_AXI-1:0];
    assign axi_araddr_internal = s_axi_araddr[ADDR_WIDTH_CPU_IF_AXI-1:0];

    // Write Address/Data/Response Channels using state machine
    always @(posedge s_axi_aclk or posedge reset) begin
        if (reset) begin
            axi_awready_r <= 1'b0;
            awaddr_latched_r <= 8'b0;
            write_state_r <= WRITE_IDLE;
            axi_wready_r <= 1'b0;
            axi_bvalid_r <= 1'b0;
            axi_bresp_r  <= 2'b00;
        end else begin
            case (write_state_r)
                WRITE_IDLE: begin
                    axi_wready_r <= 1'b0; 
                    axi_bvalid_r <= 1'b0;
                    if (s_axi_awvalid && !axi_awready_r) begin // Ensure ready is asserted for one cycle
                        axi_awready_r <= 1'b1;
                        awaddr_latched_r <= axi_awaddr_internal; 
                    end else if (axi_awready_r) begin // Address latched, move to data
                        axi_awready_r <= 1'b0; // De-assert awready
                        write_state_r <= WRITE_DATA;
                    end else begin
                        axi_awready_r <= 1'b0;
                    end
                end
                WRITE_DATA: begin
                    if (s_axi_wvalid && !axi_wready_r) begin // Ensure ready is asserted for one cycle
                        axi_wready_r <= 1'b1;
                        // Register write occurs in the dedicated always block based on this condition
                    end else if (axi_wready_r) begin // Data latched (or processed), move to response
                         axi_wready_r <= 1'b0; // De-assert wready
                        write_state_r <= WRITE_RESP;
                    end else begin
                        axi_wready_r <= 1'b0;
                    end
                end
                WRITE_RESP: begin
                    axi_bvalid_r <= 1'b1;
                    axi_bresp_r  <= 2'b00; // OKAY
                    if (s_axi_bready) begin
                        write_state_r <= WRITE_IDLE;
                        axi_bvalid_r <= 1'b0; 
                    end
                end
                default: write_state_r <= WRITE_IDLE;
            endcase
        end
    end

    // Read Address/Data Channels using state machine
    always @(posedge s_axi_aclk or posedge reset) begin
        if (reset) begin
            axi_arready_r <= 1'b0;
            araddr_latched_r <= 8'b0;
            axi_rvalid_r  <= 1'b0;
            axi_rresp_r   <= 2'b00;
            axi_rdata_r   <= 32'b0; // Reset read data output
            read_state_r <= READ_IDLE;
        end else begin
            case(read_state_r)
                READ_IDLE: begin
                    axi_rvalid_r <= 1'b0;
                    if (s_axi_arvalid && !axi_arready_r) begin // Ensure ready is asserted for one cycle
                        axi_arready_r <= 1'b1;
                        araddr_latched_r <= axi_araddr_internal;
                    end else if (axi_arready_r) begin // Address latched, move to data
                        axi_arready_r <= 1'b0; // De-assert arready
                        read_state_r <= READ_DATA;
                    end else begin
                         axi_arready_r <= 1'b0;
                    end
                end
                READ_DATA: begin
                    // axi_rdata_r is assigned combinatorially based on araddr_latched_r
                    axi_rvalid_r <= 1'b1; 
                    axi_rresp_r  <= 2'b00; // OKAY
                    if (s_axi_rready) begin 
                        read_state_r <= READ_IDLE;
                        axi_rvalid_r <= 1'b0; 
                    end
                end
                default: read_state_r <= READ_IDLE;
            endcase
        end
    end

    //--------------------------------------------------------------------------
    // Register Read Logic Mux (combinatorial based on latched read address)
    //--------------------------------------------------------------------------
    always @(*) begin
        // Default read data for unmapped addresses or when not in READ_DATA state
        automatic logic [DATA_WIDTH_AXI-1:0] rdata_async; // Use automatic for combinatorial block temp var
        rdata_async = 32'hDEADBEEF; 

        case (araddr_latched_r) // Use latched address for read data path
            ADDR_COPRO_CMD_REG: rdata_async = copro_cmd_reg_r;
            ADDR_VM_SELECT_REG: rdata_async = {29'b0, vm_select_id_r};
            ADDR_COPRO_STATUS_REG: rdata_async = {16'b0, active_vm_mask_r, 7'b0, copro_busy_status_r};
            ADDR_PROG_ADDR_LOW_REG: rdata_async = prog_addr_low_reg_r;
            ADDR_PROG_ADDR_HIGH_REG: rdata_async = prog_addr_high_reg_r;
            ADDR_DATA_IN_ADDR_LOW_REG: rdata_async = data_in_addr_low_reg_r;
            ADDR_DATA_IN_ADDR_HIGH_REG: rdata_async = data_in_addr_high_reg_r;
            ADDR_DATA_OUT_ADDR_LOW_REG: rdata_async = data_out_addr_low_reg_r;
            ADDR_DATA_OUT_ADDR_HIGH_REG: rdata_async = data_out_addr_high_reg_r;
            ADDR_DATA_LEN_REG: rdata_async = data_len_reg_r;
            ADDR_INT_STATUS_REG: rdata_async = int_status_reg_r;
            ADDR_INT_ENABLE_REG: rdata_async = int_enable_reg_r;
            ADDR_SELECTED_VM_STATUS_REG: rdata_async = vm_status_regs_array_r[vm_select_id_r];
            ADDR_SELECTED_VM_PC_REG: rdata_async = vm_pc_regs_array_r[vm_select_id_r];
            ADDR_SELECTED_VM_DATA_OUT_ADDR_REG: rdata_async = vm_data_out_addr_regs_array_r[vm_select_id_r];
            ADDR_COPRO_VERSION_REG: rdata_async = COPRO_VERSION;
            default: begin
                if (araddr_latched_r >= ADDR_MAILBOX_DATA_IN_0_REG && araddr_latched_r < (ADDR_MAILBOX_DATA_IN_0_REG + NUM_MAILBOX_REGS*4)) begin
                    // CPU reads its own IN mailboxes (which are VM's OUT mailboxes from VM perspective)
                    // This path should read from vm_mailboxes_in (data CPU wrote for VM to read)
                    automatic logic [$clog2(NUM_MAILBOX_REGS)-1:0] mailbox_idx_r;
                    mailbox_idx_r = (araddr_latched_r - ADDR_MAILBOX_DATA_IN_0_REG) / 4;
                    if (mailbox_idx_r < NUM_MAILBOX_REGS) begin // Check bounds
                         rdata_async = vm_mailboxes_in[vm_select_id_r][mailbox_idx_r];
                    end else {
                         rdata_async = 32'hBADBAD01; // Index out of bounds for IN mbox
                    }
                end else if (araddr_latched_r >= ADDR_MAILBOX_DATA_OUT_0_REG && araddr_latched_r < (ADDR_MAILBOX_DATA_OUT_0_REG + NUM_MAILBOX_REGS*4)) begin
                    // CPU reads its OUT mailboxes (which are VM's IN mailboxes from VM perspective)
                    // This path should read from vm_mailboxes_out (data VM wrote for CPU to read)
                    automatic logic [$clog2(NUM_MAILBOX_REGS)-1:0] mailbox_idx_r;
                    mailbox_idx_r = (araddr_latched_r - ADDR_MAILBOX_DATA_OUT_0_REG) / 4;
                     if (mailbox_idx_r < NUM_MAILBOX_REGS) begin // Check bounds
                        rdata_async = vm_mailboxes_out[vm_select_id_r][mailbox_idx_r];
                    end else {
                         rdata_async = 32'hBADBAD02; // Index out of bounds for OUT mbox
                    }
                end else begin
                    rdata_async = 32'hDEADBEEF; // Unmapped address
                end
            end
        endcase
        axi_rdata_r = rdata_async; // Assign to the output register used by the read state machine
    end

    //--------------------------------------------------------------------------
    // Register Write Logic & Special Behaviors (SC, RC)
    //--------------------------------------------------------------------------
    always @(posedge s_axi_aclk or posedge reset) begin
        if (reset) begin
            copro_cmd_reg_r         <= 32'b0;
            vm_select_id_r          <= 3'b0;
            prog_addr_low_reg_r     <= 32'b0;
            prog_addr_high_reg_r    <= 32'b0;
            data_in_addr_low_reg_r  <= 32'b0;
            data_in_addr_high_reg_r <= 32'b0;
            data_out_addr_low_reg_r <= 32'b0;
            data_out_addr_high_reg_r<= 32'b0;
            data_len_reg_r          <= 32'b0;
            int_status_reg_r        <= 32'b0; 
            int_enable_reg_r        <= 32'b0;
            // mailbox_data_in_regs_r is replaced by vm_mailboxes_in
            // mailbox_data_out_regs_r is replaced by vm_mailboxes_out
            for (integer i = 0; i < NUM_VM_SLOTS; i = i + 1) begin
                for (integer j = 0; j < NUM_MAILBOX_REGS; j = j + 1) begin
                    vm_mailboxes_in[i][j] <= 32'b0;
                    vm_mailboxes_out[i][j] <= 32'b0;
                end
                vm_status_regs_array_r[i] <= 32'b0; // Example: VM ready
                vm_pc_regs_array_r[i] <= 32'b0;
                vm_data_out_addr_regs_array_r[i] <= 32'b0;
                internal_vm_start_r[i] <= 1'b0;
                internal_vm_stop_r[i] <= 1'b0;
                internal_vm_reset_r[i] <= 1'b0;
            end
            copro_busy_status_r <= 1'b0;
            active_vm_mask_r    <= 8'b0;

        end else begin
            // Register writes occur when write FSM is in WRITE_DATA and wvalid is high
            if (write_state_r == WRITE_DATA && s_axi_wvalid && axi_wready_r) begin
                case (awaddr_latched_r) // Use latched address for write
                    ADDR_COPRO_CMD_REG: begin
                        // Store the command; SC bits will be cleared based on pulsed command signals
                        copro_cmd_reg_r <= s_axi_wdata; 
                    end
                    ADDR_VM_SELECT_REG: begin
                        vm_select_id_r <= s_axi_wdata[2:0]; 
                    end
                    ADDR_PROG_ADDR_LOW_REG: prog_addr_low_reg_r <= s_axi_wdata;
                    ADDR_PROG_ADDR_HIGH_REG: prog_addr_high_reg_r <= s_axi_wdata;
                    ADDR_DATA_IN_ADDR_LOW_REG: data_in_addr_low_reg_r <= s_axi_wdata;
                    ADDR_DATA_IN_ADDR_HIGH_REG: data_in_addr_high_reg_r <= s_axi_wdata;
                    ADDR_DATA_OUT_ADDR_LOW_REG: data_out_addr_low_reg_r <= s_axi_wdata;
                    ADDR_DATA_OUT_ADDR_HIGH_REG: data_out_addr_high_reg_r <= s_axi_wdata;
                    ADDR_DATA_LEN_REG: data_len_reg_r <= s_axi_wdata;
                    ADDR_INT_ENABLE_REG: int_enable_reg_r <= s_axi_wdata & 32'h0003FFFF;
                    ADDR_INT_STATUS_REG: begin 
                        // Allow W1C (Write-1-to-Clear) for INT_STATUS_REG
                        int_status_reg_r <= int_status_reg_r & ~s_axi_wdata;
                    end
                    default: begin
                        if (awaddr_latched_r >= ADDR_MAILBOX_DATA_IN_0_REG && awaddr_latched_r < (ADDR_MAILBOX_DATA_IN_0_REG + NUM_MAILBOX_REGS*4)) begin
                            // Assuming full word writes, s_axi_wstrb can be used for byte-level control if needed
                            automatic logic [$clog2(NUM_MAILBOX_REGS)-1:0] mailbox_idx_w;
                            mailbox_idx_w = (awaddr_latched_r - ADDR_MAILBOX_DATA_IN_0_REG) / 4;
                            if (mailbox_idx_w < NUM_MAILBOX_REGS) begin // Check bounds
                                vm_mailboxes_in[vm_select_id_r][mailbox_idx_w] <= s_axi_wdata;
                            end
                        end else if (awaddr_latched_r >= ADDR_MAILBOX_DATA_OUT_0_REG && awaddr_latched_r < (ADDR_MAILBOX_DATA_OUT_0_REG + NUM_MAILBOX_REGS*4)) begin
                            // CPU typically does not write to OUT mailboxes, this path might be for testing or specific features.
                            // For now, writes to OUT mailboxes from CPU are ignored or could also go to vm_mailboxes_out.
                            // Let's make them ignored to prevent CPU from overwriting VM outputs directly.
                        end
                        // Writes to read-only registers are ignored (e.g. COPRO_STATUS_REG, SELECTED_VM_*, COPRO_VERSION_REG)
                    end
                endcase
            end

            // Handle Self-Clearing (SC) bits for COPRO_CMD_REG after command pulse generation
            if (start_vm_cmd_w) copro_cmd_reg_r[0] <= 1'b0;
            if (stop_vm_cmd_w) copro_cmd_reg_r[1] <= 1'b0;
            if (reset_vm_cmd_w) copro_cmd_reg_r[2] <= 1'b0;
            if (load_prog_cmd_w) copro_cmd_reg_r[3] <= 1'b0;
            if (load_data_in_cmd_w) copro_cmd_reg_r[4] <= 1'b0;

            // Handle Read-Clear (RC) for INT_STATUS_REG
            // Clears bits that were read in the previous cycle when read FSM was in READ_DATA and master was ready
            if (read_state_r == READ_IDLE && axi_rvalid_r && s_axi_rready && araddr_latched_r == ADDR_INT_STATUS_REG) begin
                 // We check READ_IDLE because read_state_r transitions to IDLE when s_axi_rready is high in READ_DATA
                 // axi_rdata_r still holds the value that was read out
                int_status_reg_r <= int_status_reg_r & ~axi_rdata_r; 
            end

            // VM Control Logic: Pulsing internal_vm_* signals based on commands
            // Clear all internal pulse signals first
            for (integer i = 0; i < NUM_VM_SLOTS; i = i + 1) begin
                internal_vm_start_r[i] <= 1'b0;
                internal_vm_stop_r[i]  <= 1'b0;
                internal_vm_reset_r[i] <= 1'b0;
            end

            if (start_vm_cmd_w)    internal_vm_start_r[vm_select_id_r] <= 1'b1;
            if (stop_vm_cmd_w)     internal_vm_stop_r[vm_select_id_r]  <= 1'b1;
            if (reset_vm_cmd_w)    internal_vm_reset_r[vm_select_id_r] <= 1'b1;
            
            // Update active_vm_mask_r based on VM lifecycle events
            for (integer i = 0; i < NUM_VM_SLOTS; i = i + 1) begin
                if (internal_vm_start_r[i]) begin // VM starts
                    active_vm_mask_r[i] <= 1'b1;
                end else if (internal_vm_stop_r[i] || vm_done[i] || vm_error[i]) begin // VM stops, completes, or errors
                    active_vm_mask_r[i] <= 1'b0;
                end
            end
            
            // Update INT_STATUS_REG from VM status inputs (vm_done, vm_error)
            for (integer i = 0; i < NUM_VM_SLOTS; i = i + 1) begin
                if (vm_done[i]) begin
                    int_status_reg_r[i] <= 1'b1; // VMi_DONE_IRQ (Bits 0-7)
                end
                if (vm_error[i]) begin
                    int_status_reg_r[i + NUM_VM_SLOTS] <= 1'b1; // VMi_ERROR_IRQ (Bits 8-15)
                end
            end
            // Note: DMA_DONE_IRQ (Bit 16) and DMA_ERROR_IRQ (Bit 17) in int_status_reg_r
            // are to be set by DMA logic, not covered here.

            // Handle VM writes to their OUT mailboxes (data to be read by CPU)
            for (integer i = 0; i < NUM_VM_SLOTS; i = i + 1) begin
                if (vm_mailbox_out_wen_i[i]) begin
                    if (vm_mailbox_out_idx_i[i] < NUM_MAILBOX_REGS) begin
                        vm_mailboxes_out[i][vm_mailbox_out_idx_i[i]] <= vm_mailbox_out_wdata_i[i];
                    end
                    // Optional: else, handle index out of bounds error for VM write?
                    // For now, writes to out-of-bounds indices are ignored.
                end
            end
        end
    end

    // Combinatorial assignment for copro_busy_status_r
    assign copro_busy_status_r = |active_vm_mask_r | dma_busy_placeholder_w;

    // PicoRV32 (VM) Access to Mailboxes
    // VM Reads from its IN Mailbox (data written by CPU to CCU's vm_mailboxes_in)
    genvar k_ccu_mbox; 
    generate
        for (k_ccu_mbox = 0; k_ccu_mbox < NUM_VM_SLOTS; k_ccu_mbox = k_ccu_mbox + 1) begin : vm_mailbox_read_gen_ccu
            assign vm_mailbox_in_rdata_internal[k_ccu_mbox] = 
                (vm_mailbox_in_idx_i[k_ccu_mbox] < NUM_MAILBOX_REGS) ? 
                vm_mailboxes_in[k_ccu_mbox][vm_mailbox_in_idx_i[k_ccu_mbox]] : 
                32'hBADADD03; // Indicate read error (index out of bounds for specific VM)
        end
    endgenerate

    //--------------------------------------------------------------------------
    // Command Signal Generation (Pulsed for one cycle)
    //--------------------------------------------------------------------------
    reg [4:0] cmd_reg_written_snapshot_r; // Snapshot of command bits when written

    always @(posedge s_axi_aclk or posedge reset) begin
        if (reset) begin
            cmd_reg_written_snapshot_r <= 5'b0;
        end else begin
            if (write_state_r == WRITE_DATA && s_axi_wvalid && axi_wready_r && awaddr_latched_r == ADDR_COPRO_CMD_REG) begin
                cmd_reg_written_snapshot_r <= s_axi_wdata[4:0]; // Capture command bits on write
            end else begin
                cmd_reg_written_snapshot_r <= 5'b0; // Clear in the next cycle to ensure one-cycle pulse
            end
        end
    end

    assign start_vm_cmd_w     = cmd_reg_written_snapshot_r[0];
    assign stop_vm_cmd_w      = cmd_reg_written_snapshot_r[1];
    assign reset_vm_cmd_w     = cmd_reg_written_snapshot_r[2];
    assign load_prog_cmd_w    = cmd_reg_written_snapshot_r[3];
    assign load_data_in_cmd_w = cmd_reg_written_snapshot_r[4];

    //--------------------------------------------------------------------------
    // VM Control Signal Assignments from internal registers
    //--------------------------------------------------------------------------
    assign vm_start = internal_vm_start_r;
    assign vm_stop  = internal_vm_stop_r;
    assign vm_reset = internal_vm_reset_r;
    // vm_load_program_addr and vm_data_in_addr will be driven by DMA/control logic later
    // For now, they are not assigned here to avoid compilation errors if not fully driven.
    // They are outputs of the CCU. The memory map registers PROG_ADDR_LOW/HIGH etc.
    // are inputs to the DMA, not directly to these VM control ports.

    //--------------------------------------------------------------------------
    // Interrupt Logic
    //--------------------------------------------------------------------------
    wire [DATA_WIDTH_AXI-1:0] active_interrupts;
    assign active_interrupts = int_status_reg_r & int_enable_reg_r;
    assign interrupt_out = |active_interrupts[17:0]; // Consider only relevant 18 bits for interrupt


    //--------------------------------------------------------------------------
    // DMA Controller Logic (conceptual) - Placeholder
    //--------------------------------------------------------------------------
    // This section will later use load_prog_cmd_w, load_data_in_cmd_w, 
    // prog_addr_low/high_reg_r, data_in_addr_low/high_reg_r, data_len_reg_r, etc.
    // to control the AXI Master interface.

    // Connect DMA registers to AXI Master Read interface
    assign m_axi_araddr  = m_axi_araddr_r;
    assign m_axi_arlen   = m_axi_arlen_r;
    assign m_axi_arsize  = m_axi_arsize_r;
    assign m_axi_arburst = m_axi_arburst_r;
    assign m_axi_arvalid = m_axi_arvalid_r;
    assign m_axi_rready  = m_axi_rready_r;

    // Connect internal registers to VM Program Memory Write Interface Outputs
    assign vm_wr_prog_addr = vm_wr_prog_addr_r;
    assign vm_wr_prog_data = vm_wr_prog_data_r;
    assign vm_wr_prog_en   = vm_wr_prog_en_r;

    // Tie off AXI Master Write interface (not used in this subtask)
    assign m_axi_awaddr = 32'b0;
    assign m_axi_awvalid = 1'b0;
    assign m_axi_wdata = 32'b0;
    assign m_axi_wlast = 1'b0;
    assign m_axi_wvalid = 1'b0;
    // assign m_axi_bready will be tied or handled if writes were implemented

    assign dma_busy_actual_w = (dma_state_r != DMA_IDLE);

    // DMA Controller State Machine Logic
    always @(posedge s_axi_aclk or posedge reset) begin
        if (reset) begin
            dma_state_r <= DMA_IDLE;
            dma_addr_r <= 32'b0;
            dma_len_bytes_r <= 32'b0;
            dma_target_vm_id_r <= 3'b0;
            dma_op_is_prog_load_r <= 1'b0;
            dma_bytes_transferred_r <= 32'b0;
            dma_current_burst_len_bytes_r <= 32'b0;
            dma_temp_rdata_r <= 32'b0;

            m_axi_araddr_r  <= 32'b0;
            m_axi_arlen_r   <= 8'b0;
            m_axi_arsize_r  <= 3'b010; // Default to 4-byte words
            m_axi_arburst_r <= 2'b01;  // Default to INCR
            m_axi_arvalid_r <= 1'b0;
            m_axi_rready_r  <= 1'b0;
            
            dma_vm_prog_mem_wr_addr_r <= 0;
            for (integer i = 0; i < NUM_VM_SLOTS; i = i + 1) begin
                vm_wr_prog_en_r[i] <= 1'b0;
                // vm_wr_prog_addr_r and vm_wr_prog_data_r don't need reset here, driven by logic.
            end
        end else begin
            // Default de-assertion for one-cycle pulse behavior of vm_wr_prog_en
            for (integer i = 0; i < NUM_VM_SLOTS; i = i + 1) begin
                vm_wr_prog_en_r[i] <= 1'b0;
            end

            case (dma_state_r)
                DMA_IDLE: begin
                    m_axi_arvalid_r <= 1'b0;
                    m_axi_rready_r  <= 1'b0;
                    if (load_prog_cmd_w || load_data_in_cmd_w) begin
                        dma_vm_prog_mem_wr_addr_r <= 0; // Reset for new DMA operation
                        dma_op_is_prog_load_r <= load_prog_cmd_w; // True if prog load
                        dma_target_vm_id_r    <= vm_select_id_r;
                        if (load_prog_cmd_w) begin
                            dma_addr_r <= {prog_addr_high_reg_r[31:0], prog_addr_low_reg_r[31:0]}; // Assuming 64-bit if available, else just low
                        end else begin // data_in_cmd_w
                            dma_addr_r <= {data_in_addr_high_reg_r[31:0], data_in_addr_low_reg_r[31:0]};
                        end
                        dma_len_bytes_r <= data_len_reg_r;
                        dma_bytes_transferred_r <= 32'b0;
                        
                        if (data_len_reg_r == 0 || (data_len_reg_r % 4 != 0) ) begin // Length 0 or not word aligned is error for simple DMA
                            dma_state_r <= DMA_ERROR;
                        end else begin
                            dma_state_r <= DMA_CALC_BURST;
                        end
                    end
                end

                DMA_CALC_BURST: begin
                    automatic logic [31:0] remaining_bytes;
                    automatic logic [31:0] current_burst_transfers;
                    
                    remaining_bytes = dma_len_bytes_r - dma_bytes_transferred_r;
                    
                    m_axi_arsize_r  <= 3'b010; // 4 bytes
                    m_axi_arburst_r <= 2'b01;  // INCR

                    if (remaining_bytes > (256 * 4)) begin // Max 256 transfers per burst
                        current_burst_transfers = 256;
                    end else begin
                        current_burst_transfers = remaining_bytes / 4;
                    end
                    dma_current_burst_len_bytes_r <= current_burst_transfers * 4;
                    m_axi_arlen_r   <= (current_burst_transfers == 0) ? 8'd0 : (current_burst_transfers - 1);
                    m_axi_araddr_r  <= dma_addr_r + dma_bytes_transferred_r;
                    
                    if (current_burst_transfers == 0 && remaining_bytes > 0) begin // Should not happen if len was validated
                        dma_state_r <= DMA_ERROR;
                    end else if (current_burst_transfers == 0 && remaining_bytes == 0) begin // Should have been caught by len=0 check
                         dma_state_r <= DMA_DONE;
                    end else begin
                        dma_state_r <= DMA_INIT_READ;
                    end
                end

                DMA_INIT_READ: begin
                    m_axi_arvalid_r <= 1'b1;
                    if (m_axi_arready) begin
                        m_axi_arvalid_r <= 1'b0;
                        dma_state_r     <= DMA_READ_BURST;
                    end
                end

                DMA_READ_BURST: begin
                    m_axi_rready_r <= 1'b1; // Always ready to accept data
                    if (m_axi_rvalid) begin
                        // Successfully received a data beat
                        if (m_axi_rresp != 2'b00) begin // SLVERR or DECERR
                            dma_state_r <= DMA_ERROR;
                            m_axi_rready_r <= 1'b0; // Stop accepting data on error
                        end else begin
                            dma_temp_rdata_r <= m_axi_rdata; // Store all data temporarily for now
                            
                            if (dma_op_is_prog_load_r) begin
                                if (dma_vm_prog_mem_wr_addr_r < (1 << VM_PROG_MEM_ADDR_WIDTH)) begin // Check bounds
                                    vm_wr_prog_data_r[dma_target_vm_id_r] <= m_axi_rdata;
                                    vm_wr_prog_addr_r[dma_target_vm_id_r] <= dma_vm_prog_mem_wr_addr_r;
                                    vm_wr_prog_en_r[dma_target_vm_id_r]   <= 1'b1;
                                    dma_vm_prog_mem_wr_addr_r             <= dma_vm_prog_mem_wr_addr_r + 1;
                                end else begin
                                    // Address out of bounds for VM program memory
                                    dma_state_r <= DMA_ERROR;
                                    m_axi_rready_r <= 1'b0; 
                                end
                            end
                            // For LOAD_DATA_IN, data is in dma_temp_rdata_r, can be processed later or passed to VM via another mechanism.

                            dma_bytes_transferred_r <= dma_bytes_transferred_r + 4; // Assuming ARSIZE is 4 bytes

                            if (m_axi_rlast) begin
                                if (dma_bytes_transferred_r == dma_len_bytes_r) begin // Check if this was the last beat of the entire transfer
                                    dma_state_r <= DMA_DONE;
                                end else if (dma_bytes_transferred_r < dma_len_bytes_r) begin
                                    // More bursts needed for the entire transfer
                                    dma_state_r <= DMA_CALC_BURST;
                                end else { // dma_bytes_transferred_r > dma_len_bytes_r
                                    dma_state_r <= DMA_ERROR; // Too much data received for the specified length
                                }
                                m_axi_rready_r <= 1'b0; // De-assert rready after burst completion or error
                            end
                            // If not rlast, stay in DMA_READ_BURST, rready remains high to receive next beat of current AXI burst
                        end
                    end else { // m_axi_rvalid is low
                        // Maintain m_axi_rready_r if expecting more data in burst.
                        // If rlast was received and we are moving to DONE/ERROR/CALC_BURST, 
                        // rready will be de-asserted by those states or after rlast handling.
                    }
                end

                DMA_DONE: begin
                    int_status_reg_r[16] <= 1'b1; // Set DMA_DONE_IRQ
                    m_axi_rready_r  <= 1'b0;
                    dma_state_r <= DMA_IDLE;
                end

                DMA_ERROR: begin
                    int_status_reg_r[17] <= 1'b1; // Set DMA_ERROR_IRQ
                    m_axi_rready_r  <= 1'b0;
                    dma_state_r <= DMA_IDLE;
                end
                default: dma_state_r <= DMA_IDLE;
            endcase
        end
    end

    // Unused VM input placeholders (will be used for status updates to CCU)
    // input  wire [7:0]   vm_ready;
    // input  wire [7:0]   vm_done;
    // input  wire [7:0]   vm_error;
    // input  wire [31:0]  vm_data_out_addr [7:0];

endmodule
