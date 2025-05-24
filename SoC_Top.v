// SoC Top-Level Module
// Date: 2024-03-14

`timescale 1ns / 1ps

module SoC_Top (
    input  wire         clk,
    input  wire         resetn, // Active low reset

    // Example Peripheral I/O
    output wire         uart_tx_o,
    input  wire         uart_rx_i
);

    // Parameters from SoC_Memory_Map.txt and module consistency
    localparam DATA_WIDTH = 32;
    localparam ADDR_WIDTH = 32;

    // --- AXI Wires for CVA6 CPU (Master 0 on Interconnect) ---
    wire [ADDR_WIDTH-1:0] M0_AXI_AWADDR;
    wire [7:0]            M0_AXI_AWLEN;
    wire [2:0]            M0_AXI_AWSIZE;
    wire [1:0]            M0_AXI_AWBURST;
    wire                  M0_AXI_AWLOCK;
    wire [3:0]            M0_AXI_AWCACHE;
    wire [2:0]            M0_AXI_AWPROT;
    wire [3:0]            M0_AXI_AWREGION;
    wire [3:0]            M0_AXI_AWQOS;
    wire                  M0_AXI_AWVALID;
    wire                  M0_AXI_AWREADY;
    wire [DATA_WIDTH-1:0] M0_AXI_WDATA;
    wire [DATA_WIDTH/8-1:0] M0_AXI_WSTRB;
    wire                  M0_AXI_WLAST;
    wire                  M0_AXI_WVALID;
    wire                  M0_AXI_WREADY;
    wire [1:0]            M0_AXI_BRESP;
    wire                  M0_AXI_BVALID;
    wire                  M0_AXI_BREADY;
    wire [ADDR_WIDTH-1:0] M0_AXI_ARADDR;
    wire [7:0]            M0_AXI_ARLEN;
    wire [2:0]            M0_AXI_ARSIZE;
    wire [1:0]            M0_AXI_ARBURST;
    wire                  M0_AXI_ARLOCK;
    wire [3:0]            M0_AXI_ARCACHE;
    wire [2:0]            M0_AXI_ARPROT;
    wire [3:0]            M0_AXI_ARREGION;
    wire [3:0]            M0_AXI_ARQOS;
    wire                  M0_AXI_ARVALID;
    wire                  M0_AXI_ARREADY;
    wire [DATA_WIDTH-1:0] M0_AXI_RDATA;
    wire [1:0]            M0_AXI_RRESP;
    wire                  M0_AXI_RLAST;
    wire                  M0_AXI_RVALID;
    wire                  M0_AXI_RREADY;

    // --- AXI Wires for Keystone Coprocessor DMA (Master 1 on Interconnect) ---
    wire [ADDR_WIDTH-1:0] M1_AXI_AWADDR;
    wire [7:0]            M1_AXI_AWLEN;
    wire [2:0]            M1_AXI_AWSIZE;
    wire [1:0]            M1_AXI_AWBURST;
    wire                  M1_AXI_AWLOCK;
    wire [3:0]            M1_AXI_AWCACHE;
    wire [2:0]            M1_AXI_AWPROT;
    wire                  M1_AXI_AWVALID;
    wire                  M1_AXI_AWREADY;
    wire [DATA_WIDTH-1:0] M1_AXI_WDATA;
    wire [DATA_WIDTH/8-1:0] M1_AXI_WSTRB;
    wire                  M1_AXI_WLAST;
    wire                  M1_AXI_WVALID;
    wire                  M1_AXI_WREADY;
    wire [1:0]            M1_AXI_BRESP;
    wire                  M1_AXI_BVALID;
    wire                  M1_AXI_BREADY;
    wire [ADDR_WIDTH-1:0] M1_AXI_ARADDR;
    wire [7:0]            M1_AXI_ARLEN;
    wire [2:0]            M1_AXI_ARSIZE;
    wire [1:0]            M1_AXI_ARBURST;
    wire                  M1_AXI_ARLOCK;
    wire [3:0]            M1_AXI_ARCACHE;
    wire [2:0]            M1_AXI_ARPROT;
    wire                  M1_AXI_ARVALID;
    wire                  M1_AXI_ARREADY;
    wire [DATA_WIDTH-1:0] M1_AXI_RDATA;
    wire [1:0]            M1_AXI_RRESP;
    wire                  M1_AXI_RLAST;
    wire                  M1_AXI_RVALID;
    wire                  M1_AXI_RREADY;

    // --- AXI Wires for Main Memory (Slave 0 on Interconnect) ---
    wire [ADDR_WIDTH-1:0] S0_AXI_AWADDR;
    wire [7:0]            S0_AXI_AWLEN;
    wire [2:0]            S0_AXI_AWSIZE;
    wire [1:0]            S0_AXI_AWBURST;
    wire                  S0_AXI_AWLOCK;
    wire [3:0]            S0_AXI_AWCACHE;
    wire [2:0]            S0_AXI_AWPROT;
    wire [3:0]            S0_AXI_AWREGION;
    wire [3:0]            S0_AXI_AWQOS;
    wire                  S0_AXI_AWVALID;
    wire                  S0_AXI_AWREADY;
    wire [DATA_WIDTH-1:0] S0_AXI_WDATA;
    wire [DATA_WIDTH/8-1:0] S0_AXI_WSTRB;
    wire                  S0_AXI_WLAST;
    wire                  S0_AXI_WVALID;
    wire                  S0_AXI_WREADY;
    wire [1:0]            S0_AXI_BRESP;
    wire                  S0_AXI_BVALID;
    wire                  S0_AXI_BREADY;
    wire [ADDR_WIDTH-1:0] S0_AXI_ARADDR;
    wire [7:0]            S0_AXI_ARLEN;
    wire [2:0]            S0_AXI_ARSIZE;
    wire [1:0]            S0_AXI_ARBURST;
    wire                  S0_AXI_ARLOCK;
    wire [3:0]            S0_AXI_ARCACHE;
    wire [2:0]            S0_AXI_ARPROT;
    wire [3:0]            S0_AXI_ARREGION;
    wire [3:0]            S0_AXI_ARQOS;
    wire                  S0_AXI_ARVALID;
    wire                  S0_AXI_ARREADY;
    wire [DATA_WIDTH-1:0] S0_AXI_RDATA;
    wire [1:0]            S0_AXI_RRESP;
    wire                  S0_AXI_RLAST;
    wire                  S0_AXI_RVALID;
    wire                  S0_AXI_RREADY;

    // --- AXI Wires for Keystone Coprocessor CSRs (Slave 1 on Interconnect, AXI-Lite) ---
    wire [ADDR_WIDTH-1:0] S1_AXI_AWADDR;
    wire [2:0]            S1_AXI_AWPROT;
    wire                  S1_AXI_AWVALID;
    wire                  S1_AXI_AWREADY;
    wire [DATA_WIDTH-1:0] S1_AXI_WDATA;
    wire [DATA_WIDTH/8-1:0] S1_AXI_WSTRB;
    wire                  S1_AXI_WVALID;
    wire                  S1_AXI_WREADY;
    wire [1:0]            S1_AXI_BRESP;
    wire                  S1_AXI_BVALID;
    wire                  S1_AXI_BREADY;
    wire [ADDR_WIDTH-1:0] S1_AXI_ARADDR;
    wire [2:0]            S1_AXI_ARPROT;
    wire                  S1_AXI_ARVALID;
    wire                  S1_AXI_ARREADY;
    wire [DATA_WIDTH-1:0] S1_AXI_RDATA;
    wire [1:0]            S1_AXI_RRESP;
    wire                  S1_AXI_RVALID;
    wire                  S1_AXI_RREADY;

    // --- AXI Wires for Generic Peripherals (Slave 2 on Interconnect, AXI-Lite) ---
    wire [ADDR_WIDTH-1:0] S2_AXI_AWADDR;
    wire [2:0]            S2_AXI_AWPROT;
    wire                  S2_AXI_AWVALID;
    wire                  S2_AXI_AWREADY;
    wire [DATA_WIDTH-1:0] S2_AXI_WDATA;
    wire [DATA_WIDTH/8-1:0] S2_AXI_WSTRB;
    wire                  S2_AXI_WVALID;
    wire                  S2_AXI_WREADY;
    wire [1:0]            S2_AXI_BRESP;
    wire                  S2_AXI_BVALID;
    wire                  S2_AXI_BREADY;
    wire [ADDR_WIDTH-1:0] S2_AXI_ARADDR;
    wire [2:0]            S2_AXI_ARPROT;
    wire                  S2_AXI_ARVALID;
    wire                  S2_AXI_ARREADY;
    wire [DATA_WIDTH-1:0] S2_AXI_RDATA;
    wire [1:0]            S2_AXI_RRESP;
    wire                  S2_AXI_RVALID;
    wire                  S2_AXI_RREADY;

    // --- Boot ROM Interface Wires ---
    wire [15:0] boot_addr_w;
    wire [31:0] boot_data_w;

    // --- Interrupt Wires ---
    wire copro_irq_w;
    // wire timer_irq_w; // Example for future
    // wire sw_irq_w;    // Example for future

    // --- Instantiate CVA6 CPU Core Stub ---
    CVA6_Core_Stub cva6_core_inst (
        .clk(clk),
        .resetn(resetn),
        // AXI Master Port
        .M_AXI_AWADDR(M0_AXI_AWADDR),
        .M_AXI_AWLEN(M0_AXI_AWLEN),
        .M_AXI_AWSIZE(M0_AXI_AWSIZE),
        .M_AXI_AWBURST(M0_AXI_AWBURST),
        .M_AXI_AWLOCK(M0_AXI_AWLOCK),
        .M_AXI_AWCACHE(M0_AXI_AWCACHE),
        .M_AXI_AWPROT(M0_AXI_AWPROT),
        .M_AXI_AWREGION(M0_AXI_AWREGION),
        .M_AXI_AWQOS(M0_AXI_AWQOS),
        .M_AXI_AWVALID(M0_AXI_AWVALID),
        .M_AXI_AWREADY(M0_AXI_AWREADY),
        .M_AXI_WDATA(M0_AXI_WDATA),
        .M_AXI_WSTRB(M0_AXI_WSTRB),
        .M_AXI_WLAST(M0_AXI_WLAST),
        .M_AXI_WVALID(M0_AXI_WVALID),
        .M_AXI_WREADY(M0_AXI_WREADY),
        .M_AXI_BRESP(M0_AXI_BRESP),
        .M_AXI_BVALID(M0_AXI_BVALID),
        .M_AXI_BREADY(M0_AXI_BREADY),
        .M_AXI_ARADDR(M0_AXI_ARADDR),
        .M_AXI_ARLEN(M0_AXI_ARLEN),
        .M_AXI_ARSIZE(M0_AXI_ARSIZE),
        .M_AXI_ARBURST(M0_AXI_ARBURST),
        .M_AXI_ARLOCK(M0_AXI_ARLOCK),
        .M_AXI_ARCACHE(M0_AXI_ARCACHE),
        .M_AXI_ARPROT(M0_AXI_ARPROT),
        .M_AXI_ARREGION(M0_AXI_ARREGION),
        .M_AXI_ARQOS(M0_AXI_ARQOS),
        .M_AXI_ARVALID(M0_AXI_ARVALID),
        .M_AXI_ARREADY(M0_AXI_ARREADY),
        .M_AXI_RDATA(M0_AXI_RDATA),
        .M_AXI_RRESP(M0_AXI_RRESP),
        .M_AXI_RLAST(M0_AXI_RLAST),
        .M_AXI_RVALID(M0_AXI_RVALID),
        .M_AXI_RREADY(M0_AXI_RREADY),
        // Boot Interface
        .boot_addr_o(boot_addr_w),
        .boot_data_i(boot_data_w),
        // Interrupts
        .copro_irq_i(copro_irq_w)
        // .timer_irq_i(timer_irq_w),
        // .sw_irq_i(sw_irq_w)
    );

    // --- Instantiate Keystone Coprocessor ---
    KeystoneCoprocessor keystone_copro_inst (
        // AXI4-Lite Slave Interface (S1 on Interconnect)
        .s_axi_aclk(clk),
        .s_axi_aresetn(resetn),
        .s_axi_awaddr(S1_AXI_AWADDR[11:0]), // Keystone expects 12-bit addr for its 4KB CSR space
        .s_axi_awprot(S1_AXI_AWPROT),
        .s_axi_awvalid(S1_AXI_AWVALID),
        .s_axi_awready(S1_AXI_AWREADY),
        .s_axi_wdata(S1_AXI_WDATA),
        .s_axi_wstrb(S1_AXI_WSTRB),
        .s_axi_wvalid(S1_AXI_WVALID),
        .s_axi_wready(S1_AXI_WREADY),
        .s_axi_bresp(S1_AXI_BRESP),
        .s_axi_bvalid(S1_AXI_BVALID),
        .s_axi_bready(S1_AXI_BREADY),
        .s_axi_araddr(S1_AXI_ARADDR[11:0]),
        .s_axi_arprot(S1_AXI_ARPROT),
        .s_axi_arvalid(S1_AXI_ARVALID),
        .s_axi_arready(S1_AXI_ARREADY),
        .s_axi_rdata(S1_AXI_RDATA),
        .s_axi_rresp(S1_AXI_RRESP),
        .s_axi_rvalid(S1_AXI_RVALID),
        .s_axi_rready(S1_AXI_RREADY),
        // AXI4 Master Interface for DMA (M1 on Interconnect)
        .m_axi_aclk(clk),
        .m_axi_aresetn(resetn),
        .m_axi_awaddr(M1_AXI_AWADDR),
        .m_axi_awprot(3'b000), // Default AWPROT for DMA
        .m_axi_awvalid(M1_AXI_AWVALID),
        .m_axi_awready(M1_AXI_AWREADY),
        .m_axi_wdata(M1_AXI_WDATA),
        .m_axi_wstrb(M1_AXI_WSTRB),
        .m_axi_wlast(M1_AXI_WLAST),
        .m_axi_wvalid(M1_AXI_WVALID),
        .m_axi_wready(M1_AXI_WREADY),
        .m_axi_bresp(M1_AXI_BRESP),
        .m_axi_bvalid(M1_AXI_BVALID),
        .m_axi_bready(M1_AXI_BREADY),
        .m_axi_araddr(M1_AXI_ARADDR),
        .m_axi_arprot(3'b000), // Default ARPROT for DMA
        .m_axi_arvalid(M1_AXI_ARVALID),
        .m_axi_arready(M1_AXI_ARREADY),
        .m_axi_rdata(M1_AXI_RDATA),
        .m_axi_rresp(M1_AXI_RRESP),
        .m_axi_rlast(M1_AXI_RLAST),
        .m_axi_rvalid(M1_AXI_RVALID),
        .m_axi_rready(M1_AXI_RREADY),
        // Interrupt Output
        .interrupt_out(copro_irq_w),
        // Global Clock and Reset
        .clk(clk),
        .reset(resetn) // Keystone Coprocessor uses active low reset internally based on its modules
    );

    // --- Instantiate AXI Interconnect ---
    AXI_Interconnect axi_interconnect_inst (
        .clk(clk),
        .resetn(resetn),
        // Master Port 0: CVA6 CPU
        .M0_AXI_AWADDR(M0_AXI_AWADDR),
        .M0_AXI_AWLEN(M0_AXI_AWLEN),
        .M0_AXI_AWSIZE(M0_AXI_AWSIZE),
        .M0_AXI_AWBURST(M0_AXI_AWBURST),
        .M0_AXI_AWLOCK(M0_AXI_AWLOCK),
        .M0_AXI_AWCACHE(M0_AXI_AWCACHE),
        .M0_AXI_AWPROT(M0_AXI_AWPROT),
        .M0_AXI_AWREGION(M0_AXI_AWREGION),
        .M0_AXI_AWQOS(M0_AXI_AWQOS),
        .M0_AXI_AWVALID(M0_AXI_AWVALID),
        .M0_AXI_AWREADY(M0_AXI_AWREADY),
        .M0_AXI_WDATA(M0_AXI_WDATA),
        .M0_AXI_WSTRB(M0_AXI_WSTRB),
        .M0_AXI_WLAST(M0_AXI_WLAST),
        .M0_AXI_WVALID(M0_AXI_WVALID),
        .M0_AXI_WREADY(M0_AXI_WREADY),
        .M0_AXI_BRESP(M0_AXI_BRESP),
        .M0_AXI_BVALID(M0_AXI_BVALID),
        .M0_AXI_BREADY(M0_AXI_BREADY),
        .M0_AXI_ARADDR(M0_AXI_ARADDR),
        .M0_AXI_ARLEN(M0_AXI_ARLEN),
        .M0_AXI_ARSIZE(M0_AXI_ARSIZE),
        .M0_AXI_ARBURST(M0_AXI_ARBURST),
        .M0_AXI_ARLOCK(M0_AXI_ARLOCK),
        .M0_AXI_ARCACHE(M0_AXI_ARCACHE),
        .M0_AXI_ARPROT(M0_AXI_ARPROT),
        .M0_AXI_ARREGION(M0_AXI_ARREGION),
        .M0_AXI_ARQOS(M0_AXI_ARQOS),
        .M0_AXI_ARVALID(M0_AXI_ARVALID),
        .M0_AXI_ARREADY(M0_AXI_ARREADY),
        .M0_AXI_RDATA(M0_AXI_RDATA),
        .M0_AXI_RRESP(M0_AXI_RRESP),
        .M0_AXI_RLAST(M0_AXI_RLAST),
        .M0_AXI_RVALID(M0_AXI_RVALID),
        .M0_AXI_RREADY(M0_AXI_RREADY),
        // Master Port 1: Keystone Coprocessor DMA
        .M1_AXI_AWADDR(M1_AXI_AWADDR),
        .M1_AXI_AWLEN(M1_AXI_AWLEN),
        .M1_AXI_AWSIZE(M1_AXI_AWSIZE),
        .M1_AXI_AWBURST(M1_AXI_AWBURST),
        .M1_AXI_AWLOCK(M1_AXI_AWLOCK),
        .M1_AXI_AWCACHE(M1_AXI_AWCACHE),
        .M1_AXI_AWPROT(M1_AXI_AWPROT),
        .M1_AXI_AWVALID(M1_AXI_AWVALID),
        .M1_AXI_AWREADY(M1_AXI_AWREADY),
        .M1_AXI_WDATA(M1_AXI_WDATA),
        .M1_AXI_WSTRB(M1_AXI_WSTRB),
        .M1_AXI_WLAST(M1_AXI_WLAST),
        .M1_AXI_WVALID(M1_AXI_WVALID),
        .M1_AXI_WREADY(M1_AXI_WREADY),
        .M1_AXI_BRESP(M1_AXI_BRESP),
        .M1_AXI_BVALID(M1_AXI_BVALID),
        .M1_AXI_BREADY(M1_AXI_BREADY),
        .M1_AXI_ARADDR(M1_AXI_ARADDR),
        .M1_AXI_ARLEN(M1_AXI_ARLEN),
        .M1_AXI_ARSIZE(M1_AXI_ARSIZE),
        .M1_AXI_ARBURST(M1_AXI_ARBURST),
        .M1_AXI_ARLOCK(M1_AXI_ARLOCK),
        .M1_AXI_ARCACHE(M1_AXI_ARCACHE),
        .M1_AXI_ARPROT(M1_AXI_ARPROT),
        .M1_AXI_ARVALID(M1_AXI_ARVALID),
        .M1_AXI_ARREADY(M1_AXI_ARREADY),
        .M1_AXI_RDATA(M1_AXI_RDATA),
        .M1_AXI_RRESP(M1_AXI_RRESP),
        .M1_AXI_RLAST(M1_AXI_RLAST),
        .M1_AXI_RVALID(M1_AXI_RVALID),
        .M1_AXI_RREADY(M1_AXI_RREADY),
        // Slave Port 0: Main Memory
        .S0_AXI_AWADDR(S0_AXI_AWADDR),
        .S0_AXI_AWLEN(S0_AXI_AWLEN),
        .S0_AXI_AWSIZE(S0_AXI_AWSIZE),
        .S0_AXI_AWBURST(S0_AXI_AWBURST),
        .S0_AXI_AWLOCK(S0_AXI_AWLOCK),
        .S0_AXI_AWCACHE(S0_AXI_AWCACHE),
        .S0_AXI_AWPROT(S0_AXI_AWPROT),
        .S0_AXI_AWREGION(S0_AXI_AWREGION),
        .S0_AXI_AWQOS(S0_AXI_AWQOS),
        .S0_AXI_AWVALID(S0_AXI_AWVALID),
        .S0_AXI_AWREADY(S0_AXI_AWREADY),
        .S0_AXI_WDATA(S0_AXI_WDATA),
        .S0_AXI_WSTRB(S0_AXI_WSTRB),
        .S0_AXI_WLAST(S0_AXI_WLAST),
        .S0_AXI_WVALID(S0_AXI_WVALID),
        .S0_AXI_WREADY(S0_AXI_WREADY),
        .S0_AXI_BRESP(S0_AXI_BRESP),
        .S0_AXI_BVALID(S0_AXI_BVALID),
        .S0_AXI_BREADY(S0_AXI_BREADY),
        .S0_AXI_ARADDR(S0_AXI_ARADDR),
        .S0_AXI_ARLEN(S0_AXI_ARLEN),
        .S0_AXI_ARSIZE(S0_AXI_ARSIZE),
        .S0_AXI_ARBURST(S0_AXI_ARBURST),
        .S0_AXI_ARLOCK(S0_AXI_ARLOCK),
        .S0_AXI_ARCACHE(S0_AXI_ARCACHE),
        .S0_AXI_ARPROT(S0_AXI_ARPROT),
        .S0_AXI_ARREGION(S0_AXI_ARREGION),
        .S0_AXI_ARQOS(S0_AXI_ARQOS),
        .S0_AXI_ARVALID(S0_AXI_ARVALID),
        .S0_AXI_ARREADY(S0_AXI_ARREADY),
        .S0_AXI_RDATA(S0_AXI_RDATA),
        .S0_AXI_RRESP(S0_AXI_RRESP),
        .S0_AXI_RLAST(S0_AXI_RLAST),
        .S0_AXI_RVALID(S0_AXI_RVALID),
        .S0_AXI_RREADY(S0_AXI_RREADY),
        // Slave Port 1: Keystone Coprocessor CSRs
        .S1_AXI_AWADDR(S1_AXI_AWADDR),
        .S1_AXI_AWPROT(S1_AXI_AWPROT),
        .S1_AXI_AWVALID(S1_AXI_AWVALID),
        .S1_AXI_AWREADY(S1_AXI_AWREADY),
        .S1_AXI_WDATA(S1_AXI_WDATA),
        .S1_AXI_WSTRB(S1_AXI_WSTRB),
        .S1_AXI_WVALID(S1_AXI_WVALID),
        .S1_AXI_WREADY(S1_AXI_WREADY),
        .S1_AXI_BRESP(S1_AXI_BRESP),
        .S1_AXI_BVALID(S1_AXI_BVALID),
        .S1_AXI_BREADY(S1_AXI_BREADY),
        .S1_AXI_ARADDR(S1_AXI_ARADDR),
        .S1_AXI_ARPROT(S1_AXI_ARPROT),
        .S1_AXI_ARVALID(S1_AXI_ARVALID),
        .S1_AXI_ARREADY(S1_AXI_ARREADY),
        .S1_AXI_RDATA(S1_AXI_RDATA),
        .S1_AXI_RRESP(S1_AXI_RRESP),
        .S1_AXI_RVALID(S1_AXI_RVALID),
        .S1_AXI_RREADY(S1_AXI_RREADY),
        // Slave Port 2: Generic Peripherals
        .S2_AXI_AWADDR(S2_AXI_AWADDR),
        .S2_AXI_AWPROT(S2_AXI_AWPROT),
        .S2_AXI_AWVALID(S2_AXI_AWVALID),
        .S2_AXI_AWREADY(S2_AXI_AWREADY),
        .S2_AXI_WDATA(S2_AXI_WDATA),
        .S2_AXI_WSTRB(S2_AXI_WSTRB),
        .S2_AXI_WVALID(S2_AXI_WVALID),
        .S2_AXI_WREADY(S2_AXI_WREADY),
        .S2_AXI_BRESP(S2_AXI_BRESP),
        .S2_AXI_BVALID(S2_AXI_BVALID),
        .S2_AXI_BREADY(S2_AXI_BREADY),
        .S2_AXI_ARADDR(S2_AXI_ARADDR),
        .S2_AXI_ARPROT(S2_AXI_ARPROT),
        .S2_AXI_ARVALID(S2_AXI_ARVALID),
        .S2_AXI_ARREADY(S2_AXI_ARREADY),
        .S2_AXI_RDATA(S2_AXI_RDATA),
        .S2_AXI_RRESP(S2_AXI_RRESP),
        .S2_AXI_RVALID(S2_AXI_RVALID),
        .S2_AXI_RREADY(S2_AXI_RREADY)
    );

    // --- Instantiate Main Memory Controller Stub ---
    Main_Memory_Ctrl_Stub main_mem_ctrl_inst (
        .clk(clk),
        .resetn(resetn),
        .S_AXI_AWADDR(S0_AXI_AWADDR),
        .S_AXI_AWLEN(S0_AXI_AWLEN),
        .S_AXI_AWSIZE(S0_AXI_AWSIZE),
        .S_AXI_AWBURST(S0_AXI_AWBURST),
        .S_AXI_AWLOCK(S0_AXI_AWLOCK),
        .S_AXI_AWCACHE(S0_AXI_AWCACHE),
        .S_AXI_AWPROT(S0_AXI_AWPROT),
        .S_AXI_AWREGION(S0_AXI_AWREGION),
        .S_AXI_AWQOS(S0_AXI_AWQOS),
        .S_AXI_AWVALID(S0_AXI_AWVALID),
        .S_AXI_AWREADY(S0_AXI_AWREADY),
        .S_AXI_WDATA(S0_AXI_WDATA),
        .S_AXI_WSTRB(S0_AXI_WSTRB),
        .S_AXI_WLAST(S0_AXI_WLAST),
        .S_AXI_WVALID(S0_AXI_WVALID),
        .S_AXI_WREADY(S0_AXI_WREADY),
        .S_AXI_BRESP(S0_AXI_BRESP),
        .S_AXI_BVALID(S0_AXI_BVALID),
        .S_AXI_BREADY(S0_AXI_BREADY),
        .S_AXI_ARADDR(S0_AXI_ARADDR),
        .S_AXI_ARLEN(S0_AXI_ARLEN),
        .S_AXI_ARSIZE(S0_AXI_ARSIZE),
        .S_AXI_ARBURST(S0_AXI_ARBURST),
        .S_AXI_ARLOCK(S0_AXI_ARLOCK),
        .S_AXI_ARCACHE(S0_AXI_ARCACHE),
        .S_AXI_ARPROT(S0_AXI_ARPROT),
        .S_AXI_ARREGION(S0_AXI_ARREGION),
        .S_AXI_ARQOS(S0_AXI_ARQOS),
        .S_AXI_ARVALID(S0_AXI_ARVALID),
        .S_AXI_ARREADY(S0_AXI_ARREADY),
        .S_AXI_RDATA(S0_AXI_RDATA),
        .S_AXI_RRESP(S0_AXI_RRESP),
        .S_AXI_RLAST(S0_AXI_RLAST),
        .S_AXI_RVALID(S0_AXI_RVALID),
        .S_AXI_RREADY(S0_AXI_RREADY)
    );

    // --- Instantiate Boot ROM Stub ---
    Boot_ROM_Stub boot_rom_inst (
        .clk(clk),
        .resetn(resetn),
        .boot_addr_i(boot_addr_w), // From CVA6
        .boot_data_o(boot_data_w)  // To CVA6
    );

    // --- Instantiate Generic Peripherals Stub ---
    Peripherals_Stub peripherals_inst (
        .clk(clk),
        .resetn(resetn),
        // AXI-Lite Slave Port (S2 on Interconnect)
        .S_AXI_AWADDR(S2_AXI_AWADDR),
        .S_AXI_AWPROT(S2_AXI_AWPROT),
        .S_AXI_AWVALID(S2_AXI_AWVALID),
        .S_AXI_AWREADY(S2_AXI_AWREADY),
        .S_AXI_WDATA(S2_AXI_WDATA),
        .S_AXI_WSTRB(S2_AXI_WSTRB),
        .S_AXI_WVALID(S2_AXI_WVALID),
        .S_AXI_WREADY(S2_AXI_WREADY),
        .S_AXI_BRESP(S2_AXI_BRESP),
        .S_AXI_BVALID(S2_AXI_BVALID),
        .S_AXI_BREADY(S2_AXI_BREADY),
        .S_AXI_ARADDR(S2_AXI_ARADDR),
        .S_AXI_ARPROT(S2_AXI_ARPROT),
        .S_AXI_ARVALID(S2_AXI_ARVALID),
        .S_AXI_ARREADY(S2_AXI_ARREADY),
        .S_AXI_RDATA(S2_AXI_RDATA),
        .S_AXI_RRESP(S2_AXI_RRESP),
        .S_AXI_RVALID(S2_AXI_RVALID),
        .S_AXI_RREADY(S2_AXI_RREADY),
        // Peripheral I/O
        .uart_tx_o(uart_tx_o),
        .uart_rx_i(uart_rx_i)
        // .gpio_out_o(), // Not connected at top-level for now
        // .gpio_in_i()   // Not connected at top-level for now
    );

endmodule
