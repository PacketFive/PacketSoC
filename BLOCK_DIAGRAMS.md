# KESTREL-V SoC Block Diagrams

This document provides textual descriptions for the high-level and low-level block diagrams of the KESTREL-V System-on-Chip (SoC).

## 1. High-Level Block Diagram

**Objective:** To show the KESTREL-V SoC as a single component and its primary external interfaces.

**Components:**

*   **KESTREL-V SoC:** A single block representing the entire chip.
    *   **Inputs:**
        *   `clk`: Main system clock.
        *   `resetn`: Active-low reset.
        *   `uart_rx_i`: UART receive line.
        *   (Potentially JTAG interface pins: `jtag_tck`, `jtag_tms`, `jtag_tdi`, `jtag_tdo`, `jtag_trst_n` - if external JTAG is a primary interface).
        *   (Potentially DDR interface signals - if DDR is off-chip and directly connected).
    *   **Outputs:**
        *   `uart_tx_o`: UART transmit line.
        *   (Potentially status LEDs or other general-purpose I/O).
    *   **Bidirectional:**
        *   (External Memory Interface if applicable, e.g., to DDR RAM).

**Interactions:**

*   The KESTREL-V SoC interfaces with the external world primarily via UART for console/debug and potentially JTAG for debugging.
*   It requires a clock and reset signal.
*   It may interface with external memory (e.g., DDR RAM).

## 2. Mid-Level SoC Block Diagram

**Objective:** To show the major internal components of the KESTREL-V SoC and how they are interconnected, primarily focusing on the main CPU, the Keystone Coprocessor, memory, and key peripherals.

**Components:**

1.  **CVA6 CPU Core (RISC-V, 64-bit):**
    *   Instruction Cache (I-Cache)
    *   Data Cache (D-Cache)
    *   MMU
    *   AXI Master Port (M0_AXI) - for instructions and data
    *   Interrupt Input (from PLIC)
    *   Debug Interface (JTAG - internal connection)

2.  **Keystone Coprocessor:**
    *   AXI-Lite Slave Port (S1_AXI) - for CSR access from CVA6
    *   AXI Master Port (M1_AXI) - for DMA to/from Main Memory
    *   Interrupt Output (`copro_irq_w` to PLIC)
    *   Internal Components:
        *   Coprocessor Control Unit (CCU)
        *   Multiple eBPF VM Slots (e.g., 8 slots)
            *   Each slot contains a PicoRV32 Nano-controller
            *   Each slot has dedicated Program Memory and Stack Memory

3.  **AXI Interconnect:**
    *   Connects AXI Masters to AXI Slaves.
    *   **Master Ports:**
        *   `M0_AXI` (from CVA6 CPU)
        *   `M1_AXI` (from Keystone Coprocessor DMA)
    *   **Slave Ports:**
        *   `S0_AXI` (to Main Memory Controller)
        *   `S1_AXI` (to Keystone Coprocessor CSRs)
        *   `S2_AXI` (to Boot ROM)
        *   `S3_AXI` (to Peripherals)

4.  **Main Memory Controller (DDR Controller Stub):**
    *   AXI Slave Port (S0_AXI)
    *   Connects to external DDR RAM (conceptual, actual interface depends on FPGA IP)

5.  **Boot ROM Stub:**
    *   AXI Slave Port (S2_AXI)
    *   Stores initial boot code for CVA6.

6.  **Peripherals Block (AXI-Lite):**
    *   AXI Slave Port (S3_AXI)
    *   Contains:
        *   UART Controller
        *   PLIC (Platform-Level Interrupt Controller) - aggregates interrupts (e.g., from Keystone Coprocessor, UART, Timer) and forwards to CVA6.
        *   CLINT (Core Local Interruptor) - for timer and software interrupts for CVA6.
        *   (Other potential peripherals like GPIO, SPI, I2C - currently stubs)

7.  **Clock Generation and Distribution Unit:**
    *   Takes `clk_i` (main clock input).
    *   Generates/distributes clocks to CPU, Interconnect, Coprocessor, Peripherals, Memory Controller.

8.  **Reset Distribution Unit:**
    *   Takes `resetn_i` (main reset input).
    *   Distributes synchronized reset signals to all components.

**Interconnections (via AXI Interconnect primarily):**

*   **CVA6 (M0_AXI)** can access:
    *   Main Memory (via S0_AXI)
    *   Keystone Coprocessor CSRs (via S1_AXI)
    *   Boot ROM (via S2_AXI)
    *   Peripherals (via S3_AXI)
*   **Keystone Coprocessor (M1_AXI)** can access:
    *   Main Memory (via S0_AXI) - for DMA
*   **Interrupts:**
    *   Keystone Coprocessor, UART, Timer -> PLIC
    *   PLIC -> CVA6 CPU
    *   CLINT -> CVA6 CPU

## 3. Low-Level Block Diagram: Keystone Coprocessor Detail

**Objective:** To provide a more detailed view of the internal structure of the Keystone Coprocessor.

**Components:**

1.  **Coprocessor Control Unit (CCU):**
    *   **AXI-Lite Slave Interface (from AXI Interconnect S1_AXI):**
        *   Decodes CSR addresses.
        *   Handles read/write operations to CSRs.
    *   **CSRs (Control/Status Registers):**
        *   `COPRO_CMD_REG`, `VM_SELECT_REG`, `PROG_ADDR_LOW/HIGH_REG`, `DATA_ADDR_LOW/HIGH_REG`, `DATA_LEN_REG`, `INT_STATUS_REG`, `INT_ENABLE_REG`, Mailbox registers, etc.
    *   **DMA Controller (AXI Master - M1_AXI):**
        *   Initiates AXI read bursts from Main Memory (for program/data load).
        *   Interfaces with eBPF VM Slots to write data into their memories.
        *   Generates DMA done/error interrupts.
    *   **VM Lifecycle Control Logic:**
        *   Manages `start_vm`, `stop_vm`, `reset_vm` signals to individual eBPF VM Slots based on commands from CVA6.
    *   **Mailbox Multiplexing Logic:**
        *   Routes mailbox data from CVA6 (via CSRs) to the selected eBPF VM Slot's IN mailboxes.
        *   Routes mailbox data from the selected eBPF VM Slot's OUT mailboxes to CVA6 (via CSRs).
    *   **Interrupt Aggregation Logic:**
        *   Collects interrupt signals (VM done/error, DMA done/error) and presents them in `INT_STATUS_REG`.
        *   Generates the main `copro_irq_w` signal if enabled in `INT_ENABLE_REG`.

2.  **eBPF VM Slots (e.g., 8 identical slots, Arrayed):**
    *   Each slot is an instance of `eBPF_VM_Slot.v`.
    *   **Inputs from CCU:**
        *   `select_vm_i`: Selects this specific VM slot for CSR-based interaction (mailbox, status read).
        *   `start_vm_i`: Starts the PicoRV32 in this slot.
        *   `stop_vm_i`: Stops/gates the PicoRV32.
        *   `reset_vm_i`: Resets the PicoRV32 and its local memories/state.
        *   `write_prog_mem_en_i`, `write_prog_mem_addr_i`, `write_prog_mem_data_i`: For DMA writing to program memory.
        *   `write_stack_mem_en_i`, `write_stack_mem_addr_i`, `write_stack_mem_data_i`: (If DMA to stack is supported, currently not shown in `CoprocessorControlUnit.v`).
        *   `mailbox_in_data_i`, `mailbox_in_idx_i`, `mailbox_in_wen_i`: Data written by CVA6 to this VM's IN mailbox.
    *   **Outputs to CCU:**
        *   `done_o`: VM has completed execution.
        *   `error_o`: VM has encountered an error.
        *   `error_code_o`: Specific error code from VM.
        *   `mailbox_out_data_o`, `mailbox_out_idx_o`, `mailbox_out_wen_o`: Data written by this VM to its OUT mailbox.
        *   `status_reg_out_o`: Value of the PicoRV32's status register.
    *   **Internal Components of an eBPF VM Slot:**
        *   **PicoRV32 Nano-controller (RISC-V RV32IMC):**
            *   Fetches instructions from its local `nano_ctrl_instr_rom`.
            *   Accesses its local `nano_ctrl_data_ram` for stack/data.
            *   Memory-mapped interface to access:
                *   eBPF Program Memory
                *   eBPF Stack Memory
                *   Mailbox Registers (IN/OUT)
                *   Its own Status Register (`ADDR_NANO_CTRL_STATUS_REG`)
        *   **eBPF Program Memory (RAM):** Stores eBPF bytecode, written by CCU DMA.
        *   **eBPF Stack Memory (RAM):** Used by eBPF programs for their stack.
        *   **Nano-controller Instruction ROM:** Stores the uBPF interpreter firmware.
        *   **Nano-controller Data RAM:** Stores the PicoRV32's stack and uBPF interpreter's data.
        *   **Mailbox Registers (IN/OUT):** Hardware registers for communication.

**Interconnections within Keystone Coprocessor:**

*   CCU CSRs are accessible via AXI-Lite from the main SoC interconnect.
*   CCU DMA talks to the main SoC interconnect (AXI Master) and to the program memories of the eBPF VM Slots.
*   CCU control signals (`start_vm`, `reset_vm`, etc.) are fanned out to the respective eBPF VM Slots.
*   Mailbox data and control signals are routed between CCU and the currently selected eBPF VM Slot.
*   Interrupts (`done`, `error`) from all eBPF VM Slots are aggregated by the CCU.

```
This should provide a good textual basis for someone to create the actual diagrams.
This new file describes the KESTREL-V SoC block diagrams at high, mid, and low levels.
The high-level diagram shows the SoC's external interfaces.
The mid-level diagram details major internal components like the CVA6 CPU, Keystone Coprocessor, AXI interconnect, memory, and peripherals.
The low-level diagram focuses on the Keystone Coprocessor's internal structure, including the Coprocessor Control Unit (CCU) and the eBPF VM Slots with their PicoRV32 nano-controllers.
Interconnections, primarily via AXI, are also described.
The file `BLOCK_DIAGRAMS.md` has been created with the specified content.
This completes the assigned subtask. I will now submit the report.
