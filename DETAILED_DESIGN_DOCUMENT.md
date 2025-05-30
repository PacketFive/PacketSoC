# KESTREL-V System-on-Chip - Detailed Design Document

## Table of Contents

1.  [Introduction](#1-introduction)
    1.1. [Purpose](#11-purpose)
    1.2. [Scope](#12-scope)
    1.3. [Project Overview](#13-project-overview)
    1.4. [Document Conventions](#14-document-conventions)
2.  [System Architecture](#2-system-architecture)
    2.1. [High-Level System View](#21-high-level-system-view)
        2.1.1. [Overview](#211-overview)
    2.2. [Mid-Level SoC Block Diagram](#22-mid-level-soc-block-diagram)
        2.2.1. [Overview](#221-overview)
    2.3. [Low-Level Keystone Coprocessor Detail](#23-low-level-keystone-coprocessor-detail)
        2.3.1. [Overview](#231-overview)
3.  [Component Descriptions](#3-component-descriptions)
    3.1. [CVA6 CPU Core](#31-cva6-cpu-core)
        3.1.1. [Overview](#311-overview)
        *(This section describes the CVA6 CPU core used in the KESTREL-V SoC.)*

        The KESTREL-V SoC integrates the CVA6 CPU core as its main processor. CVA6 is an open-source, 64-bit RISC-V (RV64GC) application-class processor designed to be Linux-capable. It features a multi-stage pipeline, Instruction Cache (I-Cache), Data Cache (D-Cache), and a Memory Management Unit (MMU), enabling it to run complex operating systems and applications. The CVA6 core communicates with other SoC components, such as memory and peripherals, via its AXI master port. It also receives interrupts, for example, from the Platform-Level Interrupt Controller (PLIC).
        3.1.2. [ISA Extension "Y"](#312-isa-extension-y)
        *(This section summarizes the custom "Y" ISA extension for Keystone Coprocessor interaction.)*

        To facilitate efficient control and communication between the CVA6 CPU and the Keystone Coprocessor, a custom ISA extension, designated "Y", has been implemented. This extension utilizes the RISC-V `custom-0` opcode (`0001011`).

        Individual "Y" extension instructions are differentiated using the `funct3` and `funct7` fields within the instruction format, similar to standard RISC-V R-type or I-type instructions. The operands `rd`, `rs1`, and `rs2` are used to specify destination registers, source registers (often holding VM index or data), and addresses or data for the coprocessor, respectively.

        The "Y" instruction set includes several categories:
        *   **VM Lifecycle & Control:** Instructions such as `BPF.VM.LOAD_PROG`, `BPF.VM.START`, `BPF.VM.STOP`, and `BPF.VM.RESET` manage the eBPF VM slots within the coprocessor.
        *   **Status & Data Transfer:** Instructions like `BPF.VM.STATUS` (to read VM status) and `BPF.VM.SEND`/`BPF.VM.RECV` (to interact with VM mailboxes).
        *   **Configuration:** Instructions like `BPF.CONF.SETLEN` to configure parameters such as data length for DMA operations.

        These custom "Y" instructions are decoded by the CVA6 CPU. The execution stage of the CPU then translates these instructions into one or more AXI4-Lite transactions. These transactions target the Control/Status Registers (CSRs) of the Keystone Coprocessor, allowing the CPU to command the coprocessor and exchange data with it. This mechanism provides a software-programmable interface to the coprocessor's functionalities directly from the CVA6 core.
    3.2. [Keystone Coprocessor](#32-keystone-coprocessor)
        3.2.1. [Overview](#321-overview)
        *(This section provides a general description of the Keystone Coprocessor.)*

        The Keystone Coprocessor is a specialized hardware accelerator integrated into the KESTREL-V SoC. Its primary purpose is to offload the execution of extended Berkeley Packet Filter (eBPF) programs from the main CVA6 CPU, providing dedicated hardware resources for eBPF virtual machine (VM) acceleration. This enhances the overall system performance for tasks involving eBPF-based packet processing, monitoring, or other forms of sandboxed execution.

        The Keystone Coprocessor interfaces with the rest of the SoC through two main AXI ports:
        *   An AXI4-Lite slave port (S1_AXI in the SoC interconnect) allows the CVA6 CPU to control the coprocessor and access its status by reading and writing to its Control/Status Registers (CSRs).
        *   An AXI4 master port (M1_AXI in the SoC interconnect) is used by the coprocessor's internal DMA (Direct Memory Access) engine to fetch eBPF programs and potentially other data from the main system memory.

        It plays a key role in enabling secure and efficient execution of eBPF logic within the KESTREL-V trusted execution environment.
        3.2.2. [Coprocessor Control Unit (CCU)](#322-coprocessor-control-unit-ccu)
        *(This section describes the Coprocessor Control Unit.)*

        The Coprocessor Control Unit (CCU) is the central command and control logic block within the Keystone Coprocessor. It orchestrates the operations of the entire coprocessor and acts as the primary interface to the CVA6 CPU.

        Key responsibilities of the CCU include:
        *   **AXI-Lite Slave Interface Management:** It exposes the coprocessor's CSRs to the CVA6 CPU via an AXI4-Lite slave interface. This involves decoding addresses from the CPU and handling read and write requests to the CSRs.
        *   **CSR Management:** The CCU contains and manages all the CSRs of the Keystone Coprocessor. These registers are used for configuring the coprocessor, initiating operations, selecting specific eBPF VM slots, passing data addresses and lengths, and reading status or interrupt information.
        *   **DMA Control:** It houses a DMA controller that uses the coprocessor's AXI master port. The CPU programs the DMA engine via CSRs to load eBPF programs (and potentially associated data) from main memory into the selected eBPF VM slot's program memory. The CCU manages the DMA process and signals completion or errors via status registers and interrupts.
        *   **VM Lifecycle Management:** The CCU processes commands from the CVA6 CPU (written to specific CSRs, often triggered by "Y" ISA extension instructions) to manage the lifecycle of the eBPF VMs. This includes starting, stopping, and resetting individual eBPF VM slots.
        *   **Mailbox Multiplexing:** It handles the routing of data between the CVA6 CPU and the mailboxes of the individual eBPF VM slots. When the CPU writes to a mailbox CSR in the CCU, the data is directed to the currently selected VM's IN mailbox. Conversely, data written by a VM to its OUT mailbox is made available to the CPU through CCU's mailbox CSRs.
        *   **Interrupt Aggregation:** The CCU aggregates various interrupt sources from within the coprocessor, such as DMA completion/error signals and VM completion/error signals from each eBPF VM slot. It reflects these statuses in the `INT_STATUS_REG` and generates a single interrupt signal (`copro_irq_w`) to the SoC's PLIC if any enabled interrupt condition occurs. This allows the CVA6 CPU to be notified of significant events within the coprocessor.
        3.2.3. [eBPF VM Slots](#323-ebpf-vm-slots)
        *(This section describes the eBPF VM Slots.)*

        The eBPF VM Slots are the dedicated hardware units within the Keystone Coprocessor responsible for the actual execution of eBPF programs. The KESTREL-V SoC design typically includes multiple identical eBPF VM Slots (e.g., 8 slots as indicated in the block diagrams), allowing for concurrent or isolated execution of different eBPF programs.

        Each eBPF VM Slot interfaces with the Coprocessor Control Unit (CCU) through several key signals:
        *   `select_vm_i`: A signal from the CCU that selects a specific VM slot for interactions like mailbox access or status reads via the CCU's CSRs.
        *   `start_vm_i`, `stop_vm_i`, `reset_vm_i`: Control signals from the CCU to manage the execution state of the nano-controller within the slot (start, stop, or reset its operation).
        *   DMA Write Interface (`write_prog_mem_en_i`, `write_prog_mem_addr_i`, `write_prog_mem_data_i`): Signals used by the CCU's DMA engine to write eBPF program bytecode into the slot's dedicated program memory.
        *   Mailbox Interface:
            *   Inputs from CCU (`mailbox_in_data_i`, `mailbox_in_idx_i`, `mailbox_in_wen_i`): For the CCU to write data into the slot's IN mailboxes.
            *   Outputs to CCU (`mailbox_out_data_o`, `mailbox_out_idx_o`, `mailbox_out_wen_o`): For the slot to write data from its OUT mailboxes, which the CCU then makes available to the CVA6 CPU.
        *   Interrupt/Status Lines (`done_o`, `error_o`, `error_code_o`): Signals from the slot to the CCU indicating completion of an eBPF program, occurrence of an error, and any specific error codes.

        Each slot provides an isolated environment for an eBPF program, including its own program memory, stack memory, and nano-controller.
        3.2.4. [PicoRV32 Nano-controller](#324-picorv32-nano-controller)
        *(This section describes the PicoRV32 Nano-controller within each eBPF VM Slot.)*

        Embedded within each eBPF VM Slot is a PicoRV32 nano-controller. This is a compact, 32-bit RISC-V CPU core (configured with RV32IMC ISA: Integer, Multiplication, and Compressed instructions) responsible for fetching, decoding, and executing the eBPF instructions of a loaded program. It achieves this by running a specialized piece of firmware known as a uBPF (micro BPF) interpreter.

        The PicoRV32 nano-controller operates on a set of memory-mapped resources within its eBPF VM Slot:
        *   **Local Instruction ROM (`nano_ctrl_instr_rom`):** This ROM stores the uBPF interpreter firmware. The PicoRV32 fetches its own instructions from this memory.
        *   **Local Data RAM (`nano_ctrl_data_ram`):** This RAM is used by the PicoRV32 for its own stack and any read/write data required by the uBPF interpreter firmware itself.
        *   **eBPF Program Memory:** A dedicated RAM within the slot that stores the eBPF bytecode loaded by the CCU's DMA engine. The PicoRV32 (running the uBPF interpreter) reads eBPF instructions from this memory.
        *   **eBPF Stack Memory:** A dedicated RAM used by the executing eBPF program for its own stack operations (e.g., storing local variables, function call arguments within the eBPF context).
        *   **Mailbox Registers (IN/OUT):** Memory-mapped registers that the PicoRV32 firmware can access to read data sent from the CVA6 CPU (via IN mailboxes) or write data intended for the CVA6 CPU (via OUT mailboxes).
        *   **Status Register (`ADDR_NANO_CTRL_STATUS_REG`):** A memory-mapped register that the PicoRV32 firmware writes to, indicating the status of the eBPF program execution (e.g., completion, errors, specific error codes). This status is then reported to the CCU.
    3.3. [AXI Interconnect](#33-axi-interconnect)
        *(This section describes the AXI Interconnect.)*

        The AXI Interconnect is a crucial component of the KESTREL-V SoC, acting as the central fabric that enables communication between various master and slave components. It implements the Advanced eXtensible Interface (AXI) protocol, specifically AXI4 and AXI4-Lite, to facilitate these connections.

        Its primary functions include:
        *   **Address Decoding:** It decodes the addresses generated by AXI master components to determine which slave component is being targeted. This is based on the SoC's global memory map (see Section 4.1).
        *   **Routing:** It routes AXI transactions (read/write commands, data, and responses) between the initiating master and the selected slave.
        *   **Arbitration:** (Though not explicitly detailed for the current stub, a full interconnect would handle arbitration when multiple masters attempt to access the same slave or shared resources simultaneously).

        **Master Ports:**
        The AXI Interconnect serves the following AXI master components:
        *   `M0_AXI`: Connected to the CVA6 CPU core. This port is used by the CPU for instruction fetches, data loads/stores, and accessing memory-mapped peripherals.
        *   `M1_AXI`: Connected to the DMA engine within the Keystone Coprocessor. This port is used by the Keystone Coprocessor to read eBPF programs and data from main memory.

        **Slave Ports:**
        The AXI Interconnect routes transactions to the following AXI slave components:
        *   `S0_AXI`: Connected to the Main Memory Controller (currently a DDR controller stub). This is an AXI4 Full interface.
        *   `S1_AXI`: Connected to the Keystone Coprocessor's Control/Status Registers (CSRs). This is an AXI4-Lite interface.
        *   `S2_AXI`: Connected to the Boot ROM. This is an AXI4-Lite interface (as per `AXI_Interconnect.v` stub, though `SoC_Memory_Map.txt` implies it could be AXI Full, the stub is more restrictive).
        *   `S3_AXI`: Connected to the Peripherals block (UART, PLIC, CLINT, etc.). This is an AXI4-Lite interface.
    3.4. [Memory System](#34-memory-system)
        3.4.1. [Boot ROM](#341-boot-rom)
        *(This section describes the Boot ROM.)*

        The Boot ROM (Read-Only Memory) stores the initial code executed by the CVA6 CPU core when the KESTREL-V SoC is powered on or reset. Its primary purpose is to perform basic system initialization and typically to load a more comprehensive bootloader (like U-Boot) from a non-volatile storage medium or a predefined location in main memory.

        In the current KESTREL-V SoC design:
        *   It is implemented as `Boot_ROM_Stub.v`.
        *   It interfaces with the AXI Interconnect as a slave device (S2_AXI). Based on the `AXI_Interconnect.v` stub, this is an AXI4-Lite interface.
        *   The size of the Boot ROM is defined as 4KB in `SoC_Memory_Map.txt` (address range `0x0000_0000` - `0x0000_0FFF`).
        *   For FPGA deployment, the Boot ROM content (e.g., `boot_content.hex`) will be initialized into Block RAM (BRAM) during bitstream generation.
        3.4.2. [Main Memory (DDR Stub)](#342-main-memory-ddr-stub)
        *(This section describes the Main Memory.)*

        The Main Memory serves as the primary random-access memory for the KESTREL-V SoC. It is used by the CVA6 CPU for storing the operating system, applications, user data, and runtime data. The Keystone Coprocessor's DMA engine also accesses it to fetch eBPF programs and related data.

        Key characteristics in the current design:
        *   It is represented by `Main_Memory_Ctrl_Stub.v`, which acts as a basic AXI4 Full slave memory model.
        *   It connects to the AXI Interconnect via slave port S0_AXI.
        *   The `SoC_Memory_Map.txt` allocates a 1GB address space for DRAM, from `0x8000_0000` to `0xBFFF_FFFF`.
        *   This stubbed implementation is intended for simulation and initial verification. For FPGA deployment, this stub will be replaced by a specific Microchip PolarFire SoC DDR controller IP (e.g., CoreDDR) to interface with external DDR RAM.
    3.5. [Peripherals](#35-peripherals)
        3.5.1. [UART Controller](#351-uart-controller)
        *(This section describes the UART Controller.)*

        The UART (Universal Asynchronous Receiver/Transmitter) Controller provides serial communication capabilities for the KESTREL-V SoC. It is primarily used for console input/output, enabling debugging, system interaction during boot-up, and communication with external devices or a host computer.

        In the KESTREL-V SoC:
        *   It is part of the `Peripherals_Stub.v` block.
        *   It interfaces with the AXI Interconnect as an AXI4-Lite slave, accessible by the CVA6 CPU at base address `0x0200_0000` (as per `SoC_Memory_Map.txt`).
        *   The Linux kernel's `serial_8250` driver (or a similar standard driver for ns16550a compatible UARTs) is expected to be used for communication if the stub adheres to a common standard.
        3.5.2. [Platform-Level Interrupt Controller (PLIC)](#352-platform-level-interrupt-controller-plic)
        *(This section describes the PLIC.)*

        The Platform-Level Interrupt Controller (PLIC) is a standard RISC-V component responsible for managing and prioritizing external interrupts from various sources within the SoC before presenting them to the CVA6 CPU core.

        Its role in the KESTREL-V SoC includes:
        *   Aggregating interrupt requests from multiple peripheral devices, including:
            *   The Keystone Coprocessor (e.g., `copro_irq_w` signaling DMA completion, VM completion, or errors).
            *   The UART controller (e.g., for transmit ready or receive data available).
            *   Timers (if a system timer outside of CLINT generates PLIC-routed interrupts).
        *   Prioritizing these incoming interrupt requests.
        *   Forwarding the highest priority pending interrupt to the CVA6 CPU's external interrupt input.
        *   Providing registers for the CPU to claim interrupts and signal their completion.
        *   It is part of the `Peripherals_Stub.v` block and is mapped to the AXI4-Lite interface at base address `0x0C00_0000` (as per `SoC_Memory_Map.txt`). The standard RISC-V PLIC driver in Linux will be configured to manage it.
        3.5.3. [Core Local Interruptor (CLINT)](#353-core-local-interruptor-clint)
        *(This section describes the CLINT.)*

        The Core Local Interruptor (CLINT) is another standard RISC-V component that provides machine-level timer interrupts and software interrupts directly to each CPU core. These interrupts are typically not routed through the PLIC.

        In the KESTREL-V SoC:
        *   It is primarily used to generate timer interrupts for the CVA6 CPU, which are essential for operating system scheduling and context switching.
        *   It also allows software to request an interrupt (Inter-Processor Interrupt or IPI, though less relevant for a single-core CVA6 setup, but standard in CLINT).
        *   The CLINT provides memory-mapped registers (e.g., `mtimecmp` for setting timer compare values, `mtime` for the current time, and `msip` for software interrupts) that the CVA6 CPU accesses.
        *   It is part of the `Peripherals_Stub.v` block and is mapped to the AXI4-Lite interface at base address `0x0201_0000` (as per `SoC_Memory_Map.txt`, though the typical CLINT address is often `0x0200_xxxx` in many RISC-V systems, the map here gives it a distinct offset).
4.  [Memory Maps](#4-memory-maps)
    4.1. [SoC Global Memory Map](#41-soc-global-memory-map)
        *(This section details the overall memory organization of the KESTREL-V SoC.)*

        The following table and notes describe the global memory map of the KESTREL-V SoC:
        ```
== SoC Memory Map ==

Default AXI Data Width: 32 bits

Region                      | Start Address | End Address   | Size     | AXI Type  | Notes
----------------------------|---------------|---------------|----------|-----------|----------------------------------------------------
Boot ROM                    | 0x0001_0000   | 0x0001_FFFF   | 64 KB    | AXI-Lite* | For CPU initial boot code. *Typically direct or simpler bus.
Generic Peripherals         | 0x0200_0000   | 0x0200_FFFF   | 64 KB    | AXI-Lite  | UART, Timer, GPIO, etc.
Keystone Coprocessor CSRs   | 0x1000_0000   | 0x1000_0FFF   | 4 KB     | AXI-Lite  | Control/Status Registers for Keystone Coprocessor.
Main Memory (DRAM)          | 0x8000_0000   | 0xBFFF_FFFF   | 1 GB     | AXI4 Full | Main system memory.

**Notes:**

1.  **Boot ROM:** While listed as AXI-Lite for interconnect purposes, in a real system, the CPU might have a dedicated boot interface that directly accesses the Boot ROM at address `0x0000_0000` or another designated boot address (like `0x00010000` after reset). For this design, we'll assume it's accessible via the AXI interconnect for simplicity if the CPU's boot sequence allows fetching from this address.
2.  **Address Alignment:** All regions are assumed to be aligned to their size or appropriate AXI boundaries.
3.  **Keystone Coprocessor CSRs:** The size (4KB) matches the typical page size and provides ample space for the registers defined in `AXI_Lite_Memory_Map.txt` for the coprocessor.
4.  **Generic Peripherals:** A 64KB region is allocated. Specific peripherals will be mapped within this space.
5.  **Main Memory:** 1GB is a common size for embedded SoCs capable of running Linux or complex applications.
6.  **AXI Types:**
    *   **AXI4 Full:** Used for high-throughput access, typically for memory.
    *   **AXI-Lite:** Used for simpler, register-based access to control/status registers or low-bandwidth peripherals.
7.  **Unmapped Regions:** Accesses to addresses outside these defined regions should result in an AXI error response (DECERR).

This memory map will guide the design of the AXI interconnect's address decoding logic.
The CVA6 CPU will typically start fetching instructions from the Boot ROM address after reset.
The Keystone Coprocessor's DMA will primarily interact with Main Memory.
The CVA6 CPU will interact with Keystone Coprocessor CSRs, Main Memory, and Generic Peripherals.
        ```
    4.2. [Keystone Coprocessor AXI-Lite CSR Map](#42-keystone-coprocessor-axi-lite-csr-map)
        *(This section details the memory map for the Keystone Coprocessor's Control/Status Registers.)*

        The Keystone Coprocessor's Control/Status Registers (CSRs) are mapped into the SoC's address space at `0x1000_0000` (see Section 4.1) and accessed via an AXI4-Lite interface. The following table details these registers:
        ```
== AXI4-Lite Slave Interface Memory Map for Keystone Coprocessor Control ==

Base Address: 0x0000_0000 (Offset from the base address assigned to the coprocessor in the system memory map)
AXI Data Width: 32 bits

All registers are Read/Write (RW) unless specified otherwise.
R = Read, W = Write, RC = Read Clear (reading clears the bits), SC = Self Clear (hardware clears bits after action)

Offset      | Register Name                | Bits      | Description
------------|------------------------------|-----------|----------------------------------------------------------------------------------------------------
**Global Control and Status Registers**
0x00        | COPRO_CMD_REG                |           | Coprocessor Command Register
            |                              | [0]       | `START_VM`: (SC) Start selected VM (selected by VM_SELECT_REG).
            |                              | [1]       | `STOP_VM`: (SC) Stop/Halt selected VM.
            |                              | [2]       | `RESET_VM`: (SC) Reset selected VM.
            |                              | [3]       | `LOAD_PROG`: (SC) Initiate program load for selected VM. CCU uses PROG_ADDR_LOW/HIGH_REG.
            |                              | [4]       | `LOAD_DATA_IN`: (SC) Initiate input data transfer for selected VM. CCU uses DATA_IN_ADDR_LOW/HIGH_REG.
            |                              | [7:5]     | Reserved
            |                              | [31:8]    | Command Data (Optional, e.g., specific flags for a command)
0x04        | VM_SELECT_REG                |           | VM Select Register
            |                              | [2:0]     | `VM_ID`: Selects one of the 8 eBPF VM Slots (0-7) for subsequent commands.
            |                              | [31:3]    | Reserved
0x08        | COPRO_STATUS_REG             | (R)       | Coprocessor Global Status Register
            |                              | [0]       | `BUSY`: Overall coprocessor busy (e.g., DMA active, or any VM busy).
            |                              | [7:1]     | Reserved
            |                              | [15:8]    | `ACTIVE_VM_MASK`: (R) Bitmask indicating which VMs are currently active/running.
            |                              | [31:16]   | Reserved
0x0C        | PROG_ADDR_LOW_REG            |           | Program Base Address Low (for DMA)
            |                              | [31:0]    | Lower 32 bits of the source address in main memory for eBPF program.
0x10        | PROG_ADDR_HIGH_REG           |           | Program Base Address High (for DMA) - for 64-bit addressing if needed
            |                              | [31:0]    | Upper 32 bits of the source address (if system uses >32 bit addresses).
0x14        | DATA_IN_ADDR_LOW_REG         |           | Input Data Base Address Low (for DMA)
            |                              | [31:0]    | Lower 32 bits of the source address in main memory for input data.
0x18        | DATA_IN_ADDR_HIGH_REG        |           | Input Data Base Address High (for DMA)
            |                              | [31:0]    | Upper 32 bits of the source address.
0x1C        | DATA_OUT_ADDR_LOW_REG        |           | Output Data Base Address Low (for DMA)
            |                              | [31:0]    | Lower 32 bits of the destination address in main memory for output data.
0x20        | DATA_OUT_ADDR_HIGH_REG       |           | Output Data Base Address High (for DMA)
            |                              | [31:0]    | Upper 32 bits of the destination address.
0x24        | DATA_LEN_REG                 |           | Data Length Register (for DMA transfers - program, data in/out)
            |                              | [31:0]    | Length in bytes for the current DMA operation (program or data).

**Interrupt Control Registers**
0x28        | INT_STATUS_REG               | (R/RC)    | Interrupt Status Register
            |                              | [0]       | `VM0_DONE_IRQ`: VM 0 completed execution.
            |                              | [1]       | `VM1_DONE_IRQ`: VM 1 completed execution.
            |                              | ...       | ...
            |                              | [7]       | `VM7_DONE_IRQ`: VM 7 completed execution.
            |                              | [8]       | `VM0_ERROR_IRQ`: VM 0 encountered an error.
            |                              | ...       | ...
            |                              | [15]      | `VM7_ERROR_IRQ`: VM 7 encountered an error.
            |                              | [16]      | `DMA_DONE_IRQ`: DMA transfer completed.
            |                              | [17]      | `DMA_ERROR_IRQ`: DMA transfer error.
            |                              | [31:18]   | Reserved
0x2C        | INT_ENABLE_REG               |           | Interrupt Enable Register
            |                              | [0]       | `VM0_DONE_EN`: Enable interrupt for VM 0 completion.
            |                              | [1]       | `VM1_DONE_EN`: Enable interrupt for VM 1 completion.
            |                              | ...       | ...
            |                              | [7]       | `VM7_DONE_EN`: Enable interrupt for VM 7 completion.
            |                              | [8]       | `VM0_ERROR_EN`: Enable interrupt for VM 0 error.
            |                              | ...       | ...
            |                              | [15]      | `VM7_ERROR_EN`: Enable interrupt for VM 7 error.
            |                              | [16]      | `DMA_DONE_EN`: Enable interrupt for DMA completion.
            |                              | [17]      | `DMA_ERROR_EN`: Enable interrupt for DMA error.
            |                              | [31:18]   | Reserved

**Per-VM Status Registers (Optional - could be part of a larger status block read via VM_SELECT_REG)**
*Access to these might be indirect: first write VM_ID to VM_SELECT_REG, then read/write these.*
*Alternatively, map a block of 8xN registers for direct access if address space allows.*
*For this initial map, we assume VM_SELECT_REG is used to query specific VM status.*

0x30        | SELECTED_VM_STATUS_REG       | (R)       | Status of the VM selected by VM_SELECT_REG
            |                              | [0]       | `READY`: VM is ready for new program/data.
            |                              | [1]       | `RUNNING`: VM is currently executing.
            |                              | [2]       | `DONE`: VM execution finished.
            |                              | [3]       | `ERROR`: VM is in an error state.
            |                              | [7:4]     | `ERROR_CODE`: Specific error code if ERROR is set.
            |                              | [31:8]    | Reserved
0x34        | SELECTED_VM_PC_REG           | (R)       | Program Counter of the selected VM (for debugging)
            |                              | [31:0]    | Current PC value.
0x38        | SELECTED_VM_DATA_OUT_ADDR_REG | (R)       | Address where selected VM wrote its output data (if applicable, relative to a VM-specific area or absolute if DMA'd by VM itself)
            |                              | [31:0]    | Output data address.

**Data Mailbox Registers (Example - if direct CPU data passing is needed, typically for small amounts of data)**
*These are typically per-VM or a shared mailbox selected by VM_SELECT_REG.*
*Assuming a single shared mailbox for simplicity here, selected by VM_SELECT_REG before access.*

0x80        | MAILBOX_DATA_IN_0_REG        |           | Mailbox for CPU to write data to selected VM (Word 0)
            |                              | [31:0]    | Data Word 0
0x84        | MAILBOX_DATA_IN_1_REG        |           | Mailbox for CPU to write data to selected VM (Word 1)
            |                              | [31:0]    | Data Word 1
...         | ...                          | ...       | ... (e.g., up to 4-8 words)
0x9C        | MAILBOX_DATA_IN_N_REG        |           | (Example last input word)

0xA0        | MAILBOX_DATA_OUT_0_REG       | (R)       | Mailbox for CPU to read data from selected VM (Word 0)
            |                              | [31:0]    | Data Word 0
0xA4        | MAILBOX_DATA_OUT_1_REG       | (R)       | Mailbox for CPU to read data from selected VM (Word 1)
            |                              | [31:0]    | Data Word 1
...         | ...                          | ...       | ... (e.g., up to 4-8 words)
0xBC        | MAILBOX_DATA_OUT_N_REG       | (R)       | (Example last output word)

0xFC        | COPRO_VERSION_REG            | (R)       | Coprocessor Version Register
            |                              | [7:0]     | Patch Version
            |                              | [15:8]    | Minor Version
            |                              | [23:16]   | Major Version
            |                              | [31:24]   | Reserved

**Notes:**
1.  This is a preliminary memory map. Addresses and register functions may change as the design evolves.
2.  DMA operations (LOAD_PROG, LOAD_DATA_IN, and implicit DATA_OUT by VMs) will use the respective Address Low/High and Data Length registers. The CCU will manage the DMA engine based on these.
3.  Interrupts: The `INT_STATUS_REG` reflects the source of interrupts. The CPU should read this register to determine the cause and then clear the corresponding bit(s) (if R/C). `INT_ENABLE_REG` controls which sources can actually generate an interrupt signal to the CPU. The global `interrupt_out` from the coprocessor is an OR of all enabled and active interrupts.
4.  Accessing per-VM status (0x30-0x38): The typical flow would be:
    a.  Write to `VM_SELECT_REG` to choose VM_ID.
    b.  Read `SELECTED_VM_STATUS_REG`, `SELECTED_VM_PC_REG`, etc.
5.  Mailbox registers provide a simple way for the CPU to exchange small amounts of data directly with a VM, bypassing main memory DMA. The CCU would facilitate moving data between these registers and the selected VM's internal data structures.
6.  The exact address range for "Per-VM Status Registers" and "Data Mailbox Registers" might be replicated for each VM if direct addressing is preferred over select-then-access, which would consume more address space (e.g., 0x100 - 0x1FF for VM0 registers, 0x200 - 0x2FF for VM1 registers, etc.). The current map assumes a more compact, select-then-access model for these.
7.  `s_axi_aresetn` is active low. Registers should be reset to defined default values. For example, enable registers might reset to 0, status registers to a "ready" or "idle" state.
8.  `COPRO_CMD_REG` commands are self-clearing (SC) where appropriate, meaning the hardware will clear the command bit after it has been accepted/actioned by the CCU. This prevents the command from being accidentally re-triggered on a subsequent register write if the CPU doesn't explicitly clear it.
        ```
5.  [Interfaces](#5-interfaces)
    5.1. [AXI Protocol Usage](#51-axi-protocol-usage)
        5.1.1. [AXI4 Full (Main Memory, DMA)](#511-axi4-full-main-memory-dma)
        *(This section describes the use of AXI4 Full.)*

        The AXI4 Full protocol is utilized for high-bandwidth data transfers within the KESTREL-V SoC. It is primarily employed for:
        *   **CVA6 CPU access to Main Memory:** The CVA6 CPU uses its AXI master port (M0_AXI) to communicate with the Main Memory Controller (S0_AXI, currently a DDR stub) for instruction fetches and data load/store operations. AXI4 Full allows for burst transactions, which are efficient for transferring cache lines and larger data blocks.
        *   **Keystone Coprocessor DMA to Main Memory:** The DMA engine within the Keystone Coprocessor uses its AXI master port (M1_AXI) to perform AXI4 Full transactions with the Main Memory Controller (S0_AXI). This is used for loading eBPF programs into the eBPF VM Slots and potentially for transferring larger data sets associated with eBPF program execution.
        5.1.2. [AXI4-Lite (Peripherals, CSRs)](#512-axi4-lite-peripherals-csrs)
        *(This section describes the use of AXI4-Lite.)*

        The AXI4-Lite protocol, a simplified subset of AXI4, is used for single-beat data transfers, primarily for accessing control and status registers or low-bandwidth peripherals. In the KESTREL-V SoC, AXI4-Lite is used for:
        *   **CVA6 CPU access to Keystone Coprocessor CSRs:** The CVA6 CPU (M0_AXI) communicates with the Keystone Coprocessor's Control/Status Registers (S1_AXI) using AXI4-Lite. This interface is suitable for reading status, writing commands, and configuring the coprocessor.
        *   **CVA6 CPU access to Boot ROM:** The Boot ROM (S2_AXI) is accessed by the CVA6 CPU using AXI4-Lite for fetching initial boot instructions.
        *   **CVA6 CPU access to Peripherals:** The Generic Peripherals block (S3_AXI), which includes the UART controller, PLIC, and CLINT, is accessed by the CVA6 CPU using AXI4-Lite. This is appropriate for register-based configuration and control of these peripherals.
    5.2. [Mailbox Communication Protocol](#52-mailbox-communication-protocol)
        *(This section explains the CPU-VM mailbox communication.)*

        The KESTREL-V SoC provides a mailbox mechanism for direct, low-latency communication of small data packets between the CVA6 CPU and the eBPF VM slots within the Keystone Coprocessor. This is useful for passing control parameters, small data payloads, or results without the overhead of DMA through main memory.

        The communication flow is managed by the Coprocessor Control Unit (CCU) and utilizes dedicated CSRs:
        *   **CPU-to-VM:**
            1.  The CVA6 CPU first writes the target VM's ID to the `VM_SELECT_REG` in the CCU.
            2.  The CPU then writes data to one or more of the `MAILBOX_DATA_IN_x_REG` registers (e.g., `0x80` to `0x9C` in the CSR map).
            3.  The CCU routes this data to the IN mailboxes of the selected eBPF VM slot.
        *   **VM-to-CPU:**
            1.  The PicoRV32 firmware running within an eBPF VM slot writes data to its memory-mapped OUT mailbox registers (accessible at `EBPF_MAILBOX_OUT_BASE_ADDR` from the PicoRV32's perspective).
            2.  The CCU captures this data from the currently selected VM (as per `VM_SELECT_REG`).
            3.  The CVA6 CPU can then read this data from the `MAILBOX_DATA_OUT_x_REG` registers (e.g., `0xA0` to `0xBC` in the CSR map) after selecting the appropriate VM via `VM_SELECT_REG`.

        The PicoRV32 firmware typically interacts with these mailboxes through helper functions, such as `bpf_mailbox_send()` to write to an OUT mailbox and `bpf_mailbox_recv()` to read from an IN mailbox, which abstract the underlying memory-mapped register accesses. The number of mailbox registers (e.g., `NUM_MAILBOX_REGS_VM=4` as per `PicoRV32_uBPF_Firmware_Plan.md`) defines the capacity of each mailbox.
    5.3. [Interrupt Architecture](#53-interrupt-architecture)
        *(This section describes the interrupt flow and management.)*

        The KESTREL-V SoC employs a comprehensive interrupt architecture to manage asynchronous events and signal them to the CVA6 CPU.

        **Interrupt Sources:**
        *   **Keystone Coprocessor:** This is a major source of interrupts.
            *   `VMx_DONE_IRQ`: Indicates that an eBPF VM slot (VM0-VM7) has completed its execution.
            *   `VMx_ERROR_IRQ`: Indicates that an eBPF VM slot has encountered an error.
            *   `DMA_DONE_IRQ`: Signals completion of a DMA operation (e.g., program load).
            *   `DMA_ERROR_IRQ`: Signals an error during a DMA operation.
            These conditions are reflected in the Keystone Coprocessor's `INT_STATUS_REG`. The corresponding bits in `INT_ENABLE_REG` must be set for an interrupt to be generated.
        *   **Peripherals:**
            *   **UART Controller:** Can generate interrupts for events like transmit buffer empty or receive data available.
            *   **Timers:** System timers can generate interrupts. (Note: The CLINT timer is core-local, but other system timers could exist).

        **Interrupt Flow and Management:**
        1.  **Keystone Coprocessor Interrupts:** Internal events within the Keystone Coprocessor (VM done/error, DMA done/error) set flags in its `INT_STATUS_REG`. If the corresponding enable bit in `INT_ENABLE_REG` is set, the CCU asserts its `copro_irq_w` output line.
        2.  **Platform-Level Interrupt Controller (PLIC):** The `copro_irq_w` from the Keystone Coprocessor, along with interrupt lines from other peripherals like the UART, are connected to the PLIC. The PLIC is responsible for:
            *   Prioritizing incoming interrupt requests from multiple sources.
            *   Forwarding the highest priority pending interrupt signal to the CVA6 CPU's external interrupt input.
            *   Providing CSRs for the CVA6 CPU to query the source of the interrupt (claim) and signal its completion, allowing the PLIC to service the next pending interrupt.
        3.  **Core Local Interruptor (CLINT):** The CLINT provides direct interrupt sources to the CVA6 CPU that are not routed through the PLIC. These include:
            *   **Machine Timer Interrupts:** Generated when the `mtime` register (counter) in the CLINT reaches the value in the `mtimecmp` register of the CVA6 core. Essential for OS scheduling.
            *   **Machine Software Interrupts:** Triggered by writing to the `msip` register in the CLINT. Used for inter-processor communication (less relevant for single-core CVA6 but part of the standard) or for software-driven interrupt requests.
        4.  **CVA6 CPU Interrupt Handling:** The CVA6 CPU, upon receiving an interrupt signal (either from PLIC or CLINT), will typically switch to a specific interrupt handler routine. This routine will query the cause of the interrupt (e.g., read PLIC claim register or CLINT's `mcause` register), service the interrupt, and then signal completion.
6.  [PicoRV32 uBPF Firmware](#6-picorv32-ubpf-firmware)
    6.1. [Overview](#61-overview)
        *(This section provides an overview of the firmware for the PicoRV32 nano-controllers.)*

        The PicoRV32 uBPF (micro BPF) firmware is a specialized program that runs on the PicoRV32 nano-controllers located within each eBPF VM slot of the Keystone Coprocessor. Its primary purpose is to interpret and execute eBPF bytecode that has been loaded into the respective VM slot by the CVA6 CPU via the CCU's DMA mechanism.

        The firmware is developed using a standard RISC-V GCC toolchain, targeting the `rv32imc` instruction set architecture (Integer, Multiplication, and Compressed instructions), which matches the configuration of the PicoRV32 cores used in the KESTREL-V SoC.
    6.2. [Interpreter Functionality](#62-interpreter-functionality)
        *(This section describes the core functionality of the uBPF interpreter.)*

        The core task of the uBPF interpreter firmware is to fetch eBPF instructions from the eBPF Program Memory within its VM slot, decode these instructions, and then execute them according to the eBPF specification. This involves:
        *   Maintaining an eBPF program counter (PC).
        *   Reading eBPF instructions from the eBPF Program Memory, which is memory-mapped from the PicoRV32's perspective.
        *   Accessing eBPF registers (simulated in PicoRV32's general-purpose registers or local RAM).
        *   Performing operations on the eBPF Stack Memory, also memory-mapped from the PicoRV32's perspective, for stack-related eBPF instructions.
        *   Handling control flow instructions (jumps, calls).
        *   Calling registered eBPF helper functions when encountered.
    6.3. [Helper Functions](#63-helper-functions)
        *(This section details the eBPF helper functions implemented in the firmware.)*

        eBPF programs executed by the uBPF interpreter can call pre-defined "helper functions" to interact with the KESTREL-V SoC environment or perform operations not directly available in the eBPF instruction set. These helper functions are implemented as C functions within the PicoRV32 firmware. Key helper functions include:
        *   **Mailbox Communication:**
            *   `bpf_mailbox_send(uint32_t mbox_idx, uint64_t data_val)`: Allows the eBPF program to write data to one of its OUT mailbox registers. The firmware handles the memory-mapped write to the appropriate `EBPF_MAILBOX_OUT_BASE_ADDR` offset.
            *   `bpf_mailbox_recv(uint32_t mbox_idx, uint64_t* data_val_ptr)`: Allows the eBPF program to read data from one of its IN mailbox registers, which would have been previously written by the CVA6 CPU. The firmware handles the memory-mapped read from `EBPF_MAILBOX_IN_BASE_ADDR`.
        *   **Status Reporting:**
            *   `bpf_vm_set_done(void)`: Called by the eBPF program to indicate it has completed its execution. The firmware writes to the `done` bit in the PicoRV32's `ADDR_NANO_CTRL_STATUS_REG`.
            *   `bpf_vm_set_error(uint8_t err_code)`: Called by the eBPF program to signal an error condition. The firmware writes to the `error` bit and the `error_code` field in the `ADDR_NANO_CTRL_STATUS_REG`.
        These helper functions are registered with the uBPF interpreter, mapping specific eBPF helper function IDs to their firmware implementations.
    6.4. [Memory Layout](#64-memory-layout)
        *(This section describes the memory organization for the PicoRV32 firmware.)*

        The PicoRV32 nano-controller within each eBPF VM slot has its own local memory space, distinct from the main SoC memory map. This local memory is organized by a linker script used during firmware compilation:
        *   **Instruction ROM (`nano_ctrl_instr_rom`):** This is an 8KB Read-Only Memory (starting at PicoRV32 local address `0x0000_0000`) that stores the compiled uBPF interpreter firmware (its `.text` and `.rodata` sections).
        *   **Data RAM (`nano_ctrl_data_ram`):** This is a 4KB Read/Write Memory (starting at PicoRV32 local address `0x0000_2000`) used for the PicoRV32's own stack, and for any read/write data (`.data`, `.bss` sections) required by the uBPF interpreter itself.

        The linker script ensures that the firmware code is placed correctly into the ROM region and that RAM is allocated for the stack and data sections. The stack typically grows downwards from the top of the Data RAM.
7.  [Clocking and Reset Strategy](#7-clocking-and-reset-strategy)
    7.1. [Clock Domains](#71-clock-domains)
        *(This section describes the SoC's clocking strategy.)*

        The KESTREL-V SoC operates based on a primary system clock input, typically denoted as `clk_i` (or `clk` at the SoC boundary). This main clock serves as the basis for generating various clock signals required by different components within the SoC.
        A Clock Generation and Distribution Unit (conceptually, often a Phase-Locked Loop (PLL) and clock dividers, e.g., using PolarFire's `PF_CCC` IP for FPGA deployment) is responsible for:
        *   Generating the CPU clock for the CVA6 core.
        *   Generating the AXI interconnect clock, which may be synchronous with the CPU clock or a divided version.
        *   Generating the clock for the Keystone Coprocessor, including its CCU and the PicoRV32 nano-controllers.
        *   Providing necessary clocks for the Main Memory Controller (e.g., DDR controller), which often has specific frequency requirements.
        *   Clocking the AXI4-Lite peripherals (UART, PLIC, CLINT).

        If different components operate at different clock frequencies, careful design of Clock Domain Crossings (CDCs) is essential to prevent metastability issues and ensure reliable data transfer between these domains. This typically involves using synchronizer circuits for single-bit control signals and asynchronous FIFOs for multi-bit data paths.
    7.2. [Reset Logic](#72-reset-logic)
        *(This section describes the SoC's reset strategy.)*

        The KESTREL-V SoC utilizes a global, active-low reset input, typically `resetn_i` (or `resetn` at the SoC boundary). This primary reset signal is the source for resetting the entire chip.
        A Reset Distribution Unit is responsible for:
        *   Synchronizing the external asynchronous reset signal to the main clock domain to prevent metastability issues related to reset de-assertion.
        *   Distributing the synchronized reset signal to all components within the SoC, including the CVA6 CPU, AXI Interconnect, Keystone Coprocessor (CCU and eBPF VM Slots), Main Memory Controller, and all peripherals.
        *   Ensuring proper reset sequencing if required by specific IP blocks (e.g., ensuring the memory controller is reset before the CPU attempts to access memory).
        All flip-flops and stateful elements within the design are expected to be reset to a known default state upon assertion of this global reset.
8.  [Glossary](#8-glossary)
9.  [References](#9-references)

---

## 1. Introduction

### 1.1. Purpose

This document provides a detailed design description of the KESTREL-V System-on-Chip (SoC). It is intended for hardware and software developers working on, or interfacing with, the KESTREL-V SoC.

### 1.2. Scope

This document covers the architecture, components, interfaces, memory maps, and key operational aspects of the KESTREL-V SoC. It consolidates information from various planning documents and source files.

### 1.3. Project Overview

KESTREL-V (Keystone Enclave Secured TRusted eBPF Logic on RISC-V) is a System-on-Chip (SoC) designed to provide a secure and high-performance platform for executing eBPF (extended Berkeley Packet Filter) programs. The project integrates a RISC-V CPU core (CVA6) with a specialized Keystone Coprocessor. This coprocessor offloads eBPF execution into isolated, hardware-accelerated virtual machine (VM) slots, leveraging PicoRV32 nano-controllers. The design aims to enable trusted execution of eBPF logic, potentially within a Keystone Enclave framework, for applications such as secure packet processing, network monitoring, and other tasks requiring sandboxed, verifiable computation.

### 1.4. Document Conventions

*   AXI: Advanced eXtensible Interface
*   CSR: Control/Status Register
*   eBPF: extended Berkeley Packet Filter
*   SoC: System-on-Chip
*   ...(other conventions as needed)

---

## 2. System Architecture

This section describes the KESTREL-V SoC from a high-level perspective down to its major functional blocks.

### 2.1. High-Level System View

#### 2.1.1. Overview
*(This section is populated from BLOCK_DIAGRAMS.md -> "1. High-Level Block Diagram")*

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

### 2.2. Mid-Level SoC Block Diagram

#### 2.2.1. Overview
*(This section is populated from BLOCK_DIAGRAMS.md -> "2. Mid-Level SoC Block Diagram")*

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

### 2.3. Low-Level Keystone Coprocessor Detail

#### 2.3.1. Overview
*(This section is populated from BLOCK_DIAGRAMS.md -> "3. Low-Level Block Diagram: Keystone Coprocessor Detail")*

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

---

*(Further sections will be populated based on the plan.)*
