// CVA6 Core Stub (Placeholder)
// Date: 2024-03-14
`timescale 1ns / 1ps

module CVA6_Core_Stub (
    input  wire         clk,
    input  wire         resetn, // Active low reset

    // AXI4 Full Master Port (to AXI_Interconnect)
    // Write Address Channel
    output wire [31:0]  M_AXI_AWADDR,
    output wire [7:0]   M_AXI_AWLEN,
    output wire [2:0]   M_AXI_AWSIZE,
    output wire [1:0]   M_AXI_AWBURST,
    output wire         M_AXI_AWLOCK,
    output wire [3:0]   M_AXI_AWCACHE,
    output wire [2:0]   M_AXI_AWPROT,
    output wire [3:0]   M_AXI_AWREGION,
    output wire [3:0]   M_AXI_AWQOS,
    output wire         M_AXI_AWVALID,
    input  wire         M_AXI_AWREADY,
    // Write Data Channel
    output wire [31:0]  M_AXI_WDATA,
    output wire [3:0]   M_AXI_WSTRB,
    output wire         M_AXI_WLAST,
    output wire         M_AXI_WVALID,
    input  wire         M_AXI_WREADY,
    // Write Response Channel
    input  wire [1:0]   M_AXI_BRESP,
    input  wire         M_AXI_BVALID,
    output wire         M_AXI_BREADY,
    // Read Address Channel
    output wire [31:0]  M_AXI_ARADDR,
    output wire [7:0]   M_AXI_ARLEN,
    output wire [2:0]   M_AXI_ARSIZE,
    output wire [1:0]   M_AXI_ARBURST,
    output wire         M_AXI_ARLOCK,
    output wire [3:0]   M_AXI_ARCACHE,
    output wire [2:0]   M_AXI_ARPROT,
    output wire [3:0]   M_AXI_ARREGION,
    output wire [3:0]   M_AXI_ARQOS,
    output wire         M_AXI_ARVALID,
    input  wire         M_AXI_ARREADY,
    // Read Data Channel
    input  wire [31:0]  M_AXI_RDATA,
    input  wire [1:0]   M_AXI_RRESP,
    input  wire         M_AXI_RLAST,
    input  wire         M_AXI_RVALID,
    output wire         M_AXI_RREADY,

    // Boot Interface (Simplified for stub)
    output wire [15:0]  boot_addr_o, // To Boot ROM
    input  wire [31:0]  boot_data_i, // From Boot ROM

    // Interrupts
    input  wire         copro_irq_i, // From Keystone Coprocessor
    input  wire         timer_irq_i, // Example timer interrupt
    input  wire         sw_irq_i     // Example software interrupt
);

    // Stub Behavior:
    // - Issue a read request to Boot ROM address (e.g., 0x00010000) after reset.
    // - Then, issue a read request to Main Memory (e.g., 0x80000000).
    // - Then, issue a write then read to Keystone Coprocessor CSRs (e.g., 0x10000000).
    // - Then, issue a write then read to Generic Peripherals (e.g., 0x02000000).
    // - Drive AXI signals with some default/idle values.

    reg [31:0] m_axi_araddr_r;
    reg        m_axi_arvalid_r;
    reg [31:0] m_axi_awaddr_r;
    reg        m_axi_awvalid_r;
    reg [31:0] m_axi_wdata_r;
    reg        m_axi_wvalid_r;
    reg        m_axi_wlast_r;
    reg        m_axi_rready_r;
    reg        m_axi_bready_r;

    assign M_AXI_ARADDR = m_axi_araddr_r;
    assign M_AXI_ARLEN  = 8'd0; // Single beat
    assign M_AXI_ARSIZE = 3'b010; // 32-bit
    assign M_AXI_ARBURST= 2'b01; // INCR
    assign M_AXI_ARLOCK = 1'b0;
    assign M_AXI_ARCACHE= 4'b0000;
    assign M_AXI_ARPROT = 3'b000;
    assign M_AXI_ARREGION=4'b0000;
    assign M_AXI_ARQOS  = 4'b0000;
    assign M_AXI_ARVALID= m_axi_arvalid_r;

    assign M_AXI_AWADDR = m_axi_awaddr_r;
    assign M_AXI_AWLEN  = 8'd0; // Single beat
    assign M_AXI_AWSIZE = 3'b010; // 32-bit
    assign M_AXI_AWBURST= 2'b01; // INCR
    assign M_AXI_AWLOCK = 1'b0;
    assign M_AXI_AWCACHE= 4'b0010; // Bufferable
    assign M_AXI_AWPROT = 3'b000;
    assign M_AXI_AWREGION=4'b0000;
    assign M_AXI_AWQOS  = 4'b0000;
    assign M_AXI_AWVALID= m_axi_awvalid_r;

    assign M_AXI_WDATA  = m_axi_wdata_r;
    assign M_AXI_WSTRB  = 4'b1111; // Full word write
    assign M_AXI_WLAST  = m_axi_wlast_r;
    assign M_AXI_WVALID = m_axi_wvalid_r;

    assign M_AXI_RREADY = m_axi_rready_r;
    assign M_AXI_BREADY = m_axi_bready_r;

    // Simplified boot address
    assign boot_addr_o = 16'h0000; // Read from start of Boot ROM

    // Stub FSM for generating some AXI traffic
    localparam IDLE = 0, BOOT_FETCH = 1, MEM_READ_ADDR = 2, MEM_READ_DATA =3,
               COPRO_WRITE_ADDR = 4, COPRO_WRITE_DATA = 5, COPRO_WRITE_RESP = 6,
               COPRO_READ_ADDR = 7, COPRO_READ_DATA = 8,
               PERIPH_WRITE_ADDR = 9, PERIPH_WRITE_DATA = 10, PERIPH_WRITE_RESP = 11,
               PERIPH_READ_ADDR = 12, PERIPH_READ_DATA = 13,
               DONE = 14;
    reg [3:0] state_r;

    always @(posedge clk or negedge resetn) begin
        if (!resetn) begin
            state_r <= BOOT_FETCH; // Start with boot fetch
            m_axi_arvalid_r <= 1'b0;
            m_axi_awvalid_r <= 1'b0;
            m_axi_wvalid_r  <= 1'b0;
            m_axi_wlast_r   <= 1'b0;
            m_axi_rready_r  <= 1'b0;
            m_axi_bready_r  <= 1'b0;
        end else begin
            // Default de-assertions
            m_axi_arvalid_r <= 1'b0;
            m_axi_awvalid_r <= 1'b0;
            m_axi_wvalid_r  <= 1'b0;
            // m_axi_wlast_r is asserted with wvalid for single beat

            case (state_r)
                BOOT_FETCH: begin // Using boot_data_i, not AXI for this stub's boot
                    // After boot_data_i is loaded (simulated by a delay or external stimulus), move to next state
                    // For now, just move after a few cycles.
                    if (boot_data_i != 32'h0) begin // Wait for some valid boot data (placeholder)
                        state_r <= MEM_READ_ADDR;
                    end
                end
                MEM_READ_ADDR: begin
                    m_axi_araddr_r  <= 32'h80000000; // Read from Main Memory
                    m_axi_arvalid_r <= 1'b1;
                    if (M_AXI_ARREADY) begin
                        m_axi_arvalid_r <= 1'b0;
                        state_r <= MEM_READ_DATA;
                    end
                end
                MEM_READ_DATA: begin
                    m_axi_rready_r <= 1'b1;
                    if (M_AXI_RVALID) begin
                        m_axi_rready_r <= 1'b0;
                        state_r <= COPRO_WRITE_ADDR;
                    end
                end
                COPRO_WRITE_ADDR: begin
                    m_axi_awaddr_r <= 32'h10000004; // Keystone VM_SELECT_REG
                    m_axi_wdata_r  <= 32'h00000001; // Select VM 1
                    m_axi_awvalid_r <= 1'b1;
                    if (M_AXI_AWREADY) begin
                        m_axi_awvalid_r <= 1'b0;
                        state_r <= COPRO_WRITE_DATA;
                    end
                end
                COPRO_WRITE_DATA: begin
                    m_axi_wvalid_r <= 1'b1;
                    m_axi_wlast_r  <= 1'b1; // Single beat write
                    if (M_AXI_WREADY) begin
                        m_axi_wvalid_r <= 1'b0;
                        m_axi_wlast_r  <= 1'b0;
                        state_r <= COPRO_WRITE_RESP;
                    end
                end
                COPRO_WRITE_RESP: begin
                    m_axi_bready_r <= 1'b1;
                    if (M_AXI_BVALID) begin
                        m_axi_bready_r <= 1'b0;
                        state_r <= COPRO_READ_ADDR;
                    end
                end
                COPRO_READ_ADDR: begin
                    m_axi_araddr_r  <= 32'h10000008; // Keystone COPRO_STATUS_REG
                    m_axi_arvalid_r <= 1'b1;
                    if (M_AXI_ARREADY) begin
                        m_axi_arvalid_r <= 1'b0;
                        state_r <= COPRO_READ_DATA;
                    end
                end
                COPRO_READ_DATA: begin
                    m_axi_rready_r <= 1'b1;
                    if (M_AXI_RVALID) begin
                        m_axi_rready_r <= 1'b0;
                        state_r <= PERIPH_WRITE_ADDR;
                    end
                end
                // Similar sequence for PERIPH_WRITE and PERIPH_READ
                PERIPH_WRITE_ADDR: begin
                    m_axi_awaddr_r <= 32'h02000000; // UART TX Reg
                    m_axi_wdata_r  <= 32'h00000041; // 'A'
                    m_axi_awvalid_r <= 1'b1;
                    if (M_AXI_AWREADY) begin
                        m_axi_awvalid_r <= 1'b0;
                        state_r <= PERIPH_WRITE_DATA;
                    end
                end
                PERIPH_WRITE_DATA: begin
                    m_axi_wvalid_r <= 1'b1;
                    m_axi_wlast_r  <= 1'b1;
                    if (M_AXI_WREADY) begin
                        m_axi_wvalid_r <= 1'b0;
                        m_axi_wlast_r  <= 1'b0;
                        state_r <= PERIPH_WRITE_RESP;
                    end
                end
                PERIPH_WRITE_RESP: begin
                    m_axi_bready_r <= 1'b1;
                    if (M_AXI_BVALID) begin
                        m_axi_bready_r <= 1'b0;
                        state_r <= PERIPH_READ_ADDR;
                    end
                end
                PERIPH_READ_ADDR: begin
                    m_axi_araddr_r  <= 32'h02000008; // UART Status Reg
                    m_axi_arvalid_r <= 1'b1;
                    if (M_AXI_ARREADY) begin
                        m_axi_arvalid_r <= 1'b0;
                        state_r <= PERIPH_READ_DATA;
                    end
                end
                PERIPH_READ_DATA: begin
                    m_axi_rready_r <= 1'b1;
                    if (M_AXI_RVALID) begin
                        m_axi_rready_r <= 1'b0;
                        state_r <= DONE;
                    end
                end
                DONE: begin
                    // Stay here
                end
                default: state_r <= IDLE;
            endcase
        end
    end

endmodule
