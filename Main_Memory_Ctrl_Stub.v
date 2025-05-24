// Main Memory Controller Stub
// Date: 2024-03-14
`timescale 1ns / 1ps

module Main_Memory_Ctrl_Stub (
    input  wire         clk,
    input  wire         resetn,

    // AXI4 Full Slave Port (from AXI_Interconnect)
    // Write Address Channel
    input  wire [31:0]  S_AXI_AWADDR,
    input  wire [7:0]   S_AXI_AWLEN,
    input  wire [2:0]   S_AXI_AWSIZE,
    input  wire [1:0]   S_AXI_AWBURST,
    input  wire         S_AXI_AWLOCK,
    input  wire [3:0]   S_AXI_AWCACHE,
    input  wire [2:0]   S_AXI_AWPROT,
    input  wire [3:0]   S_AXI_AWREGION,
    input  wire [3:0]   S_AXI_AWQOS,
    input  wire         S_AXI_AWVALID,
    output wire         S_AXI_AWREADY,
    // Write Data Channel
    input  wire [31:0]  S_AXI_WDATA, // Assuming 32-bit data bus
    input  wire [3:0]   S_AXI_WSTRB,
    input  wire         S_AXI_WLAST,
    input  wire         S_AXI_WVALID,
    output wire         S_AXI_WREADY,
    // Write Response Channel
    output wire [1:0]   S_AXI_BRESP,
    output wire         S_AXI_BVALID,
    input  wire         S_AXI_BREADY,
    // Read Address Channel
    input  wire [31:0]  S_AXI_ARADDR,
    input  wire [7:0]   S_AXI_ARLEN,
    input  wire [2:0]   S_AXI_ARSIZE,
    input  wire [1:0]   S_AXI_ARBURST,
    input  wire         S_AXI_ARLOCK,
    input  wire [3:0]   S_AXI_ARCACHE,
    input  wire [2:0]   S_AXI_ARPROT,
    input  wire [3:0]   S_AXI_ARREGION,
    input  wire [3:0]   S_AXI_ARQOS,
    input  wire         S_AXI_ARVALID,
    output wire         S_AXI_ARREADY,
    // Read Data Channel
    output wire [31:0]  S_AXI_RDATA,
    output wire [1:0]   S_AXI_RRESP,
    output wire         S_AXI_RLAST,
    output wire         S_AXI_RVALID,
    input  wire         S_AXI_RREADY
);

    // Stub behavior: Always ready, respond with OKAY, return dummy data.
    // This is a very basic stub and does not model actual memory behavior.

    // Write Address Channel
    assign S_AXI_AWREADY = 1'b1; // Always ready to accept address

    // Write Data Channel
    assign S_AXI_WREADY = 1'b1;  // Always ready to accept data

    // Write Response Channel
    reg bvalid_r;
    reg [1:0] bresp_r;
    always @(posedge clk or negedge resetn) begin
        if (!resetn) begin
            bvalid_r <= 1'b0;
            bresp_r  <= 2'b00;
        end else begin
            if (S_AXI_AWVALID && S_AXI_AWREADY && S_AXI_WVALID && S_AXI_WREADY && S_AXI_WLAST) begin // End of write burst
                bvalid_r <= 1'b1;
                bresp_r  <= 2'b00; // OKAY
            end else if (S_AXI_BREADY && bvalid_r) begin
                bvalid_r <= 1'b0;
            end
        end
    end
    assign S_AXI_BVALID = bvalid_r;
    assign S_AXI_BRESP  = bresp_r;

    // Read Address Channel
    assign S_AXI_ARREADY = 1'b1; // Always ready to accept address

    // Read Data Channel
    reg rvalid_r;
    reg [31:0] rdata_r;
    reg rlast_r;
    reg [1:0] rresp_r;

    // Counter for burst length (simplified)
    reg [7:0] arlen_cnt_r;
    reg ar_active_r; // Indicates an AR transaction is active

    always @(posedge clk or negedge resetn) begin
        if (!resetn) begin
            rvalid_r <= 1'b0;
            rdata_r  <= 32'h0;
            rlast_r  <= 1'b0;
            rresp_r  <= 2'b00;
            arlen_cnt_r <= 8'd0;
            ar_active_r <= 1'b0;
        end else begin
            if (S_AXI_ARVALID && S_AXI_ARREADY && !ar_active_r) begin // New read request
                ar_active_r <= 1'b1;
                arlen_cnt_r <= S_AXI_ARLEN; // Capture burst length
                rvalid_r    <= 1'b1;       // First beat is available "immediately"
                rdata_r     <= S_AXI_ARADDR; // Dummy data: return address
                rresp_r     <= 2'b00;      // OKAY
                rlast_r     <= (S_AXI_ARLEN == 0);
            end else if (rvalid_r && S_AXI_RREADY && ar_active_r) begin // Subsequent beats
                if (arlen_cnt_r > 0) begin
                    arlen_cnt_r <= arlen_cnt_r - 1;
                    rvalid_r    <= 1'b1;
                    rdata_r     <= rdata_r + 32'd4; // Increment dummy data
                    rlast_r     <= (arlen_cnt_r == 1); // Next beat will be the last
                end else begin // Current beat was the last
                    rvalid_r    <= 1'b0;
                    rlast_r     <= 1'b0;
                    ar_active_r <= 1'b0;
                end
            end else if (!S_AXI_RREADY && rvalid_r) begin
                // Master not ready, hold data and valid
            end else if (ar_active_r && !rvalid_r && arlen_cnt_r == 0 && !rlast_r) {
                 // This case handles the cycle after the last beat was sent and accepted
                 ar_active_r <= 1'b0;
            }
        end
    end
    assign S_AXI_RVALID = rvalid_r;
    assign S_AXI_RDATA  = rdata_r;
    assign S_AXI_RLAST  = rlast_r;
    assign S_AXI_RRESP  = rresp_r;

endmodule
