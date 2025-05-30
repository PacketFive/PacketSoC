// Top-Level Module: KeystoneCoprocessor.v
// Date: 2024-03-14

`timescale 1ns / 1ps

module KeystoneCoprocessor (
    // AXI4-Lite Slave Interface (for CPU commands/status)
    input  wire         s_axi_aclk,
    input  wire         s_axi_aresetn,
    input  wire [31:0]  s_axi_awaddr,
    input  wire [2:0]   s_axi_awprot,
    input  wire         s_axi_awvalid,
    output wire         s_axi_awready,
    input  wire [31:0]  s_axi_wdata,
    input  wire [3:0]   s_axi_wstrb,
    input  wire         s_axi_wvalid,
    output wire         s_axi_wready,
    output wire [1:0]   s_axi_bresp,
    output wire         s_axi_bvalid,
    input  wire         s_axi_bready,
    input  wire [31:0]  s_axi_araddr,
    input  wire [2:0]   s_axi_arprot,
    input  wire         s_axi_arvalid,
    output wire         s_axi_arready,
    output wire [31:0]  s_axi_rdata,
    output wire [1:0]   s_axi_rresp,
    output wire         s_axi_rvalid,
    input  wire         s_axi_rready,

    // AXI4 Master Interface (for DMA to main memory)
    input  wire         m_axi_aclk,
    input  wire         m_axi_aresetn,
    output wire [31:0]  m_axi_awaddr,
    output wire [2:0]   m_axi_awprot,
    output wire         m_axi_awvalid,
    input  wire         m_axi_awready,
    output wire [31:0]  m_axi_wdata,
    output wire [3:0]   m_axi_wstrb,
    output wire         m_axi_wlast,
    output wire         m_axi_wvalid,
    input  wire         m_axi_wready,
    input  wire [1:0]   m_axi_bresp,
    input  wire         m_axi_bvalid,
    output wire         m_axi_bready,
    output wire [31:0]  m_axi_araddr,
    output wire [2:0]   m_axi_arprot,
    output wire         m_axi_arvalid,
    input  wire         m_axi_arready,
    input  wire [31:0]  m_axi_rdata,
    input  wire [1:0]   m_axi_rresp,
    input  wire         m_axi_rlast,
    input  wire         m_axi_rvalid,
    output wire         m_axi_rready,

    // Interrupt Output
    output wire         interrupt_out,

    // Global Clock and Reset
    input  wire         clk,
    input  wire         reset
);

    // Parameters
    localparam NUM_VM_SLOTS = 8;
    localparam VM_PROG_MEM_ADDR_WIDTH = 11; // For eBPF_VM_Slot prog_mem (2048 words)
    localparam DATA_WIDTH_AXI = 32;       // Should match CCU's DATA_WIDTH_AXI
    localparam NUM_MAILBOX_REGS_TOP = 4;  // Should match NUM_MAILBOX_REGS in CCU and NUM_MAILBOX_REGS_VM in Slot

    // Internal wires and signals
    // Connections from CCU to VM Slots for Program Memory Write
    wire [VM_PROG_MEM_ADDR_WIDTH-1:0] vm_wr_prog_addr_w [NUM_VM_SLOTS-1:0];
    wire [DATA_WIDTH_AXI-1:0]         vm_wr_prog_data_w [NUM_VM_SLOTS-1:0];
    wire [NUM_VM_SLOTS-1:0]             vm_wr_prog_en_w;

    // CCU <-> VM Slot Mailbox Connections
    wire [$clog2(NUM_MAILBOX_REGS_TOP)-1:0] vm_mailbox_out_idx_ks_w [NUM_VM_SLOTS-1:0];
    wire [DATA_WIDTH_AXI-1:0]              vm_mailbox_out_wdata_ks_w [NUM_VM_SLOTS-1:0];
    wire [NUM_VM_SLOTS-1:0]                  vm_mailbox_out_wen_ks_w;
    wire [$clog2(NUM_MAILBOX_REGS_TOP)-1:0] vm_mailbox_in_idx_ks_w [NUM_VM_SLOTS-1:0];
    wire [DATA_WIDTH_AXI-1:0]              vm_mailbox_in_rdata_ks_w [NUM_VM_SLOTS-1:0];

    // Other CCU <-> VM Slot connections (lifecycle, status)
    wire [NUM_VM_SLOTS-1:0] vm_start_w;
    wire [NUM_VM_SLOTS-1:0] vm_stop_w;
    wire [NUM_VM_SLOTS-1:0] vm_reset_w;
    wire [NUM_VM_SLOTS-1:0] vm_ready_w;
    wire [NUM_VM_SLOTS-1:0] vm_done_w;
    wire [NUM_VM_SLOTS-1:0] vm_error_w;
    // vm_load_program_addr and vm_data_in_addr are informational for CCU, not direct VM connections.
    // vm_data_out_addr from VM to CCU.

    // Instantiate CoprocessorControlUnit (CCU)
    CoprocessorControlUnit ccu_inst (
        // AXI-Lite Slave Interface for commands
        .s_axi_aclk(s_axi_aclk),
        .s_axi_aresetn(s_axi_aresetn),
        .s_axi_awaddr(s_axi_awaddr),
        .s_axi_awvalid(s_axi_awvalid),
        .s_axi_awready(s_axi_awready),
        .s_axi_wdata(s_axi_wdata),
        .s_axi_wstrb(s_axi_wstrb),
        .s_axi_wvalid(s_axi_wvalid),
        .s_axi_wready(s_axi_wready),
        .s_axi_bresp(s_axi_bresp),
        .s_axi_bvalid(s_axi_bvalid),
        .s_axi_bready(s_axi_bready),
        .s_axi_araddr(s_axi_araddr),
        .s_axi_arvalid(s_axi_arvalid),
        .s_axi_arready(s_axi_arready),
        .s_axi_rdata(s_axi_rdata),
        .s_axi_rresp(s_axi_rresp),
        .s_axi_rvalid(s_axi_rvalid),
        .s_axi_rready(s_axi_rready),

        // AXI Master Interface for DMA
        .m_axi_aclk(m_axi_aclk),
        .m_axi_aresetn(m_axi_aresetn),
        .m_axi_awaddr(m_axi_awaddr),
        // .m_axi_awprot(m_axi_awprot), // CCU does not drive this directly
        .m_axi_awvalid(m_axi_awvalid),
        .m_axi_awready(m_axi_awready),
        .m_axi_wdata(m_axi_wdata),
        // .m_axi_wstrb(m_axi_wstrb),   // CCU does not drive this directly
        .m_axi_wlast(m_axi_wlast),
        .m_axi_wvalid(m_axi_wvalid),
        .m_axi_wready(m_axi_wready),
        // .m_axi_bresp(m_axi_bresp),   // CCU receives this
        // .m_axi_bvalid(m_axi_bvalid), // CCU receives this
        // .m_axi_bready(m_axi_bready), // CCU drives this
        .m_axi_araddr(m_axi_araddr),
        // .m_axi_arprot(m_axi_arprot), // CCU does not drive this directly
        .m_axi_arvalid(m_axi_arvalid),
        .m_axi_arready(m_axi_arready),
        .m_axi_rdata(m_axi_rdata),     // CCU receives this
        .m_axi_rresp(m_axi_rresp),     // CCU receives this
        .m_axi_rlast(m_axi_rlast),     // CCU receives this
        .m_axi_rvalid(m_axi_rvalid),   // CCU receives this
        .m_axi_rready(m_axi_rready),   // CCU drives this

        // VM Control Outputs
        .vm_start(vm_start_w),
        .vm_stop(vm_stop_w),
        .vm_reset(vm_reset_w),
        // .vm_load_program_addr(), // Output from CCU, not directly to VM slots
        // .vm_data_in_addr(),      // Output from CCU, not directly to VM slots
        .vm_wr_prog_addr(vm_wr_prog_addr_w),
        .vm_wr_prog_data(vm_wr_prog_data_w),
        .vm_wr_prog_en(vm_wr_prog_en_w),

        // VM Status Inputs
        .vm_ready(vm_ready_w),
        .vm_done(vm_done_w),
        .vm_error(vm_error_w),
        // .vm_data_out_addr(), // Input to CCU from VMs

        // VM Mailbox Interface with CCU
        .vm_mailbox_out_idx_i(vm_mailbox_out_idx_ks_w),
        .vm_mailbox_out_wdata_i(vm_mailbox_out_wdata_ks_w),
        .vm_mailbox_out_wen_i(vm_mailbox_out_wen_ks_w),
        .vm_mailbox_in_idx_i(vm_mailbox_in_idx_ks_w),
        .vm_mailbox_in_rdata_o(vm_mailbox_in_rdata_ks_w),

        // Interrupt Output
        .interrupt_out(interrupt_out),

        // Global clock and reset
        .clk(clk),
        .reset(reset)
    );

    // Instantiate eBPF_VM_Slot modules (NUM_VM_SLOTS times)
    genvar i;
    generate
        for (i = 0; i < NUM_VM_SLOTS; i = i + 1) begin : vm_slot_gen
            eBPF_VM_Slot #(
                // Assuming eBPF_VM_Slot parameters are default or correctly set internally for now
            ) vm_slot_inst (
                // Control Signals from CCU
                .start_vm(vm_start_w[i]),
                .stop_vm(vm_stop_w[i]),
                .reset_vm(vm_reset_w[i]),
                // .load_program_address(), // This is info for CCU's DMA, not direct to VM
                // .data_in_address(),      // This is info for CCU's DMA, not direct to VM

                // Status Signals to CCU
                .ready(vm_ready_w[i]),
                .done(vm_done_w[i]),
                .error(vm_error_w[i]),
                // .data_out_available_address(), // Connect this if/when CCU needs it

                // Memory Write Interface (for CCU DMA to write to VM's Program Memory)
                .write_prog_mem_addr_i(vm_wr_prog_addr_w[i]),
                .write_prog_mem_data_i(vm_wr_prog_data_w[i]),
                .write_prog_mem_en_i(vm_wr_prog_en_w[i]),

                // Stack memory write and all read interfaces are for internal VM use or later features
                // .write_stack_mem_addr_i(),
                // .write_stack_mem_data_i(),
                // .write_stack_mem_en_i(),
                // .read_prog_mem_addr_i(),  // Driven by VM's internal PC
                // .prog_mem_data_o(),       // Read by VM's fetch stage
                // .read_stack_mem_addr_i(), // Driven by VM's internal SP/FP
                // .stack_mem_data_o(),      // Read by VM's execution stage

                // Mailbox Interface
                .vm_mailbox_out_idx_o(vm_mailbox_out_idx_ks_w[i]),
                .vm_mailbox_out_wdata_o(vm_mailbox_out_wdata_ks_w[i]),
                .vm_mailbox_out_wen_o(vm_mailbox_out_wen_ks_w[i]),
                .vm_mailbox_in_idx_o(vm_mailbox_in_idx_ks_w[i]),
                .vm_mailbox_in_rdata_i(vm_mailbox_in_rdata_ks_w[i]),

                // Global clock and reset
                .clk(clk), // Assuming all VMs and CCU share the same main clock 'clk'
                .reset(reset) // Assuming all VMs and CCU share the same main reset 'reset'
            );
        end
    endgenerate

    // Instantiate AXI Interface Adapters/Modules (if necessary)
    // e.g., AXI4-Lite to internal bus adapter
    // e.g., AXI4 Master DMA controller (or connect CCU to m_axi ports)


    // Logic for interrupt_out generation
    // ...

endmodule
