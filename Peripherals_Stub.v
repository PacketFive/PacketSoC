// Generic Peripherals Stub
// Date: 2024-03-14
`timescale 1ns / 1ps

module Peripherals_Stub (
    input  wire         clk,
    input  wire         resetn,

    // AXI4-Lite Slave Port (from AXI_Interconnect)
    // Write Address Channel
    input  wire [31:0]  S_AXI_AWADDR, // Full 32-bit address for interconnect decoding ease
    input  wire [2:0]   S_AXI_AWPROT,
    input  wire         S_AXI_AWVALID,
    output wire         S_AXI_AWREADY,
    // Write Data Channel
    input  wire [31:0]  S_AXI_WDATA,
    input  wire [3:0]   S_AXI_WSTRB,
    input  wire         S_AXI_WVALID,
    output wire         S_AXI_WREADY,
    // Write Response Channel
    output wire [1:0]   S_AXI_BRESP,
    output wire         S_AXI_BVALID,
    input  wire         S_AXI_BREADY,
    // Read Address Channel
    input  wire [31:0]  S_AXI_ARADDR,
    input  wire [2:0]   S_AXI_ARPROT,
    input  wire         S_AXI_ARVALID,
    output wire         S_AXI_ARREADY,
    // Read Data Channel
    output wire [31:0]  S_AXI_RDATA,
    output wire [1:0]   S_AXI_RRESP,
    output wire         S_AXI_RVALID,
    input  wire         S_AXI_RREADY,

    // Example Peripheral I/O (can be expanded)
    output wire        uart_tx_o,
    input  wire        uart_rx_i,
    output wire [7:0]  gpio_out_o,
    input  wire [7:0]  gpio_in_i
);

    // Stub behavior: Always ready, respond with OKAY, return dummy data.
    // Minimal register logic for UART Tx/Rx data registers (conceptual).

    localparam UART_TX_REG_OFFSET = 16'h0000; // Relative to peripheral base
    localparam UART_RX_REG_OFFSET = 16'h0004;
    localparam UART_STATUS_REG_OFFSET = 16'h0008; // Bit 0: RX_VALID, Bit 1: TX_READY

    reg [31:0] uart_tx_reg_r;
    reg [31:0] uart_rx_reg_r; // CPU reads this, can be written by simulation
    reg        uart_rx_valid_r;

    // AXI Write Logic (Simplified)
    assign S_AXI_AWREADY = 1'b1;
    assign S_AXI_WREADY  = 1'b1;
    
    reg s_axi_bvalid_r;
    always @(posedge clk or negedge resetn) begin
        if (!resetn) begin
            s_axi_bvalid_r <= 1'b0;
            uart_tx_reg_r  <= 32'b0;
        end else begin
            if (S_AXI_AWVALID && S_AXI_AWREADY && S_AXI_WVALID && S_AXI_WREADY) begin
                s_axi_bvalid_r <= 1'b1;
                // Check address offset (lower bits of S_AXI_AWADDR)
                // For simplicity, assume S_AXI_AWADDR[15:0] is the offset within peripheral region
                if (S_AXI_AWADDR[15:0] == UART_TX_REG_OFFSET) begin
                    uart_tx_reg_r <= S_AXI_WDATA;
                end
            end else if (S_AXI_BREADY && s_axi_bvalid_r) begin
                s_axi_bvalid_r <= 1'b0;
            end
        end
    end
    assign S_AXI_BVALID = s_axi_bvalid_r;
    assign S_AXI_BRESP  = 2'b00; // OKAY

    // AXI Read Logic (Simplified)
    assign S_AXI_ARREADY = 1'b1;
    reg s_axi_rvalid_r;
    reg [31:0] s_axi_rdata_r;

    always @(posedge clk or negedge resetn) begin
        if (!resetn) begin
            s_axi_rvalid_r <= 1'b0;
            s_axi_rdata_r  <= 32'b0;
            uart_rx_reg_r <= 32'b0;
            uart_rx_valid_r <= 1'b0;
        end else begin
            if (S_AXI_ARVALID && S_AXI_ARREADY) begin
                s_axi_rvalid_r <= 1'b1;
                // Check address offset
                if (S_AXI_ARADDR[15:0] == UART_RX_REG_OFFSET) begin
                    s_axi_rdata_r <= uart_rx_reg_r;
                    uart_rx_valid_r <= 1'b0; // Clear valid on read
                end else if (S_AXI_ARADDR[15:0] == UART_STATUS_REG_OFFSET) begin
                    s_axi_rdata_r <= {30'b0, 1'b1, uart_rx_valid_r}; // TX_READY=1, RX_VALID
                end else if (S_AXI_ARADDR[15:0] == UART_TX_REG_OFFSET) begin
                     s_axi_rdata_r <= uart_tx_reg_r; // Allow reading TX reg
                end else begin
                    s_axi_rdata_r <= 32'hDEADBEEF; // Unmapped peripheral register
                end
            end else if (S_AXI_RREADY && s_axi_rvalid_r) begin
                s_axi_rvalid_r <= 1'b0;
            end
        end
    end
    assign S_AXI_RVALID = s_axi_rvalid_r;
    assign S_AXI_RDATA  = s_axi_rdata_r;
    assign S_AXI_RRESP  = 2'b00; // OKAY

    // Dummy peripheral logic
    assign uart_tx_o = uart_tx_reg_r[0]; // Example: LSB of TX reg drives UART TX
    // In a real UART, uart_rx_i would eventually set uart_rx_valid_r and fill uart_rx_reg_r.
    // For stub, simulate external write to uart_rx_reg_r for testing:
    // E.g. `initial begin #1000 uart_rx_reg_r = "H"; uart_rx_valid_r = 1; ... end`

    assign gpio_out_o = 8'h00; // Tied off for stub
    // gpio_in_i is an input

endmodule
