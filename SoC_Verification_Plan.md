# SoC Verification Plan

## 0. Document Purpose

This document outlines the verification strategy, testbench architecture, key verification areas, and specific test cases for the KESTREL-V SoC design featuring the CVA6 CPU core and the Keystone Coprocessor.

## 1. Testbench Architecture Overview

The SoC testbench will be constructed using SystemVerilog and will instantiate the `SoC_Top` module as the Device Under Test (DUT).

**Components:**

1.  **`SoC_Top` (DUT):** The top-level System-on-Chip module.
2.  **Clock and Reset Generators:**
    *   A module/interface to generate the main system clock (`clk`).
    *   A module/interface to generate the active-low reset signal (`resetn`) and manage its assertion/de-assertion sequence.
3.  **AXI Bus Functional Models (BFMs) / Traffic Generators:**
    *   **CPU AXI Master BFM (for M0_AXI on Interconnect):** Since `CVA6_Core_Stub.v` already includes a basic FSM to generate AXI traffic, this stub itself acts as a simplified BFM for the CPU's AXI master port. For more complex scenarios, a dedicated SystemVerilog BFM could replace or augment the stub.
    *   **Keystone DMA AXI Master BFM (for M1_AXI on Interconnect):** The `KeystoneCoprocessor`'s DMA unit will generate traffic on this port. The testbench might need to monitor this interface or provide responses if the main memory model is not fully reactive.
    *   **AXI Slave BFMs/Memory Models (for S0, S1, S2 on Interconnect):**
        *   `Main_Memory_Ctrl_Stub.v`: Acts as a basic AXI4 Full slave memory model for DRAM. It should respond to read/write requests. For more rigorous testing, this could be replaced with a more detailed memory model that allows pre-loading and checking of specific memory contents.
        *   `KeystoneCoprocessor.v` (s_axi_lite slave interface): This is part of the DUT, and its AXI-Lite slave interface will be exercised by the CPU AXI Master BFM.
        *   `Peripherals_Stub.v`: Acts as a basic AXI4-Lite slave, providing minimal register functionality (e.g., for UART).
4.  **Boot ROM Model (`Boot_ROM_Stub.v`):**
    *   Provides initial instructions to the CVA6 CPU stub. The current stub has a simplified direct interface.
5.  **Peripheral Monitors/Interactors:**
    *   **UART Monitor:** A SystemVerilog module or interface to capture data transmitted on `uart_tx_o` and potentially drive `uart_rx_i`. This monitor will log UART output for checking.
    *   **Interrupt Monitor:** A task or process within the testbench to monitor the `interrupt_out` signal from the Keystone Coprocessor to the CVA6 CPU.

**Test Sequence Coordination:**

*   Test sequences will primarily be coordinated within a SystemVerilog `program` block or within `initial` blocks in the top-level testbench module (`SoC_tb.sv` - not yet created).
*   The CVA6 CPU stub's internal FSM will drive initial AXI transactions, simulating a basic program flow.
*   Specific test case logic will use tasks to:
    *   Control reset.
    *   Wait for specific simulation times or events.
    *   Pre-load memory (e.g., into `Main_Memory_Ctrl_Stub.v` or `Boot_ROM_Stub.v` via testbench access if direct access paths are added to stubs).
    *   Initiate CPU actions by manipulating signals connected to the `CVA6_Core_Stub.v` (if extended beyond its current FSM) or by relying on its autonomous behavior.
    *   Check expected results (e.g., UART output, register values read back via AXI, interrupt assertions).

## 2. Key Verification Areas

The verification effort will focus on the following key features and modules:

1.  **CVA6 CPU Core (Stub Functionality):**
    *   Correct boot sequence initiation (fetching from Boot ROM stub address).
    *   Basic AXI master transaction generation (read/write) to different memory regions as per its internal FSM.
    *   Response to interrupts from the Keystone Coprocessor (conceptual, as the stub doesn't have a full interrupt controller).
2.  **AXI Interconnect (`AXI_Interconnect.v`):**
    *   **Address Decoding:** Verify that AXI transactions from both masters (CPU M0, Keystone DMA M1) are correctly routed to the intended slave ports (S0: Main Memory, S1: Keystone CSRs, S2: Peripherals) based on the `SoC_Memory_Map.txt`.
    *   **Basic Routing:** Ensure data and response paths are correctly connected between masters and slaves.
    *   **Error Handling (Conceptual):** Verify that accesses to unmapped address regions result in an AXI DECERR response (this will depend on the interconnect stub's implementation).
    *   *(Arbitration is not explicitly testable with current stubs but is a key area for a full interconnect model).*
3.  **Keystone Coprocessor (`KeystoneCoprocessor.v` -> `CoprocessorControlUnit.v`):**
    *   **AXI-Lite Slave Interface:**
        *   Read/write access to all defined CSRs (`COPRO_CMD_REG`, `VM_SELECT_REG`, `PROG_ADDR_LOW_REG`, etc.) via the CPU.
        *   Correct behavior of SC (Self-Clearing) and RC (Read-Clear) registers.
    *   **DMA Operation (AXI Master Interface):**
        *   Correct initiation of DMA read operations upon `LOAD_PROG` or `LOAD_DATA_IN` commands.
        *   Generation of correct AXI master read transactions (ARADDR, ARLEN, ARSIZE, ARBURST) to Main Memory.
        *   Correct handling of AXI read responses (RDATA, RRESP, RLAST) from Main Memory.
        *   Writing of received data into the target eBPF VM's program memory (for `LOAD_PROG`).
        *   Setting of `DMA_DONE_IRQ` or `DMA_ERROR_IRQ` in `INT_STATUS_REG`.
    *   **VM Lifecycle Control (via "Y" ISA - simulated by CPU stub AXI writes):**
        *   Correct response to `START_VM`, `STOP_VM`, `RESET_VM` commands issued by the CPU to `COPRO_CMD_REG`.
        *   Updates to `active_vm_mask_r` and `copro_busy_status_r` based on VM state changes.
    *   **Mailbox Communication (CPU <-> VM):**
        *   CPU writing to IN mailboxes (via `ADDR_MAILBOX_DATA_IN_0_REG` in CCU).
        *   CPU reading from OUT mailboxes (via `ADDR_MAILBOX_DATA_OUT_0_REG` in CCU).
        *   Correct routing of data from/to the selected VM's mailbox interface connected to `eBPF_VM_Slot`.
    *   **Interrupt Generation:**
        *   Correct assertion of `interrupt_out` based on enabled bits in `INT_STATUS_REG` (VM done/error, DMA done/error).
4.  **eBPF VM Slot (`eBPF_VM_Slot.v` - including PicoRV32 nano-controller):**
    *   **PicoRV32 Boot-up & Execution (Conceptual):**
        *   Verify PicoRV32 reset is correctly managed by `reset_vm`, `start_vm`, `stop_vm`.
        *   Assume PicoRV32 starts fetching from its local instruction ROM (`NANO_CTRL_ROM_BASE`) upon de-assertion of reset.
    *   **PicoRV32 Memory Access:**
        *   Correct access to its local instruction ROM and data RAM.
        *   Correct read access to the eBPF Program Memory (`prog_mem`).
        *   Correct read/write access to the eBPF Stack Memory (`stack_mem`).
    *   **Status Reporting:**
        *   PicoRV32 ability to write to `ADDR_NANO_CTRL_STATUS_REG` to set `done_reg_r` and `error_reg_r`, which drive the `done` and `error` outputs of the `eBPF_VM_Slot`.
    *   **Mailbox Interaction:**
        *   PicoRV32 ability to read from its IN mailbox (data originating from CPU via CCU) by accessing `EBPF_MAILBOX_IN_BASE_ADDR`.
        *   PicoRV32 ability to write to its OUT mailbox (data destined for CPU via CCU) by accessing `EBPF_MAILBOX_OUT_BASE_ADDR`.
        *   Correct generation of `vm_mailbox_out_wen_o`, `vm_mailbox_out_idx_o`, `vm_mailbox_out_wdata_o` by the slot when PicoRV32 writes.
        *   Correct driving of `vm_mailbox_in_idx_o` by the slot when PicoRV32 reads.
5.  **ISA Extension "Y" (End-to-End Tests):**
    *   These tests will involve the CVA6 CPU stub initiating "Y" instructions (simulated via direct AXI writes to Keystone CSRs that mimic the "Y" instruction effects).
    *   Verification of the entire sequence: CPU issues command -> Keystone CCU processes -> DMA (if any) -> VM Slot interaction -> Status update / Interrupt.

## 3. Detailed Test Cases

The following test cases will be developed. (Note: "CPU" refers to `CVA6_Core_Stub.v` actions, which may be direct AXI transactions for these tests).

**TC1: KESTREL-V SoC Boot & CVA6 Stub Basic Execution**

*   **Objective:** Verify that the KESTREL-V SoC comes out of reset, the CVA6 CPU stub starts fetching from the Boot ROM, and can perform a basic peripheral access (e.g., write to a conceptual UART TX register in `Peripherals_Stub.v`).
*   **Prerequisites:**
    *   `Boot_ROM_Stub.v` contains valid initial instructions (e.g., a sequence to write a character to the UART TX register address via AXI).
*   **Stimulus Sequence:**
    1.  Assert `resetn` low for a few clock cycles.
    2.  De-assert `resetn` high.
    3.  CVA6 CPU stub autonomously:
        a.  Fetches instructions from Boot ROM (simulated via `boot_addr_o`/`boot_data_i`).
        b.  (Simulated) Executes instructions to write a known value (e.g., ASCII 'H') to the UART TX register address (`0x0200_0000` + `UART_TX_REG_OFFSET`) via an AXI write transaction.
*   **Expected Results/Checks:**
    *   `resetn` signal correctly propagated to all modules.
    *   CVA6 CPU stub's `boot_addr_o` shows sequential addresses starting from its boot address.
    *   An AXI write transaction from CVA6 (M0 on interconnect) targeting the `Peripherals_Stub` (S2) at the UART TX register address.
        *   `M0_AXI_AWADDR` should be `0x0200_0000` (or `0x0200_0000` + `UART_TX_REG_OFFSET` if base is `0x0200_0000`).
        *   `M0_AXI_WDATA` should contain the known value (e.g., ASCII 'H').
    *   `Peripherals_Stub.v` should show the write to its `uart_tx_reg_r`.
    *   `uart_tx_o` (top-level) should reflect the character written (or its LSB if `uart_tx_o` is single bit).

**TC2: CVA6 Stub - Main Memory Read/Write**

*   **Objective:** Verify CVA6 CPU stub can issue AXI read and write requests to the Main Memory region, and data integrity is maintained (using `Main_Memory_Ctrl_Stub.v`).
*   **Prerequisites:** None (memory starts uninitialized or with known default).
*   **Stimulus Sequence:**
    1.  CVA6 CPU stub (or testbench directly controlling its AXI master signals for this test) initiates an AXI write to an address in Main Memory (e.g., `0x8000_1000`) with a known data pattern (e.g., `0xDEADBEEF`).
    2.  After write completion, CVA6 CPU stub initiates an AXI read from the same address (`0x8000_1000`).
*   **Expected Results/Checks:**
    *   AXI write transaction from M0 to S0 (Main Memory) with correct address and data.
        *   `M0_AXI_AWADDR == 0x8000_1000`, `M0_AXI_WDATA == 0xDEADBEEF`.
        *   `S0_AXI_AWVALID`, `S0_AXI_WVALID` asserted by interconnect.
        *   `S0_AXI_AWREADY`, `S0_AXI_WREADY` asserted by memory controller stub.
        *   `M0_AXI_BVALID` asserted with `M0_AXI_BRESP == 2'b00` (OKAY).
    *   AXI read transaction from M0 to S0 with correct address.
        *   `M0_AXI_ARADDR == 0x8000_1000`.
        *   `S0_AXI_ARVALID` asserted.
        *   `S0_AXI_ARREADY` asserted.
        *   `M0_AXI_RVALID` asserted with `M0_AXI_RRESP == 2'b00` (OKAY).
        *   `M0_AXI_RDATA` should be `0xDEADBEEF`.

**TC3: Keystone Coprocessor Register Access (CPU writes/reads CSRs via AXI-Lite)**

*   **Objective:** Verify CPU can write to and read from Keystone Coprocessor's Control/Status Registers (CSRs) via its AXI-Lite slave interface.
*   **Prerequisites:** None.
*   **Stimulus Sequence:**
    1.  CPU issues AXI write to `VM_SELECT_REG` (`0x1000_0004`) with data `0x00000003` (select VM 3).
    2.  CPU issues AXI read from `VM_SELECT_REG`.
    3.  CPU issues AXI write to `PROG_ADDR_LOW_REG` (`0x1000_000C`) with data `0x8001_0000`.
    4.  CPU issues AXI read from `PROG_ADDR_LOW_REG`.
    5.  CPU issues AXI write to `INT_ENABLE_REG` (`0x1000_002C`) with data `0x0000_FFFF`.
    6.  CPU issues AXI read from `INT_ENABLE_REG`.
*   **Expected Results/Checks:**
    *   For each write:
        *   Correct AXI-Lite write transaction from M0 to S1 (Keystone CSRs).
        *   `M0_AXI_AWADDR` matches the target register address (e.g., `0x1000_0004`).
        *   `M0_AXI_WDATA` matches the written data.
        *   `S1_AXI_AWVALID`, `S1_AXI_WVALID` asserted.
        *   `S1_AXI_AWREADY`, `S1_AXI_WREADY` asserted by Keystone.
        *   `M0_AXI_BVALID` asserted with `BRESP == 2'b00`.
        *   Internal registers in `CoprocessorControlUnit.v` (e.g., `vm_select_id_r`, `prog_addr_low_reg_r`, `int_enable_reg_r`) are updated.
    *   For each read:
        *   Correct AXI-Lite read transaction from M0 to S1.
        *   `M0_AXI_ARADDR` matches the target register address.
        *   `S1_AXI_ARVALID` asserted.
        *   `S1_AXI_ARREADY` asserted by Keystone.
        *   `M0_AXI_RVALID` asserted with `RRESP == 2'b00`.
        *   `M0_AXI_RDATA` matches the value previously written or the default/status value of the register.

**TC4: Keystone Coprocessor Program Load (CPU issues `LOAD_PROG` command, DMA fetches from main memory to VM's program memory)**

*   **Objective:** Verify the DMA program load sequence: CPU configures DMA via CSRs, issues `LOAD_PROG` command, CCU's DMA reads from Main Memory and writes to the selected VM's program memory.
*   **Prerequisites:**
    *   `Main_Memory_Ctrl_Stub.v` should allow pre-loading or have a known data pattern at a source address (e.g., `0x8002_0000`). For this test, the stub's dummy read data can be observed.
    *   Load (e.g., 16 bytes = 4 words) of identifiable data into Main Memory at `0x8002_0000`.
*   **Stimulus Sequence:**
    1.  CPU writes to `VM_SELECT_REG` to select VM 0 (`data = 0x0`).
    2.  CPU writes to `PROG_ADDR_LOW_REG` with source address in Main Memory (e.g., `0x8002_0000`).
    3.  CPU writes to `DATA_LEN_REG` with the length of the program (e.g., `16` bytes).
    4.  CPU writes to `COPRO_CMD_REG` with `LOAD_PROG` bit set (`data = 0x00000008`).
*   **Expected Results/Checks:**
    *   AXI writes from CPU to CCU CSRs are successful.
    *   `CoprocessorControlUnit.v` (`ccu_inst`):
        *   DMA state machine transitions from `DMA_IDLE` through `DMA_CALC_BURST`, `DMA_INIT_READ`, `DMA_READ_BURST`.
        *   `dma_op_is_prog_load_r` should be true.
        *   `dma_target_vm_id_r` should be 0.
        *   `dma_addr_r` should be `0x8002_0000`.
        *   `dma_len_bytes_r` should be `16`.
    *   AXI Master Read Transactions from Keystone (M1 on interconnect) to Main Memory (S0):
        *   `M1_AXI_ARADDR` should start at `0x8002_0000`.
        *   `M1_AXI_ARLEN` should correspond to 16 bytes (e.g., 3 for 4 transfers of 32-bit words if `ARSIZE` is 4 bytes).
        *   Observe `M1_AXI_ARVALID`, `S0_AXI_ARREADY`, `S0_AXI_RVALID`, `M1_AXI_RREADY`, `S0_AXI_RDATA`, `S0_AXI_RLAST`.
    *   In `CoprocessorControlUnit.v`:
        *   `vm_wr_prog_en_w[0]` should pulse for each word written to VM0's program memory.
        *   `vm_wr_prog_addr_w[0]` should increment (0, 1, 2, 3).
        *   `vm_wr_prog_data_w[0]` should reflect the data read from Main Memory via `M1_AXI_RDATA`.
    *   In `eBPF_VM_Slot.v` (for VM0):
        *   `write_prog_mem_en_i` should pulse.
        *   `write_prog_mem_addr_i` should increment.
        *   `prog_mem` array should contain the data read from Main Memory.
    *   CCU's `INT_STATUS_REG[16]` (DMA_DONE_IRQ) should be set after DMA completion.
    *   `copro_busy_status_r` should be active during DMA and then clear.

**TC5: eBPF VM Start & Mailbox Test (CPU starts VM, PicoRV32 runs dummy program to write to OUT mailbox, CPU reads OUT mailbox)**

*   **Objective:** Verify CPU can start a VM, the (conceptual) PicoRV32 program can write to its OUT mailbox, and CPU can read the value.
*   **Prerequisites:**
    *   A conceptual PicoRV32 program in `nano_ctrl_instr_rom` that:
        1.  Writes a known value (e.g., `0xABCD1234`) to its first OUT mailbox register (e.g., at PicoRV32 address `EBPF_MAILBOX_OUT_BASE_ADDR + 0`).
        2.  Writes `done` flag (bit 0 = 1) to `ADDR_NANO_CTRL_STATUS_REG`.
    *   This test relies on the PicoRV32 stub being able to execute from its ROM and interact with the memory map correctly.
*   **Stimulus Sequence:**
    1.  CPU writes to `VM_SELECT_REG` to select VM 0 (`data = 0x0`).
    2.  CPU writes to `COPRO_CMD_REG` with `START_VM` bit set (`data = 0x00000001`).
    3.  Testbench waits for a duration sufficient for the conceptual PicoRV32 program to execute and write to the mailbox and done register. (Or, wait for `vm_done_w[0]` if connected and reliable).
    4.  CPU issues AXI read from `ADDR_MAILBOX_DATA_OUT_0_REG` (`0x1000_00A0` for VM0).
*   **Expected Results/Checks:**
    *   AXI writes from CPU to CCU CSRs are successful.
    *   `CoprocessorControlUnit.v`: `vm_start_w[0]` pulses high. `active_vm_mask_r[0]` becomes 1.
    *   `eBPF_VM_Slot.v` (for VM0):
        *   `start_vm` input is asserted. `pico_resetn` should de-assert.
        *   (Conceptual) PicoRV32 executes.
        *   `vm_mailbox_out_wen_o` should pulse.
        *   `vm_mailbox_out_idx_o` should be 0.
        *   `vm_mailbox_out_wdata_o` should be `0xABCD1234`.
        *   `done_reg_r` should become 1 (driving `done` output high).
    *   `CoprocessorControlUnit.v`:
        *   `vm_mailbox_out_wen_i[0]`, `vm_mailbox_out_idx_i[0]`, `vm_mailbox_out_wdata_i[0]` should reflect the values from VM0.
        *   `vm_mailboxes_out[0][0]` should store `0xABCD1234`.
        *   `vm_done[0]` input to CCU should go high.
        *   `active_vm_mask_r[0]` should clear after `vm_done[0]` is seen.
    *   CPU AXI read from `0x1000_00A0` should return `0xABCD1234`.

**TC6: Keystone Coprocessor Interrupt Test (VM signals `done`, CCU generates interrupt to CPU)**

*   **Objective:** Verify that when an eBPF VM signals completion, the CCU correctly sets the corresponding interrupt status bit and asserts the global interrupt signal to the CPU.
*   **Prerequisites:**
    *   Conceptual PicoRV32 program in `nano_ctrl_instr_rom` for a selected VM (e.g., VM 1) that writes to `ADDR_NANO_CTRL_STATUS_REG` to set its `done_reg_r` bit.
*   **Stimulus Sequence:**
    1.  CPU writes to `VM_SELECT_REG` to select VM 1 (`data = 0x1`).
    2.  CPU writes to `INT_ENABLE_REG` to enable `VM1_DONE_EN` (e.g., `data = 1 << 1 = 0x00000002`).
    3.  CPU writes to `COPRO_CMD_REG` with `START_VM` bit set (`data = 0x00000001`).
    4.  Testbench waits for the conceptual PicoRV32 program to signal completion.
*   **Expected Results/Checks:**
    *   AXI writes from CPU to CCU CSRs are successful.
    *   `CoprocessorControlUnit.v`:
        *   `vm_start_w[1]` pulses high.
        *   `int_enable_reg_r` should have bit 1 set.
    *   `eBPF_VM_Slot.v` (for VM1):
        *   `start_vm` input is asserted.
        *   (Conceptual) PicoRV32 executes and sets `done_reg_r` to 1.
        *   `done` output of VM1 goes high.
    *   `CoprocessorControlUnit.v`:
        *   `vm_done[1]` input becomes high.
        *   `INT_STATUS_REG[1]` (`VM1_DONE_IRQ`) should become high.
        *   `interrupt_out` (top-level output from Keystone, input to CVA6 stub `copro_irq_i`) should be asserted high.
    *   CPU AXI read from `INT_STATUS_REG` should show bit 1 set.
    *   After CPU reads `INT_STATUS_REG`, bit 1 should be cleared (RC behavior). `interrupt_out` should de-assert (if no other pending enabled interrupts).

## 4. Verification Tools

*   **Simulator:** Standard SystemVerilog simulators such as:
    *   Mentor QuestaSim / ModelSim
    *   Synopsys VCS
    *   Cadence Xcelium
    *   Verilator (for faster simulation, especially with C++ testbenches, though current plan is SV)
*   **Waveform Viewer:** Tool provided with the simulator (e.g., QuestaSim waveform viewer, Verdi/DVE).

## 5. Logging and Debugging Strategy

*   **Waveform Dumping:**
    *   Full waveform dumping (e.g., WLF, FSDB, VCD) will be enabled for all simulations during initial debugging.
    *   For regression runs, critical signals might be selectively dumped to save space and time.
*   **Log Files:**
    *   Testbench will generate log files containing:
        *   Test case name and objective.
        *   Key actions and stimuli applied.
        *   AXI transactions initiated by BFMs/stubs (address, data, type).
        *   AXI responses received.
        *   UART monitor output.
        *   Interrupt assertions/de-assertions.
        *   Status of checks (PASS/FAIL).
        *   Error messages.
    *   SystemVerilog `$display`, `$monitor`, `$sformatf` will be used for logging.
    *   Severity levels (INFO, WARNING, ERROR, FATAL) for log messages.
*   **Assertions:** SystemVerilog Assertions (SVA) can be added for specific AXI protocol checks or internal state machine invariants if modules become more complex than stubs.
*   **Debugging:**
    *   Interactive debugger provided by the simulator.
    *   Waveform analysis.
    *   Review of log files.
    *   Modular design of the testbench and DUT allows for focused debugging.

This test plan provides a foundational strategy. It will be updated and expanded as the KESTREL-V SoC design and verification environment mature.

It includes:
1.  **Testbench Architecture Overview:** Details components like the DUT (`SoC_Top`), Clock/Reset Generators, conceptual AXI BFMs (leveraging existing stubs like `CVA6_Core_Stub` and `Main_Memory_Ctrl_Stub`), and Peripheral Monitors (UART). It also outlines how test sequences will be coordinated using SystemVerilog.
2.  **Key Verification Areas:** Lists modules and features to be tested, including the CVA6 CPU stub, AXI Interconnect (conceptual testing), the Keystone Coprocessor (AXI-Lite slave, DMA, VM lifecycle, mailboxes, interrupts), the eBPF VM Slot with PicoRV32 (PicoRV32 boot, memory access, status reporting, mailbox interaction), and end-to-end ISA Extension "Y" tests.
3.  **Detailed Test Cases:** Expands on six key test cases:
    *   TC1: SoC Boot & CVA6 Stub Basic Execution (UART output).
    *   TC2: CVA6 Stub - Main Memory Read/Write.
    *   TC3: Keystone Coprocessor Register Access (CPU R/W CSRs).
    *   TC4: Keystone Coprocessor Program Load (DMA from Main Memory to VM).
    *   TC5: eBPF VM Start & Mailbox Test (CPU starts VM, conceptual PicoRV32 writes to OUT mailbox, CPU reads).
    *   TC6: Keystone Coprocessor Interrupt Test (VM signals done, CCU generates interrupt).
    Each test case includes its objective, prerequisites, stimulus sequence, and expected results/checks.
4.  **Verification Tools:** Mentions standard Verilog simulators.
5.  **Logging and Debugging Strategy:** Covers waveform dumping, log files, and general debugging approaches.

The document provides a comprehensive plan for verifying the SoC design.
