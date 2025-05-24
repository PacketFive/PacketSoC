// AXI Interconnect Module Stub
// Date: 2024-03-14

`timescale 1ns / 1ps

module AXI_Interconnect (
    input  wire         clk,
    input  wire         resetn, // Assuming active low reset for consistency

    // --- Master Port 0: CVA6 CPU (AXI4 Full) ---
    // Write Address Channel
    input  wire [31:0]  M0_AXI_AWADDR,
    input  wire [7:0]   M0_AXI_AWLEN,   // Max 256 beats
    input  wire [2:0]   M0_AXI_AWSIZE,  // Up to 1024-bit data bus (2^7)
    input  wire [1:0]   M0_AXI_AWBURST,
    input  wire         M0_AXI_AWLOCK,
    input  wire [3:0]   M0_AXI_AWCACHE,
    input  wire [2:0]   M0_AXI_AWPROT,
    input  wire [3:0]   M0_AXI_AWREGION, // Optional AXI4 region identifier
    input  wire [3:0]   M0_AXI_AWQOS,    // Optional AXI4 QoS identifier
    input  wire         M0_AXI_AWVALID,
    output wire         M0_AXI_AWREADY,
    // Write Data Channel
    input  wire [31:0]  M0_AXI_WDATA,   // Assuming 32-bit data bus for CPU
    input  wire [3:0]   M0_AXI_WSTRB,   // (DATA_WIDTH/8)-1 : 0
    input  wire         M0_AXI_WLAST,
    input  wire         M0_AXI_WVALID,
    output wire         M0_AXI_WREADY,
    // Write Response Channel
    output wire [1:0]   M0_AXI_BRESP,
    output wire         M0_AXI_BVALID,
    input  wire         M0_AXI_BREADY,
    // Read Address Channel
    input  wire [31:0]  M0_AXI_ARADDR,
    input  wire [7:0]   M0_AXI_ARLEN,
    input  wire [2:0]   M0_AXI_ARSIZE,
    input  wire [1:0]   M0_AXI_ARBURST,
    input  wire         M0_AXI_ARLOCK,
    input  wire [3:0]   M0_AXI_ARCACHE,
    input  wire [2:0]   M0_AXI_ARPROT,
    input  wire [3:0]   M0_AXI_ARREGION,
    input  wire [3:0]   M0_AXI_ARQOS,
    input  wire         M0_AXI_ARVALID,
    output wire         M0_AXI_ARREADY,
    // Read Data Channel
    output wire [31:0]  M0_AXI_RDATA,
    output wire [1:0]   M0_AXI_RRESP,
    output wire         M0_AXI_RLAST,
    output wire         M0_AXI_RVALID,
    input  wire         M0_AXI_RREADY,

    // --- Master Port 1: Keystone Coprocessor DMA (AXI4 Full) ---
    // Write Address Channel
    input  wire [31:0]  M1_AXI_AWADDR,
    input  wire [7:0]   M1_AXI_AWLEN,
    input  wire [2:0]   M1_AXI_AWSIZE,
    input  wire [1:0]   M1_AXI_AWBURST,
    input  wire         M1_AXI_AWLOCK,  // Optional
    input  wire [3:0]   M1_AXI_AWCACHE, // Optional
    input  wire [2:0]   M1_AXI_AWPROT,  // Optional
    input  wire         M1_AXI_AWVALID,
    output wire         M1_AXI_AWREADY,
    // Write Data Channel
    input  wire [31:0]  M1_AXI_WDATA,   // Assuming 32-bit data bus for DMA
    input  wire [3:0]   M1_AXI_WSTRB,
    input  wire         M1_AXI_WLAST,
    input  wire         M1_AXI_WVALID,
    output wire         M1_AXI_WREADY,
    // Write Response Channel
    output wire [1:0]   M1_AXI_BRESP,
    output wire         M1_AXI_BVALID,
    input  wire         M1_AXI_BREADY,
    // Read Address Channel
    input  wire [31:0]  M1_AXI_ARADDR,
    input  wire [7:0]   M1_AXI_ARLEN,
    input  wire [2:0]   M1_AXI_ARSIZE,
    input  wire [1:0]   M1_AXI_ARBURST,
    input  wire         M1_AXI_ARLOCK,  // Optional
    input  wire [3:0]   M1_AXI_ARCACHE, // Optional
    input  wire [2:0]   M1_AXI_ARPROT,  // Optional
    input  wire         M1_AXI_ARVALID,
    output wire         M1_AXI_ARREADY,
    // Read Data Channel
    output wire [31:0]  M1_AXI_RDATA,
    output wire [1:0]   M1_AXI_RRESP,
    output wire         M1_AXI_RLAST,
    output wire         M1_AXI_RVALID,
    input  wire         M1_AXI_RREADY,

    // --- Slave Port 0: Main Memory (AXI4 Full) ---
    // Write Address Channel
    output wire [31:0]  S0_AXI_AWADDR,
    output wire [7:0]   S0_AXI_AWLEN,
    output wire [2:0]   S0_AXI_AWSIZE,
    output wire [1:0]   S0_AXI_AWBURST,
    output wire         S0_AXI_AWLOCK,
    output wire [3:0]   S0_AXI_AWCACHE,
    output wire [2:0]   S0_AXI_AWPROT,
    output wire [3:0]   S0_AXI_AWREGION,
    output wire [3:0]   S0_AXI_AWQOS,
    output wire         S0_AXI_AWVALID,
    input  wire         S0_AXI_AWREADY,
    // Write Data Channel
    output wire [31:0]  S0_AXI_WDATA,
    output wire [3:0]   S0_AXI_WSTRB,
    output wire         S0_AXI_WLAST,
    output wire         S0_AXI_WVALID,
    input  wire         S0_AXI_WREADY,
    // Write Response Channel
    input  wire [1:0]   S0_AXI_BRESP,
    input  wire         S0_AXI_BVALID,
    output wire         S0_AXI_BREADY,
    // Read Address Channel
    output wire [31:0]  S0_AXI_ARADDR,
    output wire [7:0]   S0_AXI_ARLEN,
    output wire [2:0]   S0_AXI_ARSIZE,
    output wire [1:0]   S0_AXI_ARBURST,
    output wire         S0_AXI_ARLOCK,
    output wire [3:0]   S0_AXI_ARCACHE,
    output wire [2:0]   S0_AXI_ARPROT,
    output wire [3:0]   S0_AXI_ARREGION,
    output wire [3:0]   S0_AXI_ARQOS,
    output wire         S0_AXI_ARVALID,
    input  wire         S0_AXI_ARREADY,
    // Read Data Channel
    input  wire [31:0]  S0_AXI_RDATA,
    input  wire [1:0]   S0_AXI_RRESP,
    input  wire         S0_AXI_RLAST,
    input  wire         S0_AXI_RVALID,
    output wire         S0_AXI_RREADY,

    // --- Slave Port 1: Keystone Coprocessor CSRs (AXI4-Lite) ---
    // Write Address Channel
    output wire [31:0]  S1_AXI_AWADDR, // Address width from memory map (e.g. 12 bits for 4KB)
    output wire [2:0]   S1_AXI_AWPROT, // Optional for AXI-Lite
    output wire         S1_AXI_AWVALID,
    input  wire         S1_AXI_AWREADY,
    // Write Data Channel
    output wire [31:0]  S1_AXI_WDATA,
    output wire [3:0]   S1_AXI_WSTRB,
    output wire         S1_AXI_WVALID,
    input  wire         S1_AXI_WREADY,
    // Write Response Channel
    input  wire [1:0]   S1_AXI_BRESP,
    input  wire         S1_AXI_BVALID,
    output wire         S1_AXI_BREADY,
    // Read Address Channel
    output wire [31:0]  S1_AXI_ARADDR,
    output wire [2:0]   S1_AXI_ARPROT, // Optional for AXI-Lite
    output wire         S1_AXI_ARVALID,
    input  wire         S1_AXI_ARREADY,
    // Read Data Channel
    input  wire [31:0]  S1_AXI_RDATA,
    input  wire [1:0]   S1_AXI_RRESP,
    input  wire         S1_AXI_RVALID,
    output wire         S1_AXI_RREADY,

    // --- Slave Port 2: Generic Peripherals (AXI4-Lite) ---
    // Write Address Channel
    output wire [31:0]  S2_AXI_AWADDR, // Address width from memory map (e.g. 16 bits for 64KB)
    output wire [2:0]   S2_AXI_AWPROT,
    output wire         S2_AXI_AWVALID,
    input  wire         S2_AXI_AWREADY,
    // Write Data Channel
    output wire [31:0]  S2_AXI_WDATA,
    output wire [3:0]   S2_AXI_WSTRB,
    output wire         S2_AXI_WVALID,
    input  wire         S2_AXI_WREADY,
    // Write Response Channel
    input  wire [1:0]   S2_AXI_BRESP,
    input  wire         S2_AXI_BVALID,
    output wire         S2_AXI_BREADY,
    // Read Address Channel
    output wire [31:0]  S2_AXI_ARADDR,
    output wire [2:0]   S2_AXI_ARPROT,
    output wire         S2_AXI_ARVALID,
    input  wire         S2_AXI_ARREADY,
    // Read Data Channel
    input  wire [31:0]  S2_AXI_RDATA,
    input  wire [1:0]   S2_AXI_RRESP,
    input  wire         S2_AXI_RVALID,
    output wire         S2_AXI_RREADY

    // Boot ROM is not connected via this interconnect in this example
    // It's assumed to be handled by CPU's dedicated boot mechanism or a separate simpler bus.
);
    // Define AXI constants (if not already defined elsewhere, e.g. in a package)
    localparam AXI_RESP_OKAY   = 2'b00;
    localparam AXI_RESP_EXOKAY = 2'b01; // Not typically used by slaves, but defined
    localparam AXI_RESP_SLVERR = 2'b10;
    localparam AXI_RESP_DECERR = 2'b11;

    // Memory Map Parameters from SoC_Memory_Map.txt
    // Slave 0: Main Memory (S0)
    localparam S0_BASE_ADDR = 32'h8000_0000;
    localparam S0_END_ADDR  = 32'hBFFF_FFFF;

    // Slave 1: Keystone Coprocessor CSRs (S1)
    localparam S1_BASE_ADDR = 32'h1000_0000;
    localparam S1_END_ADDR  = 32'h1000_0FFF;

    // Slave 2: Generic Peripherals (S2)
    localparam S2_BASE_ADDR = 32'h0200_0000;
    localparam S2_END_ADDR  = 32'h0200_FFFF;
    // Note: Boot ROM (0x0001_0000) is not handled by this interconnect in this design.

    // Number of Slaves
    localparam NUM_SLAVES = 3;

    // --- Internal Wires and Registers ---

    // Address Decoding Logic Outputs
    // For Master 0 (CPU)
    wire m0_aw_select_s0_w, m0_aw_select_s1_w, m0_aw_select_s2_w;
    wire m0_ar_select_s0_w, m0_ar_select_s1_w, m0_ar_select_s2_w;
    wire m0_aw_addr_error_w, m0_ar_addr_error_w;

    // For Master 1 (Keystone DMA) - Assumed to only target Main Memory (S0) or cause error
    wire m1_aw_select_s0_w;
    wire m1_ar_select_s0_w;
    wire m1_aw_addr_error_w, m1_ar_addr_error_w;

    // --- Address Decoding Logic ---

    // Master 0 Address Decoder (CPU)
    assign m0_aw_select_s0_w = (M0_AXI_AWADDR >= S0_BASE_ADDR && M0_AXI_AWADDR <= S0_END_ADDR);
    assign m0_aw_select_s1_w = (M0_AXI_AWADDR >= S1_BASE_ADDR && M0_AXI_AWADDR <= S1_END_ADDR);
    assign m0_aw_select_s2_w = (M0_AXI_AWADDR >= S2_BASE_ADDR && M0_AXI_AWADDR <= S2_END_ADDR);
    assign m0_aw_addr_error_w = M0_AXI_AWVALID && !(m0_aw_select_s0_w || m0_aw_select_s1_w || m0_aw_select_s2_w);

    assign m0_ar_select_s0_w = (M0_AXI_ARADDR >= S0_BASE_ADDR && M0_AXI_ARADDR <= S0_END_ADDR);
    assign m0_ar_select_s1_w = (M0_AXI_ARADDR >= S1_BASE_ADDR && M0_AXI_ARADDR <= S1_END_ADDR);
    assign m0_ar_select_s2_w = (M0_AXI_ARADDR >= S2_BASE_ADDR && M0_AXI_ARADDR <= S2_END_ADDR);
    assign m0_ar_addr_error_w = M0_AXI_ARVALID && !(m0_ar_select_s0_w || m0_ar_select_s1_w || m0_ar_select_s2_w);

    // Master 1 Address Decoder (Keystone DMA)
    // Assuming M1 only targets S0 (Main Memory). Other accesses are errors.
    assign m1_aw_select_s0_w = (M1_AXI_AWADDR >= S0_BASE_ADDR && M1_AXI_AWADDR <= S0_END_ADDR);
    assign m1_aw_addr_error_w = M1_AXI_AWVALID && !m1_aw_select_s0_w;

    assign m1_ar_select_s0_w = (M1_AXI_ARADDR >= S0_BASE_ADDR && M1_AXI_ARADDR <= S0_END_ADDR);
    assign m1_ar_addr_error_w = M1_AXI_ARVALID && !m1_ar_select_s0_w;


    // --- Arbitration Logic for S0 (Main Memory) ---
    // S0 can be accessed by M0 (CPU) or M1 (DMA)
    // For simplicity: Fixed priority to M1 (DMA) over M0 (CPU) if simultaneous.
    // A more robust arbiter (e.g., round-robin) would be better for fairness.
    
    // Write Channel Arbitration for S0
    wire s0_aw_req_m0 = m0_aw_select_s0_w && M0_AXI_AWVALID;
    wire s0_aw_req_m1 = m1_aw_select_s0_w && M1_AXI_AWVALID;
    reg  s0_aw_granted_m0_r; // Grant for M0 to S0 AW channel
    reg  s0_aw_granted_m1_r; // Grant for M1 to S0 AW channel

    // Read Channel Arbitration for S0
    wire s0_ar_req_m0 = m0_ar_select_s0_w && M0_AXI_ARVALID;
    wire s0_ar_req_m1 = m1_ar_select_s0_w && M1_AXI_ARVALID;
    reg  s0_ar_granted_m0_r; // Grant for M0 to S0 AR channel
    reg  s0_ar_granted_m1_r; // Grant for M1 to S0 AR channel

    // Simplified fixed priority arbiter (M1 > M0 for S0)
    // -- To be replaced with Round Robin --
    reg s0_arb_rr_last_grant_r; // 0 for M0, 1 for M1
    localparam M0_GRANT = 1'b0;
    localparam M1_GRANT = 1'b1;

    // AW Channel for S0 - Round Robin
    always @(posedge clk or negedge resetn) begin
        if (!resetn) begin
            s0_aw_granted_m0_r <= 1'b0;
            s0_aw_granted_m1_r <= 1'b0;
            s0_arb_rr_last_grant_r <= M1_GRANT; // M1 is higher priority initially or after M0
        end else begin
            if (!s0_aw_granted_m0_r && !s0_aw_granted_m1_r) { // If S0 is free
                if (s0_arb_rr_last_grant_r == M1_GRANT) { // Last was M1, try M0
                    if (s0_aw_req_m0) { s0_aw_granted_m0_r <= 1'b1; s0_arb_rr_last_grant_r <= M0_GRANT; }
                    else if (s0_aw_req_m1) { s0_aw_granted_m1_r <= 1'b1; s0_arb_rr_last_grant_r <= M1_GRANT; }
                } else { // Last was M0, try M1
                    if (s0_aw_req_m1) { s0_aw_granted_m1_r <= 1'b1; s0_arb_rr_last_grant_r <= M1_GRANT; }
                    else if (s0_aw_req_m0) { s0_aw_granted_m0_r <= 1'b1; s0_arb_rr_last_grant_r <= M0_GRANT; }
                }
            } else if (S0_AXI_AWREADY) { // Current transaction finishing for granted master
                if (s0_aw_granted_m0_r) s0_aw_granted_m0_r <= 1'b0;
                if (s0_aw_granted_m1_r) s0_aw_granted_m1_r <= 1'b0;
                // Immediately check for next grant in next cycle based on new priority
                if (s0_arb_rr_last_grant_r == M0_GRANT) { // If M0 just finished, M1 gets priority
                    if (s0_aw_req_m1) { s0_aw_granted_m1_r <= 1'b1; s0_arb_rr_last_grant_r <= M1_GRANT; }
                    else if (s0_aw_req_m0) { s0_aw_granted_m0_r <= 1'b1; s0_arb_rr_last_grant_r <= M0_GRANT; }
                } else { // M1 just finished (or was initial state), M0 gets priority
                    if (s0_aw_req_m0) { s0_aw_granted_m0_r <= 1'b1; s0_arb_rr_last_grant_r <= M0_GRANT; }
                    else if (s0_aw_req_m1) { s0_aw_granted_m1_r <= 1'b1; s0_arb_rr_last_grant_r <= M1_GRANT; }
                }
            }
            // else grant holds
        end
    end

    // AR Channel for S0 - Round Robin (similar logic to AW)
    reg s0_ar_arb_rr_last_grant_r;
    always @(posedge clk or negedge resetn) begin
        if (!resetn) begin
            s0_ar_granted_m0_r <= 1'b0;
            s0_ar_granted_m1_r <= 1'b0;
            s0_ar_arb_rr_last_grant_r <= M1_GRANT;
        end else begin
            if (!s0_ar_granted_m0_r && !s0_ar_granted_m1_r) { // If S0 is free
                if (s0_ar_arb_rr_last_grant_r == M1_GRANT) {
                    if (s0_ar_req_m0) { s0_ar_granted_m0_r <= 1'b1; s0_ar_arb_rr_last_grant_r <= M0_GRANT; }
                    else if (s0_ar_req_m1) { s0_ar_granted_m1_r <= 1'b1; s0_ar_arb_rr_last_grant_r <= M1_GRANT; }
                } else {
                    if (s0_ar_req_m1) { s0_ar_granted_m1_r <= 1'b1; s0_ar_arb_rr_last_grant_r <= M1_GRANT; }
                    else if (s0_ar_req_m0) { s0_ar_granted_m0_r <= 1'b1; s0_ar_arb_rr_last_grant_r <= M0_GRANT; }
                }
            } else if (S0_AXI_ARREADY) { // Current transaction finishing
                if (s0_ar_granted_m0_r) s0_ar_granted_m0_r <= 1'b0;
                if (s0_ar_granted_m1_r) s0_ar_granted_m1_r <= 1'b0;
                if (s0_ar_arb_rr_last_grant_r == M0_GRANT) {
                    if (s0_ar_req_m1) { s0_ar_granted_m1_r <= 1'b1; s0_ar_arb_rr_last_grant_r <= M1_GRANT; }
                    else if (s0_ar_req_m0) { s0_ar_granted_m0_r <= 1'b1; s0_ar_arb_rr_last_grant_r <= M0_GRANT; }
                } else {
                    if (s0_ar_req_m0) { s0_ar_granted_m0_r <= 1'b1; s0_ar_arb_rr_last_grant_r <= M0_GRANT; }
                    else if (s0_ar_req_m1) { s0_ar_granted_m1_r <= 1'b1; s0_ar_arb_rr_last_grant_r <= M1_GRANT; }
                }
            }
        end
    end

    // --- DECERR Generation State Machines (per master port, per channel type) ---
    localparam DECERR_IDLE = 0, DECERR_RESP = 1;

    // M0 AW DECERR
    reg m0_aw_decerr_state_r;
    reg m0_aw_decerr_bvalid_r;
    // M0 AR DECERR
    reg m0_ar_decerr_state_r;
    reg m0_ar_decerr_rvalid_r;
    // M1 AW DECERR
    reg m1_aw_decerr_state_r;
    reg m1_aw_decerr_bvalid_r;
    // M1 AR DECERR
    reg m1_ar_decerr_state_r;
    reg m1_ar_decerr_rvalid_r;


    // --- AXI Signal Multiplexing and Routing ---
    // This section combines the logic from the previous attempt to connect master to slave
    // and slave to master, including DECERR handling.

    // --- Slave Port Signals (Inputs to Slaves, Outputs from Interconnect) ---

    // S0 (Main Memory) - Arbitrated between M0 and M1
    assign S0_AXI_AWADDR   = s0_aw_granted_m1_r ? M1_AXI_AWADDR  : M0_AXI_AWADDR; // If M1 granted, use M1, else M0 (implicitly if M0 granted)
    assign S0_AXI_AWLEN    = s0_aw_granted_m1_r ? M1_AXI_AWLEN   : M0_AXI_AWLEN;
    assign S0_AXI_AWSIZE   = s0_aw_granted_m1_r ? M1_AXI_AWSIZE  : M0_AXI_AWSIZE;
    assign S0_AXI_AWBURST  = s0_aw_granted_m1_r ? M1_AXI_AWBURST  : M0_AXI_AWBURST;
    assign S0_AXI_AWLOCK   = s0_aw_granted_m1_r ? M1_AXI_AWLOCK   : M0_AXI_AWLOCK;  // M1 stub might not have AWLOCK
    assign S0_AXI_AWCACHE  = s0_aw_granted_m1_r ? M1_AXI_AWCACHE  : M0_AXI_AWCACHE; // M1 stub might not have AWCACHE
    assign S0_AXI_AWPROT   = s0_aw_granted_m1_r ? M1_AXI_AWPROT   : M0_AXI_AWPROT;
    assign S0_AXI_AWREGION = s0_aw_granted_m0_r ? M0_AXI_AWREGION : 4'b0; // Assuming M1 does not use region
    assign S0_AXI_AWQOS    = s0_aw_granted_m0_r ? M0_AXI_AWQOS    : 4'b0; // Assuming M1 does not use QOS
    assign S0_AXI_AWVALID  = (s0_aw_granted_m0_r && M0_AXI_AWVALID && m0_aw_select_s0_w && (m0_aw_decerr_state_r == DECERR_IDLE)) || 
                             (s0_aw_granted_m1_r && M1_AXI_AWVALID && m1_aw_select_s0_w && (m1_aw_decerr_state_r == DECERR_IDLE));
    // W Channel - Follows AW grant for S0
    wire s0_w_from_m0_selected = s0_aw_granted_m0_r && m0_aw_select_s0_w; // M0 is granted and selected S0 for AW
    wire s0_w_from_m1_selected = s0_aw_granted_m1_r && m1_aw_select_s0_w; // M1 is granted and selected S0 for AW
    assign S0_AXI_WDATA  = s0_w_from_m1_selected ? M1_AXI_WDATA  : M0_AXI_WDATA;
    assign S0_AXI_WSTRB  = s0_w_from_m1_selected ? M1_AXI_WSTRB  : M0_AXI_WSTRB;
    assign S0_AXI_WLAST  = s0_w_from_m1_selected ? M1_AXI_WLAST  : M0_AXI_WLAST;
    assign S0_AXI_WVALID = (s0_w_from_m0_selected && M0_AXI_WVALID && (m0_aw_decerr_state_r == DECERR_IDLE)) || 
                           (s0_w_from_m1_selected && M1_AXI_WVALID && (m1_aw_decerr_state_r == DECERR_IDLE));
    // B Channel (Response from S0 to M0 or M1)
    // AR Channel
    assign S0_AXI_ARADDR   = s0_ar_granted_m1_r ? M1_AXI_ARADDR   : M0_AXI_ARADDR;
    assign S0_AXI_ARLEN    = s0_ar_granted_m1_r ? M1_AXI_ARLEN    : M0_AXI_ARLEN;
    assign S0_AXI_ARSIZE   = s0_ar_granted_m1_r ? M1_AXI_ARSIZE   : M0_AXI_ARSIZE;
    assign S0_AXI_ARBURST  = s0_ar_granted_m1_r ? M1_AXI_ARBURST  : M0_AXI_ARBURST;
    assign S0_AXI_ARLOCK   = s0_ar_granted_m1_r ? M1_AXI_ARLOCK   : M0_AXI_ARLOCK;
    assign S0_AXI_ARCACHE  = s0_ar_granted_m1_r ? M1_AXI_ARCACHE  : M0_AXI_ARCACHE;
    assign S0_AXI_ARPROT   = s0_ar_granted_m1_r ? M1_AXI_ARPROT   : M0_AXI_ARPROT;
    assign S0_AXI_ARREGION = s0_ar_granted_m0_r ? M0_AXI_ARREGION : 4'b0;
    assign S0_AXI_ARQOS    = s0_ar_granted_m0_r ? M0_AXI_ARQOS    : 4'b0;
    assign S0_AXI_ARVALID  = (s0_ar_granted_m0_r && M0_AXI_ARVALID && m0_ar_select_s0_w && (m0_ar_decerr_state_r == DECERR_IDLE)) ||
                             (s0_ar_granted_m1_r && M1_AXI_ARVALID && m1_ar_select_s0_w && (m1_ar_decerr_state_r == DECERR_IDLE));
    // R Channel (Data from S0 to M0 or M1)

    // --- Slave Port S1 (Keystone CSRs - M0 only, AXI-Lite) ---
    // AWLEN, AWSIZE, AWBURST, AWLOCK, AWCACHE, AWREGION, AWQOS from M0 are not connected to S1 (AXI-Lite)
    assign S1_AXI_AWADDR  = M0_AXI_AWADDR;
    assign S1_AXI_AWPROT  = M0_AXI_AWPROT;
    assign S1_AXI_AWVALID = m0_aw_select_s1_w && M0_AXI_AWVALID && (m0_aw_decerr_state_r == DECERR_IDLE);
    assign S1_AXI_WDATA   = M0_AXI_WDATA;
    assign S1_AXI_WSTRB   = M0_AXI_WSTRB;
    assign S1_AXI_WVALID  = m0_aw_select_s1_w && M0_AXI_WVALID && (m0_aw_decerr_state_r == DECERR_IDLE);

    // ARLEN, ARSIZE, ARBURST, ARLOCK, ARCACHE, ARREGION, ARQOS from M0 are not connected to S1 (AXI-Lite)
    assign S1_AXI_ARADDR  = M0_AXI_ARADDR;
    assign S1_AXI_ARPROT  = M0_AXI_ARPROT;
    assign S1_AXI_ARVALID = m0_ar_select_s1_w && M0_AXI_ARVALID && (m0_ar_decerr_state_r == DECERR_IDLE);

    // --- Slave Port S2 (Peripherals - M0 only, AXI-Lite) ---
    assign S2_AXI_AWADDR  = M0_AXI_AWADDR;
    assign S2_AXI_AWPROT  = M0_AXI_AWPROT;
    assign S2_AXI_AWVALID = m0_aw_select_s2_w && M0_AXI_AWVALID && (m0_aw_decerr_state_r == DECERR_IDLE);
    assign S2_AXI_WDATA   = M0_AXI_WDATA;
    assign S2_AXI_WSTRB   = M0_AXI_WSTRB;
    assign S2_AXI_WVALID  = m0_aw_select_s2_w && M0_AXI_WVALID && (m0_aw_decerr_state_r == DECERR_IDLE);
    
    assign S2_AXI_ARADDR  = M0_AXI_ARADDR;
    assign S2_AXI_ARPROT  = M0_AXI_ARPROT;
    assign S2_AXI_ARVALID = m0_ar_select_s2_w && M0_AXI_ARVALID && (m0_ar_decerr_state_r == DECERR_IDLE);
    

    // --- Master M0 (CPU) Response Logic ---
    // Combinatorial assignments for M0 outputs based on selections and slave responses / DECERR FSM
    assign M0_AXI_AWREADY = (m0_aw_decerr_state_r == DECERR_IDLE) ? 
                                ((m0_aw_select_s0_w && s0_aw_granted_m0_r) ? S0_AXI_AWREADY :
                                 (m0_aw_select_s1_w) ? S1_AXI_AWREADY :
                                 (m0_aw_select_s2_w) ? S2_AXI_AWREADY : 1'b0) :
                                1'b1; // Accept to generate DECERR
                            
    assign M0_AXI_WREADY  = (m0_aw_decerr_state_r == DECERR_IDLE) ?
                                ((m0_aw_select_s0_w && s0_aw_granted_m0_r) ? S0_AXI_WREADY :
                                 (m0_aw_select_s1_w) ? S1_AXI_WREADY :
                                 (m0_aw_select_s2_w) ? S2_AXI_WREADY : 1'b0) :
                                1'b1; // Accept to generate DECERR

    assign M0_AXI_BRESP  = (m0_aw_decerr_state_r == DECERR_RESP) ? AXI_RESP_DECERR :
                           (m0_aw_select_s0_w && s0_aw_granted_m0_r) ? S0_AXI_BRESP :
                           (m0_aw_select_s1_w) ? S1_AXI_BRESP :
                           (m0_aw_select_s2_w) ? S2_AXI_BRESP :
                           AXI_RESP_OKAY; 
    assign M0_AXI_BVALID = (m0_aw_decerr_state_r == DECERR_RESP) ? m0_aw_decerr_bvalid_r :
                           (m0_aw_select_s0_w && s0_aw_granted_m0_r) ? S0_AXI_BVALID :
                           (m0_aw_select_s1_w) ? S1_AXI_BVALID :
                           (m0_aw_select_s2_w) ? S2_AXI_BVALID :
                           1'b0; 
                           
    assign M0_AXI_ARREADY = (m0_ar_decerr_state_r == DECERR_IDLE) ?
                                ((m0_ar_select_s0_w && s0_ar_granted_m0_r) ? S0_AXI_ARREADY :
                                 (m0_ar_select_s1_w) ? S1_AXI_ARREADY :
                                 (m0_ar_select_s2_w) ? S2_AXI_ARREADY : 1'b0) :
                                1'b1; // Accept for DECERR

    assign M0_AXI_RDATA  = (m0_ar_decerr_state_r == DECERR_RESP) ? 32'hDEADBEEF :
                           (m0_ar_select_s0_w && s0_ar_granted_m0_r) ? S0_AXI_RDATA :
                           (m0_ar_select_s1_w) ? S1_AXI_RDATA :
                           (m0_ar_select_s2_w) ? S2_AXI_RDATA :
                           32'b0;
    assign M0_AXI_RRESP  = (m0_ar_decerr_state_r == DECERR_RESP) ? AXI_RESP_DECERR :
                           (m0_ar_select_s0_w && s0_ar_granted_m0_r) ? S0_AXI_RRESP :
                           (m0_ar_select_s1_w) ? S1_AXI_RRESP :
                           (m0_ar_select_s2_w) ? S2_AXI_RRESP :
                           AXI_RESP_OKAY;
    assign M0_AXI_RLAST  = (m0_ar_decerr_state_r == DECERR_RESP) ? 1'b1 : 
                           (m0_ar_select_s0_w && s0_ar_granted_m0_r) ? S0_AXI_RLAST :
                           ((m0_ar_select_s1_w && S1_AXI_RVALID) || (m0_ar_select_s2_w && S2_AXI_RVALID)) ? 1'b1 : 
                           1'b0; 
    assign M0_AXI_RVALID = (m0_ar_decerr_state_r == DECERR_RESP) ? m0_ar_decerr_rvalid_r :
                           (m0_ar_select_s0_w && s0_ar_granted_m0_r) ? S0_AXI_RVALID :
                           (m0_ar_select_s1_w) ? S1_AXI_RVALID :
                           (m0_ar_select_s2_w) ? S2_AXI_RVALID :
                           1'b0;

    // --- Master M1 (DMA) Response Logic (Only S0 or DECERR) ---
    assign M1_AXI_AWREADY = (m1_aw_decerr_state_r == DECERR_IDLE) ?
                                ((m1_aw_select_s0_w && s0_aw_granted_m1_r) ? S0_AXI_AWREADY : 1'b0) :
                                1'b1;
    assign M1_AXI_WREADY  = (m1_aw_decerr_state_r == DECERR_IDLE) ?
                                ((m1_aw_select_s0_w && s0_aw_granted_m1_r) ? S0_AXI_WREADY : 1'b0) :
                                1'b1;
    assign M1_AXI_BRESP  = (m1_aw_decerr_state_r == DECERR_RESP) ? AXI_RESP_DECERR :
                           (m1_aw_select_s0_w && s0_aw_granted_m1_r) ? S0_AXI_BRESP : AXI_RESP_OKAY;
    assign M1_AXI_BVALID = (m1_aw_decerr_state_r == DECERR_RESP) ? m1_aw_decerr_bvalid_r :
                           (m1_aw_select_s0_w && s0_aw_granted_m1_r) ? S0_AXI_BVALID : 1'b0;

    assign M1_AXI_ARREADY = (m1_ar_decerr_state_r == DECERR_IDLE) ?
                                ((m1_ar_select_s0_w && s0_ar_granted_m1_r) ? S0_AXI_ARREADY : 1'b0) :
                                1'b1;
    assign M1_AXI_RDATA  = (m1_ar_decerr_state_r == DECERR_RESP) ? 32'hDEADBEEF :
                           (m1_ar_select_s0_w && s0_ar_granted_m1_r) ? S0_AXI_RDATA : 32'b0;
    assign M1_AXI_RRESP  = (m1_ar_decerr_state_r == DECERR_RESP) ? AXI_RESP_DECERR :
                           (m1_ar_select_s0_w && s0_ar_granted_m1_r) ? S0_AXI_RRESP : AXI_RESP_OKAY;
    assign M1_AXI_RLAST  = (m1_ar_decerr_state_r == DECERR_RESP) ? 1'b1 :
                           (m1_ar_select_s0_w && s0_ar_granted_m1_r) ? S0_AXI_RLAST : 1'b0;
    assign M1_AXI_RVALID = (m1_ar_decerr_state_r == DECERR_RESP) ? m1_ar_decerr_rvalid_r :
                           (m1_ar_select_s0_w && s0_ar_granted_m1_r) ? S0_AXI_RVALID : 1'b0;

    // Slave BREADYs / RREADYs
    // These are inputs to the slaves. The interconnect drives them based on which master is talking to the slave.
    // And also, only if the master itself is ready to accept response/data.
    assign S0_AXI_BREADY = (s0_aw_granted_m0_r && M0_AXI_BREADY && m0_aw_select_s0_w && (m0_aw_decerr_state_r == DECERR_IDLE)) || 
                           (s0_aw_granted_m1_r && M1_AXI_BREADY && m1_aw_select_s0_w && (m1_aw_decerr_state_r == DECERR_IDLE));
    assign S0_AXI_RREADY = (s0_ar_granted_m0_r && M0_AXI_RREADY && m0_ar_select_s0_w && (m0_ar_decerr_state_r == DECERR_IDLE)) || 
                           (s0_ar_granted_m1_r && M1_AXI_RREADY && m1_ar_select_s0_w && (m1_ar_decerr_state_r == DECERR_IDLE));
    
    assign S1_AXI_BREADY = m0_aw_select_s1_w && M0_AXI_BREADY && (m0_aw_decerr_state_r == DECERR_IDLE);
    assign S1_AXI_RREADY = m0_ar_select_s1_w && M0_AXI_RREADY && (m0_ar_decerr_state_r == DECERR_IDLE);
    
    assign S2_AXI_BREADY = m0_aw_select_s2_w && M0_AXI_BREADY && (m0_aw_decerr_state_r == DECERR_IDLE);
    assign S2_AXI_RREADY = m0_ar_select_s2_w && M0_AXI_RREADY && (m0_ar_decerr_state_r == DECERR_IDLE);

    // DECERR FSM Logic
    // M0 AW DECERR
    always @(posedge clk or negedge resetn) begin
        if (!resetn) begin
            m0_aw_decerr_state_r  <= DECERR_IDLE;
            m0_aw_decerr_bvalid_r <= 1'b0;
        end else begin
            case (m0_aw_decerr_state_r)
                DECERR_IDLE: begin
                    m0_aw_decerr_bvalid_r <= 1'b0; // Default BVALID low in IDLE
                    if (m0_aw_addr_error_w && M0_AXI_AWVALID && M0_AXI_WVALID && M0_AXI_WLAST) begin // Wait for full write command (WLAST for single beat)
                        m0_aw_decerr_state_r <= DECERR_RESP;
                        m0_aw_decerr_bvalid_r <= 1'b1;
                    end
                end
                DECERR_RESP: begin
                    if (M0_AXI_BREADY) begin
                        m0_aw_decerr_state_r  <= DECERR_IDLE;
                        m0_aw_decerr_bvalid_r <= 1'b0;
                    end
                    // else BVALID remains high until BREADY
                end
                default: m0_aw_decerr_state_r <= DECERR_IDLE;
            endcase
        end
    end
    // M0 AR DECERR
    always @(posedge clk or negedge resetn) begin
        if (!resetn) begin
            m0_ar_decerr_state_r  <= DECERR_IDLE;
            m0_ar_decerr_rvalid_r <= 1'b0;
        end else begin
            case (m0_ar_decerr_state_r)
                DECERR_IDLE: begin
                    m0_ar_decerr_rvalid_r <= 1'b0; // Default RVALID low in IDLE
                    if (m0_ar_addr_error_w && M0_AXI_ARVALID) begin
                        m0_ar_decerr_state_r <= DECERR_RESP;
                        m0_ar_decerr_rvalid_r <= 1'b1;
                    end
                end
                DECERR_RESP: begin
                    if (M0_AXI_RREADY) begin
                        m0_ar_decerr_state_r  <= DECERR_IDLE;
                        m0_ar_decerr_rvalid_r <= 1'b0;
                    end
                    // else RVALID remains high until RREADY
                end
                default: m0_ar_decerr_state_r <= DECERR_IDLE;
            endcase
        end
    end
    // M1 AW DECERR
     always @(posedge clk or negedge resetn) begin
        if (!resetn) begin
            m1_aw_decerr_state_r  <= DECERR_IDLE;
            m1_aw_decerr_bvalid_r <= 1'b0;
        end else begin
            case (m1_aw_decerr_state_r)
                DECERR_IDLE: begin
                    m1_aw_decerr_bvalid_r <= 1'b0;
                    if (m1_aw_addr_error_w && M1_AXI_AWVALID && M1_AXI_WVALID && M1_AXI_WLAST) begin
                        m1_aw_decerr_state_r <= DECERR_RESP;
                        m1_aw_decerr_bvalid_r <= 1'b1;
                    end
                end
                DECERR_RESP: begin
                    if (M1_AXI_BREADY) begin
                        m1_aw_decerr_state_r  <= DECERR_IDLE;
                        m1_aw_decerr_bvalid_r <= 1'b0;
                    end
                end
                default: m1_aw_decerr_state_r <= DECERR_IDLE;
            endcase
        end
    end
    // M1 AR DECERR
    always @(posedge clk or negedge resetn) begin
        if (!resetn) begin
            m1_ar_decerr_state_r  <= DECERR_IDLE;
            m1_ar_decerr_rvalid_r <= 1'b0;
        end else begin
            case (m1_ar_decerr_state_r)
                DECERR_IDLE: begin
                    m1_ar_decerr_rvalid_r <= 1'b0;
                    if (m1_ar_addr_error_w && M1_AXI_ARVALID) begin
                        m1_ar_decerr_state_r <= DECERR_RESP;
                        m1_ar_decerr_rvalid_r <= 1'b1;
                    end
                end
                DECERR_RESP: begin
                    if (M1_AXI_RREADY) begin
                        m1_ar_decerr_state_r  <= DECERR_IDLE;
                        m1_ar_decerr_rvalid_r <= 1'b0;
                    end
                end
                default: m1_ar_decerr_state_r <= DECERR_IDLE;
            endcase
        end
    end

    // Internal Logic (Conceptual):
    // 1. Address Decoding Logic:
    //    - For M0_AXI (CPU) and M1_AXI (Keystone DMA) requests:
    // For AXI-Lite (S1, S2), many M0 signals like AWLEN, AWSIZE, AWBURST, etc., are passed.
    // The Lite slaves are expected to ignore them or handle them correctly (e.g., only perform single beat).
    // S0 (Main Memory) uses the full AXI signals.

    // --- Write Channel Logic ---
    // AW (Address Write) Channel
    // S0 AW Channel (Arbitrated)
    assign S0_AXI_AWADDR  = s0_aw_granted_m1_r ? M1_AXI_AWADDR  : M0_AXI_AWADDR;
    assign S0_AXI_AWLEN   = s0_aw_granted_m1_r ? M1_AXI_AWLEN   : M0_AXI_AWLEN;
    assign S0_AXI_AWSIZE  = s0_aw_granted_m1_r ? M1_AXI_AWSIZE  : M0_AXI_AWSIZE;
    assign S0_AXI_AWBURST = s0_aw_granted_m1_r ? M1_AXI_AWBURST : M0_AXI_AWBURST;
    assign S0_AXI_AWLOCK  = s0_aw_granted_m1_r ? M1_AXI_AWLOCK  : M0_AXI_AWLOCK;
    assign S0_AXI_AWCACHE = s0_aw_granted_m1_r ? M1_AXI_AWCACHE : M0_AXI_AWCACHE;
    assign S0_AXI_AWPROT  = s0_aw_granted_m1_r ? M1_AXI_AWPROT  : M0_AXI_AWPROT;
    // S0_AXI_AWREGION, S0_AXI_AWQOS are from M0 only if M0 is granted, else default/M1 if M1 has them
    assign S0_AXI_AWREGION = s0_aw_granted_m0_r ? M0_AXI_AWREGION : (s0_aw_granted_m1_r ? 4'b0 : 4'b0); // M1 stub doesn't have these
    assign S0_AXI_AWQOS    = s0_aw_granted_m0_r ? M0_AXI_AWQOS    : (s0_aw_granted_m1_r ? 4'b0 : 4'b0);
    assign S0_AXI_AWVALID = (s0_aw_granted_m0_r && M0_AXI_AWVALID && m0_aw_select_s0_w) || 
                            (s0_aw_granted_m1_r && M1_AXI_AWVALID && m1_aw_select_s0_w) ;

    // S1 AW Channel (M0 only)
    assign S1_AXI_AWADDR  = M0_AXI_AWADDR;
    assign S1_AXI_AWPROT  = M0_AXI_AWPROT;
    assign S1_AXI_AWVALID = m0_aw_select_s1_w && M0_AXI_AWVALID && !m0_aw_addr_error_w;

    // S2 AW Channel (M0 only)
    assign S2_AXI_AWADDR  = M0_AXI_AWADDR;
    assign S2_AXI_AWPROT  = M0_AXI_AWPROT;
    assign S2_AXI_AWVALID = m0_aw_select_s2_w && M0_AXI_AWVALID && !m0_aw_addr_error_w;

    // M0 AWREADY Logic
    // M1 AWREADY Logic (only targets S0 or error)

    // W (Write Data) Channel
    // S0 W Channel (Arbitrated - follows AW grant for S0)
    // Assuming W channel follows the granted AW channel master for S0
    wire s0_w_master_is_m0 = s0_aw_granted_m0_r; // W follows AW grant
    wire s0_w_master_is_m1 = s0_aw_granted_m1_r;

    assign S0_AXI_WDATA  = s0_w_master_is_m1 ? M1_AXI_WDATA  : M0_AXI_WDATA;
    assign S0_AXI_WSTRB  = s0_w_master_is_m1 ? M1_AXI_WSTRB  : M0_AXI_WSTRB;
    assign S0_AXI_WLAST  = s0_w_master_is_m1 ? M1_AXI_WLAST  : M0_AXI_WLAST;
    assign S0_AXI_WVALID = (s0_w_master_is_m0 && M0_AXI_WVALID && m0_aw_select_s0_w) || // Also check if M0 still selected for S0
                           (s0_w_master_is_m1 && M1_AXI_WVALID && m1_aw_select_s0_w) ;

    // S1 W Channel (M0 only)
    assign S1_AXI_WDATA  = M0_AXI_WDATA;
    assign S1_AXI_WSTRB  = M0_AXI_WSTRB;
    assign S1_AXI_WVALID = m0_aw_select_s1_w && M0_AXI_WVALID && !m0_aw_addr_error_w; // WVALID follows AW channel selection

    // S2 W Channel (M0 only)
    assign S2_AXI_WDATA  = M0_AXI_WDATA;
    assign S2_AXI_WSTRB  = M0_AXI_WSTRB;
    assign S2_AXI_WVALID = m0_aw_select_s2_w && M0_AXI_WVALID && !m0_aw_addr_error_w;

    // M0 WREADY Logic
    // M1 WREADY Logic

    // B (Write Response) Channel
    // M0 BREADY Logic
    // M1 BREADY Logic

    // --- Read Channel Logic ---
    // AR (Address Read) Channel
    // S0 AR Channel (Arbitrated)
    assign S0_AXI_ARADDR  = s0_ar_granted_m1_r ? M1_AXI_ARADDR  : M0_AXI_ARADDR;
    assign S0_AXI_ARLEN   = s0_ar_granted_m1_r ? M1_AXI_ARLEN   : M0_AXI_ARLEN;
    assign S0_AXI_ARSIZE  = s0_ar_granted_m1_r ? M1_AXI_ARSIZE  : M0_AXI_ARSIZE;
    assign S0_AXI_ARBURST = s0_ar_granted_m1_r ? M1_AXI_ARBURST : M0_AXI_ARBURST;
    assign S0_AXI_ARLOCK  = s0_ar_granted_m1_r ? M1_AXI_ARLOCK  : M0_AXI_ARLOCK;
    assign S0_AXI_ARCACHE = s0_ar_granted_m1_r ? M1_AXI_ARCACHE : M0_AXI_ARCACHE;
    assign S0_AXI_ARPROT  = s0_ar_granted_m1_r ? M1_AXI_ARPROT  : M0_AXI_ARPROT;
    assign S0_AXI_ARREGION = s0_ar_granted_m0_r ? M0_AXI_ARREGION : (s0_ar_granted_m1_r ? 4'b0 : 4'b0);
    assign S0_AXI_ARQOS    = s0_ar_granted_m0_r ? M0_AXI_ARQOS    : (s0_ar_granted_m1_r ? 4'b0 : 4'b0);
    assign S0_AXI_ARVALID = (s0_ar_granted_m0_r && M0_AXI_ARVALID && m0_ar_select_s0_w) ||
                            (s0_ar_granted_m1_r && M1_AXI_ARVALID && m1_ar_select_s0_w) ;

    // S1 AR Channel (M0 only)
    assign S1_AXI_ARADDR  = M0_AXI_ARADDR;
    assign S1_AXI_ARPROT  = M0_AXI_ARPROT;
    assign S1_AXI_ARVALID = m0_ar_select_s1_w && M0_AXI_ARVALID && !m0_ar_addr_error_w;

    // S2 AR Channel (M0 only)
    assign S2_AXI_ARADDR  = M0_AXI_ARADDR;
    assign S2_AXI_ARPROT  = M0_AXI_ARPROT;
    assign S2_AXI_ARVALID = m0_ar_select_s2_w && M0_AXI_ARVALID && !m0_ar_addr_error_w;
    
    // M0 ARREADY Logic
    // M1 ARREADY Logic

    // R (Read Data) Channel
    // M0 RREADY Logic
    // M1 RREADY Logic


    // --- Combined Master-Side Logic (AWREADY, WREADY, BRESP, BVALID, ARREADY, R*, etc.) ---
    // This needs to be carefully implemented to handle selected slave vs. DECERR
    // For example M0_AXI_AWREADY:
    // m0_awready_r <= (m0_aw_select_s0_w && s0_aw_granted_m0_r && S0_AXI_AWREADY) ||
    //                 (m0_aw_select_s1_w && S1_AXI_AWREADY) ||
    //                 (m0_aw_select_s2_w && S2_AXI_AWREADY) ||
    //                 m0_aw_addr_error_w; // Accept erroneous address to respond with DECERR

    // Placeholder for full logic
    always_comb begin
        // --- Master 0 (CPU) ---
        // Defaults for M0 if no slave selected or error
        m0_awready_r = 1'b0;
        m0_wready_r  = 1'b0;
        m0_bresp_r   = AXI_RESP_OKAY;
        m0_bvalid_r  = 1'b0;
        m0_arready_r = 1'b0;
        m0_rdata_r   = 32'b0;
        m0_rresp_r   = AXI_RESP_OKAY;
        m0_rlast_r   = 1'b0;
        m0_rvalid_r  = 1'b0;

        if (m0_aw_addr_error_w) begin
            m0_awready_r = 1'b1; // Accept address to send DECERR
            m0_wready_r  = 1'b1; // Accept data (and discard) to send DECERR
            if (M0_AXI_AWVALID && M0_AXI_WVALID) begin // Wait for both phases before BVALID
                 m0_bresp_r  = AXI_RESP_DECERR;
                 m0_bvalid_r = 1'b1; // This needs to be registered based on BREADY
            end
        end else if (m0_aw_select_s0_w && s0_aw_granted_m0_r) begin
            m0_awready_r = S0_AXI_AWREADY;
            m0_wready_r  = S0_AXI_WREADY;
            m0_bresp_r   = S0_AXI_BRESP;
            m0_bvalid_r  = S0_AXI_BVALID;
        end else if (m0_aw_select_s1_w) begin
            m0_awready_r = S1_AXI_AWREADY;
            m0_wready_r  = S1_AXI_WREADY;
            m0_bresp_r   = S1_AXI_BRESP;
            m0_bvalid_r  = S1_AXI_BVALID;
        end else if (m0_aw_select_s2_w) begin
            m0_awready_r = S2_AXI_AWREADY;
            m0_wready_r  = S2_AXI_WREADY;
            m0_bresp_r   = S2_AXI_BRESP;
            m0_bvalid_r  = S2_AXI_BVALID;
        end

        if (m0_ar_addr_error_w) begin
            m0_arready_r = 1'b1; // Accept address
            if (M0_AXI_ARVALID) begin // Wait for ARVALID before RVALID
                m0_rdata_r  = 32'hDEADBEEF; // Garbage data for DECERR
                m0_rresp_r  = AXI_RESP_DECERR;
                m0_rlast_r  = 1'b1; // DECERR is a single beat response
                m0_rvalid_r = 1'b1; // This needs to be registered based on RREADY
            end
        end else if (m0_ar_select_s0_w && s0_ar_granted_m0_r) begin
            m0_arready_r = S0_AXI_ARREADY;
            m0_rdata_r   = S0_AXI_RDATA;
            m0_rresp_r   = S0_AXI_RRESP;
            m0_rlast_r   = S0_AXI_RLAST;
            m0_rvalid_r  = S0_AXI_RVALID;
        end else if (m0_ar_select_s1_w) begin
            m0_arready_r = S1_AXI_ARREADY;
            m0_rdata_r   = S1_AXI_RDATA;
            m0_rresp_r   = S1_AXI_RRESP;
            m0_rlast_r   = 1'b1; // AXI-Lite is always single beat
            m0_rvalid_r  = S1_AXI_RVALID;
        end else if (m0_ar_select_s2_w) begin
            m0_arready_r = S2_AXI_ARREADY;
            m0_rdata_r   = S2_AXI_RDATA;
            m0_rresp_r   = S2_AXI_RRESP;
            m0_rlast_r   = 1'b1; // AXI-Lite is always single beat
            m0_rvalid_r  = S2_AXI_RVALID;
        end

        // --- Master 1 (DMA) ---
        // Defaults for M1 if no slave selected or error
        m1_awready_r = 1'b0;
        m1_wready_r  = 1'b0;
        m1_bresp_r   = AXI_RESP_OKAY;
        m1_bvalid_r  = 1'b0;
        m1_arready_r = 1'b0;
        m1_rdata_r   = 32'b0;
        m1_rresp_r   = AXI_RESP_OKAY;
        m1_rlast_r   = 1'b0;
        m1_rvalid_r  = 1'b0;

        if (m1_aw_addr_error_w) begin
            m1_awready_r = 1'b1;
            m1_wready_r  = 1'b1;
             if (M1_AXI_AWVALID && M1_AXI_WVALID) begin
                m1_bresp_r  = AXI_RESP_DECERR;
                m1_bvalid_r = 1'b1; // Registered
            end
        end else if (m1_aw_select_s0_w && s0_aw_granted_m1_r) begin
            m1_awready_r = S0_AXI_AWREADY;
            m1_wready_r  = S0_AXI_WREADY;
            m1_bresp_r   = S0_AXI_BRESP;
            m1_bvalid_r  = S0_AXI_BVALID;
        end

        if (m1_ar_addr_error_w) begin
            m1_arready_r = 1'b1;
            if (M1_AXI_ARVALID) begin
                m1_rdata_r  = 32'hDEADBEEF;
                m1_rresp_r  = AXI_RESP_DECERR;
                m1_rlast_r  = 1'b1;
                m1_rvalid_r = 1'b1; // Registered
            end
        end else if (m1_ar_select_s0_w && s0_ar_granted_m1_r) begin
            m1_arready_r = S0_AXI_ARREADY;
            m1_rdata_r   = S0_AXI_RDATA;
            m1_rresp_r   = S0_AXI_RRESP;
            m1_rlast_r   = S0_AXI_RLAST;
            m1_rvalid_r  = S0_AXI_RVALID;
        end
    end
    
    // Registered BVALID/RVALID for DECERR responses (simplified)
    // A full FSM per master port for DECERR generation would be more robust.
    // This simplified version might have issues if M*_AXI_BREADY/RREADY is not high when bvalid_r/rvalid_r is asserted.
    // This needs to be replaced with proper registered logic for BVALID/RVALID generation, especially for DECERR.
    // For now, the combinatorial assignment above is a starting point.
    // The m*_bvalid_r, m*_rvalid_r should be registered and cleared upon M*_AXI_BREADY/RREADY.

    // Slave BREADYs / RREADYs
    // S0
    assign S0_AXI_BREADY = (s0_aw_granted_m0_r && M0_AXI_BREADY) || (s0_aw_granted_m1_r && M1_AXI_BREADY);
    assign S0_AXI_RREADY = (s0_ar_granted_m0_r && M0_AXI_RREADY) || (s0_ar_granted_m1_r && M1_AXI_RREADY);
    // S1 (M0 only)
    assign S1_AXI_BREADY = m0_aw_select_s1_w && M0_AXI_BREADY;
    assign S1_AXI_RREADY = m0_ar_select_s1_w && M0_AXI_RREADY;
    // S2 (M0 only)
    assign S2_AXI_BREADY = m0_aw_select_s2_w && M0_AXI_BREADY;
    assign S2_AXI_RREADY = m0_ar_select_s2_w && M0_AXI_RREADY;


    // Internal Logic (Conceptual):
    // 1. Address Decoding Logic:
    //    - For M0_AXI (CPU) and M1_AXI (Keystone DMA) requests:
    //      - Read M*_AXI_AWADDR or M*_AXI_ARADDR.
    //      - Based on SoC_Memory_Map.txt:
    //        - If address is in Main Memory range (0x8000_0000 - 0xBFFF_FFFF) -> route to S0_AXI.
    //        - If address is in Keystone Coprocessor CSRs range (0x1000_0000 - 0x1000_0FFF) -> route to S1_AXI.
    //        - If address is in Generic Peripherals range (0x0200_0000 - 0x0200_FFFF) -> route to S2_AXI.
    //        - Else (unmapped address) -> generate DECERR on BRESP/RRESP for the requesting master.
    //    - Need to handle potential overlapping requests or generate exclusive selects for slaves.

    // 2. Arbitration Logic:
    //    - If both M0 and M1 try to access S0 (Main Memory) simultaneously:
    //      - Implement round-robin or fixed-priority arbitration.
    //      - Grant access to one master, hold the other's *READY signal low until resource is free.
    //    - S1 and S2 are AXI-Lite and typically accessed by CPU (M0) only. Keystone DMA (M1) usually only targets Main Memory (S0).

    // 3. AXI4 Full to AXI4-Lite Conversion (Simplified):
    //    - When M0 (Full) targets S1 (Lite) or S2 (Lite):
    //      - The interconnect should ensure only single-beat transfers are performed.
    //      - AXI Full signals like AWLEN, AWSIZE, AWBURST (and AR* equivalents) might be ignored or constrained by the interconnect for Lite slaves.
    //      - AXI-Lite slaves do not use WLAST/RLAST in the same way for bursts, as they only do single transfers.
    //      - Interconnect must ensure WLAST/RLAST are correctly handled for single beat to AXI-Lite.
    //      - For this stub, we assume that if a full master is connected to a lite slave port,
    //        the master itself (or a preceding protocol converter) is configured to issue Lite-compatible (single-beat) transactions,
    //        or the interconnect implicitly handles this by, for example, breaking down bursts or only forwarding relevant signals.
    //        A common simplification is that AXI-Lite slaves ignore burst signals and only perform one transfer per valid address.

    // 4. Data Path Multiplexing:
    //    - Route M*_AXI_WDATA to the selected S*_AXI_WDATA.
    //    - Route selected S*_AXI_RDATA back to the requesting M*_AXI_RDATA.

    // 5. Response Path Multiplexing:
    //    - Route BRESP/RRESP from the selected slave back to the master.

    // Example: Simple connections for a single master (M0) and single slave (S0) for pass-through
    // This is NOT the complete interconnect logic, just a placeholder concept.
    // assign M0_AXI_AWREADY = S0_AXI_AWREADY;
    // assign S0_AXI_AWADDR  = M0_AXI_AWADDR;
    // ... and so on for all channels and signals if only one master and one slave.
    // With multiple masters/slaves, multiplexers and arbiters are needed.

    // Default DECERR for unmapped accesses (conceptual)
    // wire m0_decerr = ... (logic that determines if M0_AXI_AWADDR/ARADDR is unmapped)
    // wire m1_decerr = ... (logic that determines if M1_AXI_AWADDR/ARADDR is unmapped)

    // Actual implementation would involve:
    // - Address decoder modules.
    // - Arbiter modules (e.g., round_robin_arbiter).
    // - Multiplexers for data, address, and control signals.
    // - Logic for handling default slave responses (DECERR).

endmodule
