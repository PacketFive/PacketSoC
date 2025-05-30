// SoC Testbench Top Module
// Date: 2024-03-14

`timescale 1ns / 1ps

module SoC_tb;

    // Clock and Reset Signals
    logic clk;
    logic resetn; // Active low reset

    // DUT Interface Wires
    wire uart_tx_tb;
    logic uart_rx_tb; // Can be driven by testbench if needed, tied off for now

    // Instantiate the DUT (Device Under Test)
    SoC_Top dut (
        .clk(clk),
        .resetn(resetn),
        .uart_tx_o(uart_tx_tb),
        .uart_rx_i(uart_rx_tb)
    );

    // Clock Generation (e.g., 100MHz clock -> 10ns period)
    localparam CLK_PERIOD = 10; // ns

    // Keystone Coprocessor CSR Addresses (relative to its base 0x1000_0000)
    localparam KEYSTONE_COPRO_CSR_BASE_ADDR = 32'h1000_0000;
    // Offsets from AXI_Lite_Memory_Map.txt
    localparam ADDR_COPRO_CMD_REG                = 32'h00;
    localparam ADDR_VM_SELECT_REG                = 32'h04;
    localparam ADDR_COPRO_STATUS_REG             = 32'h08;
    localparam ADDR_PROG_ADDR_LOW_REG            = 32'h0C;
    localparam ADDR_PROG_ADDR_HIGH_REG           = 32'h10;
    localparam ADDR_DATA_IN_ADDR_LOW_REG         = 32'h14;
    localparam ADDR_DATA_IN_ADDR_HIGH_REG        = 32'h18;
    localparam ADDR_DATA_OUT_ADDR_LOW_REG        = 32'h1C;
    localparam ADDR_DATA_OUT_ADDR_HIGH_REG       = 32'h20;
    localparam ADDR_DATA_LEN_REG                 = 32'h24;
    localparam ADDR_INT_STATUS_REG               = 32'h28;
    localparam ADDR_INT_ENABLE_REG               = 32'h2C;
    localparam ADDR_SELECTED_VM_STATUS_REG       = 32'h30;
    localparam ADDR_SELECTED_VM_PC_REG           = 32'h34;
    localparam ADDR_SELECTED_VM_DATA_OUT_ADDR_REG = 32'h38;
    localparam ADDR_MAILBOX_DATA_IN_0_REG        = 32'h80;
    localparam ADDR_MAILBOX_DATA_OUT_0_REG       = 32'hA0;
    localparam ADDR_COPRO_VERSION_REG            = 32'hFC;

    // AXI Response Types
    localparam AXI_RESP_OKAY   = 2'b00;
    localparam AXI_RESP_EXOKAY = 2'b01;
    localparam AXI_RESP_SLVERR = 2'b10;
    localparam AXI_RESP_DECERR = 2'b11;


    initial begin
        clk = 1'b0;
        forever #(CLK_PERIOD / 2) clk = ~clk;
    end

    // Reset Generation
    initial begin
        resetn = 1'b0; // Assert reset
        repeat (5) @(posedge clk); // Wait for a few clock cycles
        resetn = 1'b1; // De-assert reset
        repeat (2) @(posedge clk); // Allow some cycles for reset to propagate
    end

    // Simulation Control and Test Case TC1
    initial begin
        // --- Test Case TC1 Start: SoC Boot & CVA6 Stub Basic UART Output ---
        $display("[%0t ns] Starting SoC Testbench and TC1: SoC Boot & CVA6 Stub Basic UART Output...", $time);

        // Waveform Dumping
        $dumpfile("soc_tb.vcd");
        $dumpvars(0, SoC_tb); // Dump all signals in SoC_tb and below

        // Tie off UART RX (idle high)
        uart_rx_tb = 1'b1;

        // Reset is handled by a separate initial block.
        // Wait for reset to complete.
        wait (resetn === 1'b1);
        @(posedge clk); // Ensure we are past the immediate de-assertion of reset
        $display("[%0t ns] TC1: Reset sequence complete.", $time);

        // The CVA6_Core_Stub will autonomously perform a sequence of operations:
        // 1. Boot fetch (simulated, not AXI)
        // 2. AXI Read from Main Memory (0x80000000)
        // 3. AXI Write to Keystone Copro (VM_SELECT_REG = 0x10000004, data = 1)
        // 4. AXI Read from Keystone Copro (COPRO_STATUS_REG = 0x10000008)
        // 5. AXI Write to Peripherals (UART_TX_REG = 0x02000000, data = 'A')
        // 6. AXI Read from Peripherals (UART_STATUS_REG = 0x02000008)
        // The UART monitor should capture and display 'A'.

        $display("[%0t ns] TC1: Waiting for CVA6 stub to execute and write to UART...", $time);
        // UART 'A' (0x41) transmission:
        // 1 start bit, 8 data bits, 1 stop bit = 10 bits.
        // Baud rate = 115200. Bit time = 1/115200 s = approx 8.68 us.
        // 10 bits * 8.68 us/bit = 86.8 us.
        // CLK_PERIOD = 10ns. So, 86.8us / 10ns = 8680 clock cycles for UART transmission.
        // Add more cycles for CVA6 stub FSM to reach UART write.
        // CVA6 stub has about 6 AXI operations before UART write. Assume ~20 cycles per AXI op for handshake.
        // 6 * 20 = 120 cycles. Plus internal FSM transitions.
        // Total estimated time: ~150 (for AXI ops) + 8680 (for UART) + buffer = ~9000 cycles.
        // Let's run for 10000 clock cycles for TC1's autonomous run.
        // TC3 will start after 10100 cycles.
        // Each AXI lite task takes roughly 10-20 cycles. TC3 has 6 tasks = ~120 cycles.
        // Total ~10100 + 120 + buffer = ~10300.
        // Extending total simulation time.
        #(12000 * CLK_PERIOD); 
        
        $display("[%0t ns] TC1: Expected UART output 'A' should have been displayed by the monitor (if CVA6 stub ran its full sequence).", $time);
        $display("[%0t ns] TC1: Test Case 1 (autonomous CVA6 stub run) phase finished.", $time);
        // $finish call will be after all test cases or at the very end.
        // For now, let TC3 run, and $finish will be at the end of TC3's block or a global one.
    end

    // --- AXI Master Tasks for Testbench Control (acting as CPU M0) ---
    task axi_write_lite(input logic [31:0] addr, input logic [31:0] data_wr);
        $display("[%0t ns] AXI_WRITE_LITE: Addr=0x%h, Data=0x%h", $time, addr, data_wr);
        // Drive Address Write Channel
        @(posedge clk);
        dut.M0_AXI_AWADDR  = addr;
        dut.M0_AXI_AWPROT  = 3'b000; // Default_prot
        dut.M0_AXI_AWVALID = 1'b1;
        // For AXI-Lite, some signals might be ignored by slave or should be default
        dut.M0_AXI_AWLEN   = 8'd0;   // Single beat
        dut.M0_AXI_AWSIZE  = 3'b010; // 4 bytes
        dut.M0_AXI_AWBURST = 2'b01;  // INCR (though single beat)

        wait (dut.M0_AXI_AWREADY === 1'b1);
        @(posedge clk);
        dut.M0_AXI_AWVALID = 1'b0;

        // Drive Write Data Channel
        dut.M0_AXI_WDATA  = data_wr;
        dut.M0_AXI_WSTRB  = 4'b1111; // Write all bytes
        dut.M0_AXI_WLAST  = 1'b1;    // Single beat
        dut.M0_AXI_WVALID = 1'b1;

        wait (dut.M0_AXI_WREADY === 1'b1);
        @(posedge clk);
        dut.M0_AXI_WVALID = 1'b0;
        dut.M0_AXI_WLAST  = 1'b0;

        // Wait for Write Response Channel
        dut.M0_AXI_BREADY = 1'b1;
        wait (dut.M0_AXI_BVALID === 1'b1);
        if (dut.M0_AXI_BRESP != AXI_RESP_OKAY) begin
            $display("[%0t ns] AXI_WRITE_LITE: Error - BRESP = %b", $time, dut.M0_AXI_BRESP);
        end
        @(posedge clk);
        dut.M0_AXI_BREADY = 1'b0;
        $display("[%0t ns] AXI_WRITE_LITE: Complete for Addr=0x%h", $time, addr);
    endtask

    task axi_read_lite(input logic [31:0] addr, output logic [31:0] data_rd);
        $display("[%0t ns] AXI_READ_LITE: Addr=0x%h", $time, addr);
        // Drive Address Read Channel
        @(posedge clk);
        dut.M0_AXI_ARADDR  = addr;
        dut.M0_AXI_ARPROT  = 3'b000;
        dut.M0_AXI_ARVALID = 1'b1;
        // For AXI-Lite
        dut.M0_AXI_ARLEN   = 8'd0;
        dut.M0_AXI_ARSIZE  = 3'b010;
        dut.M0_AXI_ARBURST = 2'b01;

        wait (dut.M0_AXI_ARREADY === 1'b1);
        @(posedge clk);
        dut.M0_AXI_ARVALID = 1'b0;

        // Wait for Read Data Channel
        dut.M0_AXI_RREADY = 1'b1;
        wait (dut.M0_AXI_RVALID === 1'b1);
        data_rd = dut.M0_AXI_RDATA;
        if (dut.M0_AXI_RRESP != AXI_RESP_OKAY) begin
            $display("[%0t ns] AXI_READ_LITE: Error - RRESP = %b", $time, dut.M0_AXI_RRESP);
        end
        // if (dut.M0_AXI_RLAST !== 1'b1) begin // For AXI-Lite, RLAST should be 1
        //     $display("[%0t ns] AXI_READ_LITE: Warning - RLAST not set for AXI-Lite read from 0x%h", $time, addr);
        // end
        @(posedge clk);
        dut.M0_AXI_RREADY = 1'b0;
        $display("[%0t ns] AXI_READ_LITE: Complete for Addr=0x%h, Data=0x%h", $time, addr, data_rd);
    endtask


    // Test Case TC3: Keystone Coprocessor CSR Access
    initial begin
        logic [31:0] rdata_tc3;
        logic tc3_passed;

        // Wait for TC1 to largely complete its autonomous sequence.
        // This is a simple delay-based sequencing.
        // A more robust method would use events or flags if CVA6_Core_Stub provided them.
        #(10100 * CLK_PERIOD); // Start TC3 after TC1's main activity + a small buffer
        tc3_passed = 1'b1;

        $display("[%0t ns] --- Starting Test Case TC3: Keystone Coprocessor CSR Access ---", $time);

        // 1. Write to VM_SELECT_REG and read back
        $display("[%0t ns] TC3: Writing 0x3 to VM_SELECT_REG (0x%h)...", $time, KEYSTONE_COPRO_CSR_BASE_ADDR + ADDR_VM_SELECT_REG);
        axi_write_lite(KEYSTONE_COPRO_CSR_BASE_ADDR + ADDR_VM_SELECT_REG, 32'h00000003);
        axi_read_lite(KEYSTONE_COPRO_CSR_BASE_ADDR + ADDR_VM_SELECT_REG, rdata_tc3);
        if (rdata_tc3 === 32'h00000003) begin
            $display("[%0t ns] TC3: VM_SELECT_REG readback PASS (Got: 0x%h)", $time, rdata_tc3);
        end else begin
            $display("[%0t ns] TC3: VM_SELECT_REG readback FAIL (Exp: 0x3, Got: 0x%h)", $time, rdata_tc3);
            tc3_passed = 1'b0;
        end

        // 2. Write to PROG_ADDR_LOW_REG and read back
        $display("[%0t ns] TC3: Writing 0x80010000 to PROG_ADDR_LOW_REG (0x%h)...", $time, KEYSTONE_COPRO_CSR_BASE_ADDR + ADDR_PROG_ADDR_LOW_REG);
        axi_write_lite(KEYSTONE_COPRO_CSR_BASE_ADDR + ADDR_PROG_ADDR_LOW_REG, 32'h80010000);
        axi_read_lite(KEYSTONE_COPRO_CSR_BASE_ADDR + ADDR_PROG_ADDR_LOW_REG, rdata_tc3);
        if (rdata_tc3 === 32'h80010000) begin
            $display("[%0t ns] TC3: PROG_ADDR_LOW_REG readback PASS (Got: 0x%h)", $time, rdata_tc3);
        end else begin
            $display("[%0t ns] TC3: PROG_ADDR_LOW_REG readback FAIL (Exp: 0x80010000, Got: 0x%h)", $time, rdata_tc3);
            tc3_passed = 1'b0;
        end

        // 3. Write to INT_ENABLE_REG and read back
        $display("[%0t ns] TC3: Writing 0xFFFF to INT_ENABLE_REG (0x%h)...", $time, KEYSTONE_COPRO_CSR_BASE_ADDR + ADDR_INT_ENABLE_REG);
        axi_write_lite(KEYSTONE_COPRO_CSR_BASE_ADDR + ADDR_INT_ENABLE_REG, 32'h0000FFFF);
        axi_read_lite(KEYSTONE_COPRO_CSR_BASE_ADDR + ADDR_INT_ENABLE_REG, rdata_tc3);
        // The CCU masks int_enable_reg to 18 bits (0x3FFFF)
        if (rdata_tc3 === 32'h0000FFFF) begin // Check against what was written, CCU internal masking is its behavior
            $display("[%0t ns] TC3: INT_ENABLE_REG readback PASS (Got: 0x%h)", $time, rdata_tc3);
        end else begin
            $display("[%0t ns] TC3: INT_ENABLE_REG readback FAIL (Exp: 0xFFFF, Got: 0x%h)", $time, rdata_tc3);
            tc3_passed = 1'b0;
        end
        
        if (tc3_passed) begin
            $display("[%0t ns] TC3: All Keystone CSR Access checks PASSED.", $time);
        end else begin
            $display("[%0t ns] TC3: One or more Keystone CSR Access checks FAILED.", $time);
        end
        $display("[%0t ns] --- Test Case TC3 Finished ---", $time);
        
        // Extend simulation time if TC3 is the last test for now
        // The main $finish in TC1's block will handle overall termination.
        // If TC3 runs longer than TC1's original finish time, TC1's $finish needs to be moved or this block also calls $finish.
    end

    // Test Case TC3: Keystone Coprocessor CSR Access
    initial begin
        logic [31:0] rdata_tc3;
        logic tc3_passed_overall; // To track overall TC3 status

        // Wait for TC1 to largely complete its autonomous sequence.
        // This simple delay assumes TC1's CVA6 stub operations are done or quiescent.
        #(10100 * CLK_PERIOD); 
        
        $display("[%0t ns] --- Starting Test Case TC3: Keystone Coprocessor CSR Access ---", $time);
        tc3_passed_overall = 1'b1; // Assume pass until a check fails

        // 1. Write to VM_SELECT_REG (select VM 3) and read back
        $display("[%0t ns] TC3: Step 1 - Write to VM_SELECT_REG (0x%h) with data 0x3", $time, KEYSTONE_COPRO_CSR_BASE_ADDR + ADDR_VM_SELECT_REG);
        axi_write_lite(KEYSTONE_COPRO_CSR_BASE_ADDR + ADDR_VM_SELECT_REG, 32'h00000003);
        
        $display("[%0t ns] TC3: Step 1 - Reading from VM_SELECT_REG (0x%h)", $time, KEYSTONE_COPRO_CSR_BASE_ADDR + ADDR_VM_SELECT_REG);
        axi_read_lite(KEYSTONE_COPRO_CSR_BASE_ADDR + ADDR_VM_SELECT_REG, rdata_tc3);
        if (rdata_tc3 === 32'h00000003) begin
            $display("[%0t ns] TC3: VM_SELECT_REG readback PASS. Expected: 0x3, Got: 0x%h", $time, rdata_tc3);
        end else begin
            $display("[%0t ns] TC3: VM_SELECT_REG readback FAIL. Expected: 0x3, Got: 0x%h", $time, rdata_tc3);
            tc3_passed_overall = 1'b0;
        end

        // 2. Write to PROG_ADDR_LOW_REG and read back
        $display("[%0t ns] TC3: Step 2 - Write to PROG_ADDR_LOW_REG (0x%h) with data 0x80010000", $time, KEYSTONE_COPRO_CSR_BASE_ADDR + ADDR_PROG_ADDR_LOW_REG);
        axi_write_lite(KEYSTONE_COPRO_CSR_BASE_ADDR + ADDR_PROG_ADDR_LOW_REG, 32'h80010000);

        $display("[%0t ns] TC3: Step 2 - Reading from PROG_ADDR_LOW_REG (0x%h)", $time, KEYSTONE_COPRO_CSR_BASE_ADDR + ADDR_PROG_ADDR_LOW_REG);
        axi_read_lite(KEYSTONE_COPRO_CSR_BASE_ADDR + ADDR_PROG_ADDR_LOW_REG, rdata_tc3);
        if (rdata_tc3 === 32'h80010000) begin
            $display("[%0t ns] TC3: PROG_ADDR_LOW_REG readback PASS. Expected: 0x80010000, Got: 0x%h", $time, rdata_tc3);
        end else begin
            $display("[%0t ns] TC3: PROG_ADDR_LOW_REG readback FAIL. Expected: 0x80010000, Got: 0x%h", $time, rdata_tc3);
            tc3_passed_overall = 1'b0;
        end

        // 3. Write to INT_ENABLE_REG and read back
        $display("[%0t ns] TC3: Step 3 - Write to INT_ENABLE_REG (0x%h) with data 0xFFFF", $time, KEYSTONE_COPRO_CSR_BASE_ADDR + ADDR_INT_ENABLE_REG);
        axi_write_lite(KEYSTONE_COPRO_CSR_BASE_ADDR + ADDR_INT_ENABLE_REG, 32'h0000FFFF);
        
        $display("[%0t ns] TC3: Step 3 - Reading from INT_ENABLE_REG (0x%h)", $time, KEYSTONE_COPRO_CSR_BASE_ADDR + ADDR_INT_ENABLE_REG);
        axi_read_lite(KEYSTONE_COPRO_CSR_BASE_ADDR + ADDR_INT_ENABLE_REG, rdata_tc3);
        // Note: CCU internally masks INT_ENABLE_REG to 18 bits (0x3FFFF).
        // The test writes 0xFFFF (16 bits set), which is within the 18-bit mask.
        if (rdata_tc3 === 32'h0000FFFF) begin
            $display("[%0t ns] TC3: INT_ENABLE_REG readback PASS. Expected: 0xFFFF, Got: 0x%h", $time, rdata_tc3);
        end else begin
            $display("[%0t ns] TC3: INT_ENABLE_REG readback FAIL. Expected: 0xFFFF, Got: 0x%h", $time, rdata_tc3);
            tc3_passed_overall = 1'b0;
        end
        
        if (tc3_passed_overall) begin
            $display("[%0t ns] TC3: All Keystone CSR Access checks PASSED.", $time);
        end else begin
            $display("[%0t ns] TC3: ### One or more Keystone CSR Access checks FAILED. ###", $time);
        end
        $display("[%0t ns] --- Test Case TC3 Finished ---", $time);
        
        // Since TC1's $finish is now too early, we add a $finish here after TC3.
        // This assumes TC3 is the last test for now.
        // If more tests follow, this $finish should be moved to the end of all tests.
        #(100 * CLK_PERIOD); // Add a small delay before finishing
        $display("[%0t ns] All specified test cases complete. Finishing simulation.", $time);
        $finish;
    end

    // UART TX Monitor
    // Parameters for UART Monitor
    localparam BAUD_RATE = 115200;
    // Calculate bit period in terms of clock cycles.
    // Use real for intermediate calculation for better precision before rounding.
    localparam real REAL_BIT_PERIOD_NS = (1.0 / BAUD_RATE) * 1e9; 
    localparam integer CLKS_PER_BIT = $rtoi(REAL_BIT_PERIOD_NS / CLK_PERIOD);
    localparam integer CLKS_PER_HALF_BIT = $rtoi(REAL_BIT_PERIOD_NS / (CLK_PERIOD * 2.0));

    typedef enum logic [1:0] {
        UART_MON_IDLE,
        UART_MON_START_CONFIRM,
        UART_MON_RX_DATA_BITS,
        UART_MON_RX_STOP_BIT
    } uart_mon_state_e;

    uart_mon_state_e uart_rx_state_r;
    reg [2:0] uart_bit_count_r; // To count 8 data bits
    reg [$clog2(CLKS_PER_BIT):0] uart_clk_count_r; // To count clocks within a bit period
    reg [7:0] uart_received_char_r;

    always @(posedge clk or negedge resetn) begin
        if (!resetn) begin
            uart_rx_state_r <= UART_MON_IDLE;
            uart_bit_count_r <= 0;
            uart_clk_count_r <= 0;
            uart_received_char_r <= 8'h00;
        end else begin
            case (uart_rx_state_r)
                UART_MON_IDLE: begin
                    if (uart_tx_tb == 1'b0) begin // Start bit detected (falling edge)
                        uart_rx_state_r <= UART_MON_START_CONFIRM;
                        uart_clk_count_r <= 0;
                        uart_bit_count_r <= 0;
                        uart_received_char_r <= 8'h00;
                        //$display("[%0t ns] UART_MON: Detected potential start bit.", $time);
                    end
                end

                UART_MON_START_CONFIRM: begin
                    if (uart_clk_count_r < CLKS_PER_HALF_BIT -1) begin // Wait for mid-point of start bit
                        uart_clk_count_r <= uart_clk_count_r + 1;
                    end else begin
                        if (uart_tx_tb == 1'b0) begin // Confirm it's still low
                            //$display("[%0t ns] UART_MON: Start bit confirmed.", $time);
                            uart_rx_state_r  <= UART_MON_RX_DATA_BITS;
                            uart_clk_count_r <= 0; // Reset for next bit period counting
                        end else begin
                            //$display("[%0t ns] UART_MON: False start bit detected.", $time);
                            uart_rx_state_r <= UART_MON_IDLE; // False start
                        end
                    end
                end

                UART_MON_RX_DATA_BITS: begin
                    if (uart_clk_count_r < CLKS_PER_BIT -1) begin // Wait for full bit period
                        uart_clk_count_r <= uart_clk_count_r + 1;
                    end else begin
                        uart_clk_count_r <= 0; // Reset for next bit period
                        uart_received_char_r <= {uart_tx_tb, uart_received_char_r[7:1]}; // LSB first
                        uart_bit_count_r <= uart_bit_count_r + 1;
                        //$display("[%0t ns] UART_MON: Sampled bit %d = %b, char_in_progress = %h.", $time, uart_bit_count_r-1, uart_tx_tb, {uart_tx_tb, uart_received_char_r[7:1]});
                        if (uart_bit_count_r == 8) begin
                            uart_rx_state_r <= UART_MON_RX_STOP_BIT;
                        end
                        // else stay in UART_MON_RX_DATA_BITS for next bit
                    end
                end

                UART_MON_RX_STOP_BIT: begin
                    if (uart_clk_count_r < CLKS_PER_BIT -1) begin // Wait for full bit period
                        uart_clk_count_r <= uart_clk_count_r + 1;
                    end else begin
                        if (uart_tx_tb == 1'b1) begin // Stop bit should be high
                            $display("[%0t ns] UART_MON: Received Char: '%c' (0x%h)", $time, uart_received_char_r, uart_received_char_r);
                        end else begin
                            $display("[%0t ns] UART_MON: Framing Error! Stop bit low. Received: 0x%h", $time, uart_received_char_r);
                        end
                        uart_rx_state_r <= UART_MON_IDLE;
                    end
                end
                default: uart_rx_state_r <= UART_MON_IDLE;
            endcase
        end
    end

endmodule
