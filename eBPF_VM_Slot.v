// eBPF VM Slot Module Stub
// Date: 2024-03-14

`timescale 1ns / 1ps

module eBPF_VM_Slot (
    // Control Signals from CCU
    input  wire         start_vm,                // Start execution
    input  wire         stop_vm,                 // Stop/pause execution
    input  wire         reset_vm,                // Reset VM state
    input  wire [31:0]  load_program_address,    // Address of program in shared memory (for DMA by CCU)
    input  wire [31:0]  data_in_address,         // Address of input data in shared memory (for DMA by CCU)
                                                // or direct input data if interface supports it

    // Status Signals to CCU
    output wire         ready,                   // VM is ready to receive a program/start
    output wire         done,                    // VM has finished execution (or hit a breakpoint)
    output wire         error,                   // VM encountered an error (e.g., invalid instruction)
    output wire [31:0]  data_out_available_address, // Address of output data in shared memory (written by VM)
                                                // or direct output data if interface supports it

    // Memory Interface (for VM's dedicated memory)
    // This interface is conceptual and would connect to an internal memory block
    // or a memory controller for accessing BRAM/SRAM.
    // For simplicity, we can assume direct access to internal memories for now.
    // Example:
    // output wire [15:0] prog_mem_addr,      // Program memory address
    // input  wire [63:0] prog_mem_rdata,     // Program memory read data (eBPF instruction)
    // output wire        prog_mem_ren,       // Program memory read enable

    // output wire [15:0] stack_mem_addr,     // Stack memory address
    // output wire [63:0] stack_mem_wdata,    // Stack memory write data
    // input  wire [63:0] stack_mem_rdata,    // Stack memory read data
    // output wire        stack_mem_wen,      // Stack memory write enable
    // output wire        stack_mem_ren,      // Stack memory read enable

    // output wire [15:0] data_mailbox_addr,  // Data mailbox memory address
    // output wire [63:0] data_mailbox_wdata, // Data mailbox write data
    // input  wire [63:0] data_mailbox_rdata, // Data mailbox read data
    // output wire        data_mailbox_wen,   // Data mailbox write enable
    // output wire        data_mailbox_ren,   // Data mailbox read enable


    // Interface to shared memory (if VM directly accesses it, alternative to CCU DMAing)
    // This would be a master interface from the VM's perspective
    // output wire [31:0] m_axi_vm_addr,
    // output wire        m_axi_vm_read,
    // input  wire [XX:0] m_axi_vm_rdata,
    // output wire        m_axi_vm_write,
    // output wire [XX:0] m_axi_vm_wdata,
    // input  wire        m_axi_vm_ready,


    // Global Clock and Reset
    input  wire         clk,
    input  wire         reset,

    // Memory Write Interface (from CCU/DMA)
    input  wire [PROG_MEM_ADDR_WIDTH-1:0] write_prog_mem_addr_i,
    input  wire [31:0]                    write_prog_mem_data_i,
    input  wire                           write_prog_mem_en_i,
    input  wire [STACK_MEM_ADDR_WIDTH-1:0]write_stack_mem_addr_i,
    input  wire [31:0]                    write_stack_mem_data_i,
    input  wire                           write_stack_mem_en_i,

    // Memory Read Interface (for eBPF interpreter)
    input  wire [PROG_MEM_ADDR_WIDTH-1:0] read_prog_mem_addr_i,  // From internal PC
    output wire [31:0]                    prog_mem_data_o,
    input  wire [STACK_MEM_ADDR_WIDTH-1:0]read_stack_mem_addr_i, // From internal SP/FP
    output wire [31:0]                    stack_mem_data_o,

    // Mailbox Interface with CCU (PicoRV32 is the master of this interface from VM side)
    // For PicoRV32 to write to its OUT Mailbox (data goes to CCU's vm_mailboxes_out)
    output wire [$clog2(NUM_MAILBOX_REGS_VM)-1:0] vm_mailbox_out_idx_o,
    output wire [31:0]                             vm_mailbox_out_wdata_o,
    output wire                                  vm_mailbox_out_wen_o,
    // For PicoRV32 to read from its IN Mailbox (data comes from CCU's vm_mailboxes_in)
    output wire [$clog2(NUM_MAILBOX_REGS_VM)-1:0] vm_mailbox_in_idx_o,
    input  wire [31:0]                             vm_mailbox_in_rdata_i
    // input wire                               vm_mailbox_in_valid_i; // Optional, from CCU
);

    localparam NUM_MAILBOX_REGS_VM = 4; // Should match NUM_MAILBOX_REGS in CCU

    // Parameters for memory sizes (32-bit wide memories)
    // eBPF instructions are 64-bit, so 2 x 32-bit words per instruction.
    // Stack also uses 64-bit words typically, so 2 x 32-bit words.
    localparam PROG_MEM_WORDS_PER_INST = 2;
    localparam STACK_WORDS_PER_ENTRY = 2;

    localparam NUM_INSTRUCTIONS = 1024; // Number of eBPF instructions
    localparam PROG_MEM_DEPTH_32BIT = NUM_INSTRUCTIONS * PROG_MEM_WORDS_PER_INST; // Depth in 32-bit words
    
    localparam STACK_ENTRIES_64BIT = 512; // Number of 64-bit stack entries
    localparam STACK_MEM_DEPTH_32BIT = STACK_ENTRIES_64BIT * STACK_WORDS_PER_ENTRY; // Depth in 32-bit words

    localparam PROG_MEM_ADDR_WIDTH = $clog2(PROG_MEM_DEPTH_32BIT);
    localparam STACK_MEM_ADDR_WIDTH = $clog2(STACK_MEM_DEPTH_32BIT);

    // PicoRV32 Nano-controller Parameters
    localparam NANO_CTRL_ENABLE_COMPRESSED = 1;
    localparam NANO_CTRL_ENABLE_MUL = 1;
    localparam NANO_CTRL_ENABLE_DIV = 0; // Keep it simple for now
    localparam NANO_CTRL_BARREL_SHIFTER = 1;
    localparam NANO_CTRL_STACKADDR_TOP = 32'h0000_0FFF; // Example, adjust based on RAM size

    // Nano-controller Instruction ROM (e.g., 8KB = 2048 32-bit words)
    localparam NANO_CTRL_ROM_SIZE_BYTES = 8 * 1024;
    localparam NANO_CTRL_ROM_WORDS_32BIT = NANO_CTRL_ROM_SIZE_BYTES / 4;
    localparam NANO_CTRL_ROM_ADDR_WIDTH = $clog2(NANO_CTRL_ROM_WORDS_32BIT);

    // Nano-controller Data RAM (e.g., 4KB = 1024 32-bit words)
    localparam NANO_CTRL_RAM_SIZE_BYTES = 4 * 1024;
    localparam NANO_CTRL_RAM_WORDS_32BIT = NANO_CTRL_RAM_SIZE_BYTES / 4;
    localparam NANO_CTRL_RAM_ADDR_WIDTH = $clog2(NANO_CTRL_RAM_WORDS_32BIT);

    // PicoRV32 Memory Map Definition
    // Nano-controller's perspective. Must be 32-byte aligned for PicoRV32 default memory interface.
    // For simplicity, ensure sizes are powers of 2 if possible and align bases.
    localparam NANO_CTRL_ROM_BASE        = 32'h0000_0000;
    localparam NANO_CTRL_ROM_END          = NANO_CTRL_ROM_BASE + NANO_CTRL_ROM_SIZE_BYTES - 1;

    localparam NANO_CTRL_RAM_BASE        = 32'h0000_2000; // Example: ROM 8KB, RAM starts after
    localparam NANO_CTRL_RAM_END          = NANO_CTRL_RAM_BASE + NANO_CTRL_RAM_SIZE_BYTES - 1;

    // Control/Status Registers for PicoRV32 interaction
    localparam NANO_CTRL_CSR_BASE        = 32'h0000_3000;
    localparam ADDR_NANO_CTRL_STATUS_REG  = NANO_CTRL_CSR_BASE + 32'h00; // For done/error flags
    localparam EBPF_MAILBOX_IN_BASE_ADDR  = NANO_CTRL_CSR_BASE + 32'h0010; // Offset 16B from CSR base
    localparam EBPF_MAILBOX_IN_END_ADDR    = EBPF_MAILBOX_IN_BASE_ADDR + (NUM_MAILBOX_REGS_VM * 4) - 1;
    localparam EBPF_MAILBOX_OUT_BASE_ADDR = NANO_CTRL_CSR_BASE + 32'h0030; // Offset 48B from CSR base (allows for 4 IN regs + spacing)
    localparam EBPF_MAILBOX_OUT_END_ADDR   = EBPF_MAILBOX_OUT_BASE_ADDR + (NUM_MAILBOX_REGS_VM * 4) - 1;
    // Add other CSRs here if needed: e.g., input data mailbox, output data mailbox addresses
    localparam NANO_CTRL_CSR_END          = NANO_CTRL_CSR_BASE + 32'h00FF; // Example 256 bytes for CSRs


    // eBPF Memories (as viewed by PicoRV32)
    // Ensure these are distinct from nano-controller's local ROM/RAM and CSRs.
    localparam EBPF_PROG_MEM_BASE_ADDR   = 32'h0100_0000;
    localparam EBPF_PROG_MEM_END_ADDR     = EBPF_PROG_MEM_BASE_ADDR + (PROG_MEM_DEPTH_32BIT * 4) - 1;

    localparam EBPF_STACK_MEM_BASE_ADDR  = 32'h0200_0000;
    localparam EBPF_STACK_MEM_END_ADDR    = EBPF_STACK_MEM_BASE_ADDR + (STACK_MEM_DEPTH_32BIT * 4) - 1;

    // Status registers written by PicoRV32, driving module outputs
    reg done_reg_r;
    reg error_reg_r;

    // Internal registers for mailbox interface driving outputs to CCU
    reg [$clog2(NUM_MAILBOX_REGS_VM)-1:0] vm_mailbox_out_idx_o_r;
    reg [31:0]                             vm_mailbox_out_wdata_o_r;
    reg                                  vm_mailbox_out_wen_o_r;
    reg [$clog2(NUM_MAILBOX_REGS_VM)-1:0] vm_mailbox_in_idx_o_r; // For PicoRV32 to select which IN mailbox reg to read

    assign vm_mailbox_out_idx_o   = vm_mailbox_out_idx_o_r;
    assign vm_mailbox_out_wdata_o = vm_mailbox_out_wdata_o_r;
    assign vm_mailbox_out_wen_o   = vm_mailbox_out_wen_o_r;
    assign vm_mailbox_in_idx_o    = vm_mailbox_in_idx_o_r;

    assign done = done_reg_r;
    assign error = error_reg_r;

    // Internal Memory Blocks
    reg [31:0] prog_mem [0:PROG_MEM_DEPTH_32BIT-1];
    reg [31:0] stack_mem [0:STACK_MEM_DEPTH_32BIT-1];

    // Nano-controller Instruction ROM and Data RAM
    reg [31:0] nano_ctrl_instr_rom [0:NANO_CTRL_ROM_WORDS_32BIT-1];
    reg [31:0] nano_ctrl_data_ram [0:NANO_CTRL_RAM_WORDS_32BIT-1];

    // PicoRV32 Interface Wires
    wire        pico_mem_valid;     // pico_mem_valid output from PicoRV32
    wire        pico_mem_instr;     // pico_mem_instr output from PicoRV32 (1 if instruction fetch)
    wire        pico_mem_ready;     // pico_mem_ready input to PicoRV32
    wire [31:0] pico_mem_addr;      // pico_mem_addr output from PicoRV32
    wire [31:0] pico_mem_wdata;     // pico_mem_wdata output from PicoRV32
    wire [3:0]  pico_mem_wstrb;     // pico_mem_wstrb output from PicoRV32
    wire [31:0] pico_mem_rdata;     // pico_mem_rdata input to PicoRV32
    wire        pico_trap;          // PicoRV32 trap signal
    wire        pico_resetn;        // Active-low reset for PicoRV32
    reg         start_vm_internal_r; // Latched start signal to keep PicoRV32 running

    // PicoRV32 Reset Logic
    // PicoRV32 is reset if:
    //  - reset_vm (global eBPF_VM_Slot reset) is active
    //  - stop_vm (from CCU) is active
    //  - start_vm_internal_r (latched start) is not active
    assign pico_resetn = !reset_vm && !stop_vm && start_vm_internal_r;

    always @(posedge clk or posedge reset_vm) begin
        if (reset_vm) begin
            start_vm_internal_r <= 1'b0;
            vm_mailbox_out_wen_o_r <= 1'b0;
            vm_mailbox_out_idx_o_r <= 0;
            vm_mailbox_out_wdata_o_r <= 0;
            vm_mailbox_in_idx_o_r <= 0; // Reset this here
        end else begin
            // Default assignments for pulsed/updated signals
            vm_mailbox_out_wen_o_r <= 1'b0;
            // vm_mailbox_in_idx_o_r retains its value unless Pico accesses IN mailbox

            if (start_vm) begin
                start_vm_internal_r <= 1'b1;
            end else if (stop_vm) begin // stop_vm also clears the latched start
                start_vm_internal_r <= 1'b0;
            end

            // Update vm_mailbox_in_idx_o_r when PicoRV32 reads from IN Mailbox region
            if (pico_mem_valid && (pico_mem_addr >= EBPF_MAILBOX_IN_BASE_ADDR && pico_mem_addr <= EBPF_MAILBOX_IN_END_ADDR)) begin
                automatic logic [$clog2(NUM_MAILBOX_REGS_VM)-1:0] calculated_idx;
                calculated_idx = (pico_mem_addr - EBPF_MAILBOX_IN_BASE_ADDR) >> 2;
                if (calculated_idx < NUM_MAILBOX_REGS_VM) begin
                    vm_mailbox_in_idx_o_r <= calculated_idx;
                end
                // If out of bounds, vm_mailbox_in_idx_o_r retains previous value or can be set to an error/default.
                // CCU side should also check bounds.
            end
            // PicoRV32 driven mailbox outputs (vm_mailbox_out_*) are handled in the main memory write block below
        end
    end

    // PicoRV32 Nano-controller Instantiation
    picorv32 #(
        .PROGADDR_RESET             (32'h0000_0000), // Start of Nano-controller ROM
        .PROGADDR_IRQ               (32'h0000_0010), // Placeholder, IRQ not used
        .STACKADDR                  (NANO_CTRL_STACKADDR_TOP),
        .ENABLE_COMPRESSED          (NANO_CTRL_ENABLE_COMPRESSED),
        .ENABLE_MUL                 (NANO_CTRL_ENABLE_MUL),
        .ENABLE_DIV                 (NANO_CTRL_ENABLE_DIV),
        .BARREL_SHIFTER             (NANO_CTRL_BARREL_SHIFTER),
        .ENABLE_FAST_VERILATOR_SIM  (0), // For synthesis
        // Keep other parameters at their default values unless specific needs arise
        .ENABLE_IRQ                 (0),
        .ENABLE_IRQ_TIMER           (0),
        .ENABLE_TRACE               (0),
        .ENABLE_PCPI                (0)
    ) picorv32_inst (
        .clk                        (clk),
        .resetn                     (pico_resetn),

        .mem_valid                  (pico_mem_valid),
        .mem_instr                  (pico_mem_instr),
        .mem_ready                  (pico_mem_ready),
        .mem_addr                   (pico_mem_addr),
        .mem_wdata                  (pico_mem_wdata),
        .mem_wstrb                  (pico_mem_wstrb),
        .mem_rdata                  (pico_mem_rdata),

        .pcpi_valid                 (1'b0), // Tie off PCPI
        .pcpi_insn                  (32'b0),
        .pcpi_rs1                   (32'b0),
        .pcpi_rs2                   (32'b0),
        .pcpi_wr                    (1'b0),
        .pcpi_rd                    (),
        .pcpi_wait                  (1'b0),
        .pcpi_ready                 (),

        .irq                        (32'b0), // Tie off IRQ
        .eoi                        (32'b0),

        .trap                       (pico_trap), // Trap signal from PicoRV32

        .trace_valid                (), // Tie off trace
        .trace_data                 ()
        // .timer // Deprecated in recent PicoRV32 versions
    );

    // Internal eBPF VM components (conceptual - to be implemented later)
    // - Program Counter (PC)
    // - General Purpose Registers (R0-R10)
    // - ALU
    // - Control Logic / State Machine
    // - Memory Interface Logic for eBPF execution

    // Placeholder for status outputs
    assign ready = 1'b1; // Default to ready, actual logic needed
    assign done = 1'b0;  // To be driven by eBPF interpreter
    assign error = 1'b0; // To be driven by eBPF interpreter
    assign data_out_available_address = 32'b0; // To be driven by eBPF interpreter

    // Memory Write Logic (from CCU/DMA for eBPF prog_mem and stack_mem, and from PicoRV32)
    always @(posedge clk) begin
        // Reset for status registers controlled by PicoRV32
        if (reset_vm || stop_vm) begin // Also clear on stop_vm to signify end of run
            done_reg_r <= 1'b0;
            error_reg_r <= 1'b0;
        end

        // Writes from CCU DMA to eBPF Program Memory
        if (write_prog_mem_en_i) begin
            if (write_prog_mem_addr_i < PROG_MEM_DEPTH_32BIT) begin 
                prog_mem[write_prog_mem_addr_i] <= write_prog_mem_data_i;
            end
        end
        // Writes from CCU DMA to eBPF Stack Memory (if ever implemented, currently not used by CCU)
        if (write_stack_mem_en_i) begin
            if (write_stack_mem_addr_i < STACK_MEM_DEPTH_32BIT) begin 
                stack_mem[write_stack_mem_addr_i] <= write_stack_mem_data_i;
            end
        end

        // Writes from PicoRV32
        if (pico_mem_valid && pico_mem_ready && !pico_mem_instr && |pico_mem_wstrb) begin
            // Nano-controller RAM Write
            if (pico_mem_addr >= NANO_CTRL_RAM_BASE && pico_mem_addr <= NANO_CTRL_RAM_END) begin
                automatic logic [NANO_CTRL_RAM_ADDR_WIDTH-1:0] ram_addr_offset_w;
                ram_addr_offset_w = (pico_mem_addr - NANO_CTRL_RAM_BASE) >> 2;
                if (ram_addr_offset_w < NANO_CTRL_RAM_WORDS_32BIT) begin
                    if (pico_mem_wstrb[0]) nano_ctrl_data_ram[ram_addr_offset_w][7:0]   <= pico_mem_wdata[7:0];
                    if (pico_mem_wstrb[1]) nano_ctrl_data_ram[ram_addr_offset_w][15:8]  <= pico_mem_wdata[15:8];
                    if (pico_mem_wstrb[2]) nano_ctrl_data_ram[ram_addr_offset_w][23:16] <= pico_mem_wdata[23:16];
                    if (pico_mem_wstrb[3]) nano_ctrl_data_ram[ram_addr_offset_w][31:24] <= pico_mem_wdata[31:24];
                end
            end
            // eBPF Stack Memory Write
            else if (pico_mem_addr >= EBPF_STACK_MEM_BASE_ADDR && pico_mem_addr <= EBPF_STACK_MEM_END_ADDR) begin
                automatic logic [STACK_MEM_ADDR_WIDTH-1:0] stack_addr_offset_w;
                stack_addr_offset_w = (pico_mem_addr - EBPF_STACK_MEM_BASE_ADDR) >> 2;
                if (stack_addr_offset_w < STACK_MEM_DEPTH_32BIT) begin
                    if (pico_mem_wstrb[0]) stack_mem[stack_addr_offset_w][7:0]   <= pico_mem_wdata[7:0];
                    if (pico_mem_wstrb[1]) stack_mem[stack_addr_offset_w][15:8]  <= pico_mem_wdata[15:8];
                    if (pico_mem_wstrb[2]) stack_mem[stack_addr_offset_w][23:16] <= pico_mem_wdata[23:16];
                    if (pico_mem_wstrb[3]) stack_mem[stack_addr_offset_w][31:24] <= pico_mem_wdata[31:24];
                end
            end
            // Status Register Write
            else if (pico_mem_addr == ADDR_NANO_CTRL_STATUS_REG) begin
                // Assuming done is bit 0, error is bit 1, written via the LSB of wdata
                if (pico_mem_wstrb[0]) begin // Check if the byte containing flags is being written
                    done_reg_r  <= pico_mem_wdata[0];
                    error_reg_r <= pico_mem_wdata[1];
                end
            end
            // eBPF OUT Mailbox Write (PicoRV32 writes to CCU)
            else if (pico_mem_addr >= EBPF_MAILBOX_OUT_BASE_ADDR && pico_mem_addr <= EBPF_MAILBOX_OUT_END_ADDR) begin
                automatic logic [$clog2(NUM_MAILBOX_REGS_VM)-1:0] mailbox_idx_clk;
                mailbox_idx_clk = (pico_mem_addr - EBPF_MAILBOX_OUT_BASE_ADDR) >> 2;
                if (mailbox_idx_clk < NUM_MAILBOX_REGS_VM) begin
                    vm_mailbox_out_idx_o_r   <= mailbox_idx_clk;
                    vm_mailbox_out_wdata_o_r <= pico_mem_wdata;
                    vm_mailbox_out_wen_o_r   <= 1'b1; // Pulsed by default assignment at start of clocked block
                end
                // Else: Write to out-of-bounds mailbox index is ignored
            end
        end
    end

    // PicoRV32 Memory Interface Logic (Combinatorial Read Path)
    // pico_mem_ready and pico_mem_rdata are outputs to PicoRV32
    // Default to not ready and zero data.
    reg pico_mem_ready_comb;
    reg [31:0] pico_mem_rdata_comb;

    always_comb begin
        pico_mem_ready_comb = 1'b0;
        pico_mem_rdata_comb = 32'h0; 
        automatic logic [$clog2(NUM_MAILBOX_REGS_VM)-1:0] calculated_vm_mailbox_in_idx_comb; // Renamed for clarity
        calculated_vm_mailbox_in_idx_comb = vm_mailbox_in_idx_o_r; // Default to current value or reset value

        if (pico_mem_valid) begin
            // Nano-controller ROM Read
            if (pico_mem_addr >= NANO_CTRL_ROM_BASE && pico_mem_addr <= NANO_CTRL_ROM_END) begin
                automatic logic [NANO_CTRL_ROM_ADDR_WIDTH-1:0] rom_addr_offset_c;
                rom_addr_offset_c = (pico_mem_addr - NANO_CTRL_ROM_BASE) >> 2; 
                if (rom_addr_offset_c < NANO_CTRL_ROM_WORDS_32BIT) begin
                    pico_mem_rdata_comb = nano_ctrl_instr_rom[rom_addr_offset_c];
                    pico_mem_ready_comb = 1'b1;
                end else { 
                    pico_mem_rdata_comb = 32'hDEADBEEF; 
                    pico_mem_ready_comb = 1'b1; 
                }
            end
            // Nano-controller RAM Read
            else if (pico_mem_addr >= NANO_CTRL_RAM_BASE && pico_mem_addr <= NANO_CTRL_RAM_END) begin
                automatic logic [NANO_CTRL_RAM_ADDR_WIDTH-1:0] ram_addr_offset_c;
                ram_addr_offset_c = (pico_mem_addr - NANO_CTRL_RAM_BASE) >> 2;
                 if (ram_addr_offset_c < NANO_CTRL_RAM_WORDS_32BIT) begin
                    pico_mem_rdata_comb = nano_ctrl_data_ram[ram_addr_offset_c];
                    pico_mem_ready_comb = 1'b1;
                end else {
                    pico_mem_rdata_comb = 32'hDEADBEEF;
                    pico_mem_ready_comb = 1'b1;
                }
            end
            // eBPF Program Memory Read
            else if (pico_mem_addr >= EBPF_PROG_MEM_BASE_ADDR && pico_mem_addr <= EBPF_PROG_MEM_END_ADDR) begin
                automatic logic [PROG_MEM_ADDR_WIDTH-1:0] prog_mem_offset_c;
                prog_mem_offset_c = (pico_mem_addr - EBPF_PROG_MEM_BASE_ADDR) >> 2;
                if (prog_mem_offset_c < PROG_MEM_DEPTH_32BIT) begin
                    pico_mem_rdata_comb = prog_mem[prog_mem_offset_c];
                    pico_mem_ready_comb = 1'b1;
                end else {
                    pico_mem_rdata_comb = 32'hDEADBEEF;
                    pico_mem_ready_comb = 1'b1;
                }
            end
            // eBPF Stack Memory Read
            else if (pico_mem_addr >= EBPF_STACK_MEM_BASE_ADDR && pico_mem_addr <= EBPF_STACK_MEM_END_ADDR) begin
                automatic logic [STACK_MEM_ADDR_WIDTH-1:0] stack_mem_offset_c;
                stack_mem_offset_c = (pico_mem_addr - EBPF_STACK_MEM_BASE_ADDR) >> 2;
                if (stack_mem_offset_c < STACK_MEM_DEPTH_32BIT) begin
                    pico_mem_rdata_comb = stack_mem[stack_mem_offset_c];
                    pico_mem_ready_comb = 1'b1;
                end else {
                    pico_mem_rdata_comb = 32'hDEADBEEF;
                    pico_mem_ready_comb = 1'b1;
                }
            end
            // Status Register Read
            else if (pico_mem_addr == ADDR_NANO_CTRL_STATUS_REG) begin
                pico_mem_rdata_comb = {30'b0, error_reg_r, done_reg_r};
                pico_mem_ready_comb = 1'b1;
            end
            // eBPF IN Mailbox Read (PicoRV32 reads from CCU)
            else if (pico_mem_addr >= EBPF_MAILBOX_IN_BASE_ADDR && pico_mem_addr <= EBPF_MAILBOX_IN_END_ADDR) begin
                calculated_vm_mailbox_in_idx_comb = (pico_mem_addr - EBPF_MAILBOX_IN_BASE_ADDR) >> 2;
                if (calculated_vm_mailbox_in_idx_comb < NUM_MAILBOX_REGS_VM) begin
                    pico_mem_rdata_comb = vm_mailbox_in_rdata_i; // Data comes from CCU
                    pico_mem_ready_comb = 1'b1; // Assume CCU provides data timely
                end else {
                    pico_mem_rdata_comb = 32'hBADBAD04; // Index out of bounds for IN mbox
                    pico_mem_ready_comb = 1'b1;
                }
            end
            else begin // Address out of any defined range
                pico_mem_rdata_comb = 32'hDEADDEAD; 
                pico_mem_ready_comb = 1'b1; 
            end
        end
        // Assign the calculated index to the output register (or directly to output if it's a wire)
        // This needs to be assigned carefully. If vm_mailbox_in_idx_o_r is a reg, it should be assigned in a clocked block.
        // If vm_mailbox_in_idx_o is a wire assigned from this comb block, then it's:
        // assign vm_mailbox_in_idx_o = (pico_mem_valid && pico_mem_addr >= EBPF_MAILBOX_IN_BASE_ADDR && ... ) ? calculated_vm_mailbox_in_idx_comb : <default_val>;
        // For now, vm_mailbox_in_idx_o_r is a reg, so this combinatorial assignment is problematic.
        // Let's assume vm_mailbox_in_idx_o_r is updated in the clocked block when pico reads this region.
        // For combinatorial output, vm_mailbox_in_idx_o needs to be a wire.
        // Reverting to direct assignment for now as vm_mailbox_in_idx_o_r is a reg.
        // vm_mailbox_in_idx_o_r <= calculated_vm_mailbox_in_idx_comb; // This line will be moved or handled differently
    end
    assign pico_mem_ready = pico_mem_ready_comb;
    assign pico_mem_rdata = pico_mem_rdata_comb;

    // Memory Read Logic (for eBPF interpreter - these ports become unused by external, now used by Pico)
    // The PicoRV32 directly accesses prog_mem and stack_mem via its memory bus.
    // The ports read_prog_mem_addr_i, prog_mem_data_o, etc. are thus not needed for PicoRV32 operation.
    // If these ports were intended for debugging or external access while PicoRV32 is halted,
    // then additional muxing logic would be required. For now, they are effectively superseded.
    // To avoid synthesis warnings about undriven outputs if they were part of an interface,
    // we can assign them default values, but they are not functionally used by PicoRV32.
    assign prog_mem_data_o = 32'h0; // Or connect to a debug/test interface if needed
    assign stack_mem_data_o = 32'h0; // Or connect to a debug/test interface if needed

endmodule
