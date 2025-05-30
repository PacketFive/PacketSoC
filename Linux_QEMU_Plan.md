# Linux Porting and QEMU Emulation Plan for KESTREL-V SoC

## 0. Document Purpose

This document outlines the strategy and planning for porting Linux to the custom System-on-Chip (SoC) featuring the CVA6 CPU core and the Keystone Coprocessor, and for setting up a QEMU emulation environment for this SoC.

## 1. Linux Board Support Package (BSP) Development

### 1.1. Bootloader

#### 1.1.1. First-Stage Bootloader (FSBL) / Boot ROM
*   **Current Status:** The `Boot_ROM_Stub.v` provides a very basic mechanism for the CVA6 CPU to start fetching instructions.
*   **Requirements:**
    *   Minimal initialization of the CVA6 core (e.g., basic trap handling, setting up a stack pointer).
    *   Ability to load a larger, second-stage bootloader (U-Boot) from a known location (e.g., an offset in the main AXI address space where QEMU can place it, or from a simulated flash/SD card if such a peripheral is added to the SoC/QEMU model).
    *   For initial QEMU testing, the FSBL might be very simple, with QEMU directly loading U-Boot into simulated DRAM.
    *   If a non-volatile memory (e.g., SPI Flash) is added to the SoC design later, the Boot ROM will need to include a driver for it to load U-Boot.

#### 1.1.2. U-Boot (Second-Stage Bootloader)
*   **Porting to CVA6:**
    *   Obtain a recent U-Boot source tree.
    *   Create a new board configuration for our SoC (e.g., `configs/kestrel_v_soc_defconfig`).
    *   Configure U-Boot for a generic RISC-V 64-bit (`rv64gc`) target, matching the CVA6 core.
    *   Adapt or implement necessary low-level drivers within U-Boot:
        *   **Timer:** For delays and scheduling (a generic RISC-V timer or a custom one if present in `Peripherals_Stub.v`).
        *   **Serial/UART:** For console output, based on the peripheral in `Peripherals_Stub.v`. A standard 8250/16550 compatible driver might be adaptable.
        *   **Memory Controller:** Configure DRAM size and base address (`0x8000_0000`).
        *   **(Optional) Non-Volatile Storage Driver:** If U-Boot needs to load the kernel from Flash/SD.
*   **SoC Configuration:**
    *   Memory map configuration in U-Boot to match `SoC_Memory_Map.txt`.
    *   Environment variables for kernel loading address, DTB address, boot arguments.
    *   Command to load kernel, DTB, and rootfs (e.g., from memory if using QEMU's `-kernel`, `-initrd` options, or from a device like TFTP/SD if emulated).
*   **ISA "Y" Awareness:** U-Boot itself will likely *not* directly use ISA "Y" instructions. Its primary role is to set up the hardware and load the Linux kernel.

### 1.2. Linux Kernel

#### 1.2.1. Base RISC-V Configuration
*   Start with a recent Linux kernel version with good RISC-V support.
*   Configure the kernel for `ARCH=riscv`, `CROSS_COMPILE=riscv64-linux-gnu-`.
*   Use a generic `rv64gc` configuration as a baseline (`defconfig`).
*   Key kernel features: MMU, syscalls, interrupt handling, timers.

#### 1.2.2. Device Driver for Keystone Coprocessor
This is a custom driver.
*   **Interface to Userspace:**
    *   Character device (e.g., `/dev/keystone_copro`).
    *   `ioctl` commands for:
        *   Selecting a VM slot (`KS_IOCTL_SELECT_VM`).
        *   Loading an eBPF program into a VM (`KS_IOCTL_LOAD_PROG`, passing program buffer and length). The driver will use DMA for this.
        *   Starting/stopping/resetting a VM (`KS_IOCTL_START_VM`, `KS_IOCTL_STOP_VM`, `KS_IOCTL_RESET_VM`).
        *   Getting VM status (`KS_IOCTL_GET_VM_STATUS`).
        *   Sending data to a VM's IN mailbox (`KS_IOCTL_SEND_MAILBOX`, with mailbox index and data).
        *   Receiving data from a VM's OUT mailbox (`KS_IOCTL_RECV_MAILBOX`, with mailbox index).
*   **Using ISA "Y" Instructions:**
    *   The kernel driver cannot directly execute ISA "Y" instructions as they are custom and not known to the compiler.
    *   **Mechanism:** The "Y" instructions are intended for direct CPU control over the coprocessor's AXI-Lite CSRs. The driver will achieve this by:
        *   Memory-mapping the Keystone Coprocessor's CSR region (`0x1000_0000`) using `ioremap()`.
        *   Performing direct `readl()`/`writel()` operations to these mapped CSR addresses to simulate the effect of the "Y" instructions. For example, `BPF.VM.START` would translate to:
            1.  `writel(vm_idx, ccu_base + ADDR_VM_SELECT_REG);`
            2.  `writel(CMD_START_VM_BIT, ccu_base + ADDR_COPRO_CMD_REG);`
            3.  (Optionally) `status = readl(ccu_base + ADDR_COPRO_STATUS_REG);`
        *   This approach bypasses needing a modified compiler or M-mode/S-mode services specifically for *executing* these instructions, as the driver itself orchestrates the low-level register accesses that the "Y" instructions would have performed.
*   **Interrupt Handling:**
    *   Request an IRQ line (connected from `copro_irq_w` to the CVA6 interrupt controller).
    *   The interrupt handler (`irq_handler_t`) will:
        1.  Read the Keystone Coprocessor's `INT_STATUS_REG`.
        2.  Determine the source of the interrupt (VM done/error, DMA done/error).
        3.  Clear the interrupt bits in `INT_STATUS_REG` (by writing back the read value or specific clear bits).
        4.  Wake up relevant user-space processes waiting on events (e.g., VM completion, mailbox data available).
        5.  Schedule deferred work if necessary.
*   **Memory Management for eBPF and Data Buffers:**
    *   User-space provides eBPF programs and data buffers.
    *   The driver will need to:
        *   Copy eBPF programs from user space (`copy_from_user`) into kernel space.
        *   Allocate physically contiguous kernel memory buffers (e.g., using `kmalloc` with `GFP_KERNEL | GFP_DMA` or the DMA API `dma_alloc_coherent`) for DMA operations (program load, data in/out if DMA is used for data mailboxes later).
        *   Pass the physical addresses of these buffers to the Keystone Coprocessor's DMA configuration registers (e.g., `PROG_ADDR_LOW_REG`, `DATA_IN_ADDR_LOW_REG`).
        *   Manage the lifetime and synchronization of these buffers.

#### 1.2.3. Device Drivers for Peripherals
*   **UART:** Based on `Peripherals_Stub.v`, if it resembles a standard UART (e.g., 8250/16550), the existing Linux `serial_8250` driver can be configured. If custom, a simple driver will be needed. Address: `0x0200_0000` + offsets.
*   **Timer:** A timer peripheral is essential. RISC-V standard timer interrupts are typically part of the CLINT (Core Local Interruptor) or a platform-specific timer. If `Peripherals_Stub.v` implies a separate timer, a driver would be needed.
*   **Interrupt Controller:** CVA6 uses a PLIC (Platform-Level Interrupt Controller). The standard RISC-V PLIC driver will be configured.
*   **GPIO (Conceptual):** If GPIOs were added to `Peripherals_Stub.v`, a standard GPIO driver might be adaptable.

### 1.3. Device Tree (DTB)

A `.dts` (Device Tree Source) file will describe the hardware to the Linux kernel.

*   **Key Components:**
    *   **Root Node:** `compatible = "keystone,soc"; model = "KESTREL-V SoC"; #address-cells = <1>; #size-cells = <1>;`
    *   **CPUs:** Define CVA6 core(s) (`compatible = "ariane,cva6"; riscv,isa = "rv64gc";`). Include CLINT if present.
    *   **Memory:** Define main DRAM region (`device_type = "memory"; reg = <0x80000000 0x40000000>;` for 1GB).
    *   **Keystone Coprocessor:**
        *   `compatible = "keystone,coprocessor-v1";`
        *   `reg = <0x10000000 0x1000>;` (CSR region base and size)
        *   `interrupts = <IRQ_NUM>;` (Interrupt number connected to PLIC)
        *   `interrupt-parent = <&plic>;`
        *   Custom properties if needed by the driver (e.g., number of VM slots, mailbox depth if configurable).
    *   **Peripherals (within `soc` node):**
        *   **UART:** `compatible = "ns16550a"; reg = <0x02000000 UART_TX_REG_OFFSET UART_REG_SIZE>; clock-frequency = <UART_CLK_FREQ>; interrupts = <UART_IRQ_NUM>; interrupt-parent = <&plic>;`
        *   **Timer:** Define based on its type and registers.
        *   **PLIC (Interrupt Controller):** `compatible = "riscv,plic0"; reg = <PLIC_BASE_ADDR PLIC_SIZE>; interrupts-extended; riscv,ndev = <NUM_PLIC_SOURCES>; #interrupt-cells = <1>; interrupt-controller;`
    *   **Chosen Node:** `bootargs = "console=ttyS0,115200 root=/dev/ram0 rw"; stdout-path = &uart0;` (example)

### 1.4. Root Filesystem
*   **Build System:**
    *   **Buildroot:** Simpler for generating a minimal root filesystem quickly.
    *   **Yocto Project:** More complex but more flexible for custom distributions.
    *   Start with Buildroot for initial bring-up.
*   **Contents:**
    *   BusyBox for basic utilities.
    *   Dropbear for SSH (optional).
    *   C library (glibc, musl).
    *   **eBPF Tools (for testing):**
        *   `libelf` (if programs are loaded as ELF).
        *   A simple custom command-line tool to interact with the `/dev/keystone_copro` device node (using `ioctl`) to load and run eBPF programs and test mailbox functionality.
    *   The rootfs can be an `initramfs` loaded by U-Boot or QEMU, or a block device image (e.g., ext4) if storage is emulated.

## 2. QEMU Emulation Environment Setup

### 2.1. QEMU Machine Definition
*   A new machine type (e.g., `kestrel-v-soc-machine`) will be added to QEMU.
*   This involves creating a new C file in `hw/riscv/` (e.g., `kestrel_v_soc.c`).
*   The machine definition function will:
    *   Instantiate the CVA6 CPU model (or a generic RISC-V CPU model initially).
    *   Define the memory map (`SoC_Memory_Map.txt`).
    *   Instantiate and map QEMU models for peripherals (DRAM, UART, PLIC, CLINT, Keystone Coprocessor model).

### 2.2. CVA6 CPU Model with ISA "Y"
*   **Approach:** QEMU's RISC-V CPU model uses TCG (Tiny Code Generator) to translate guest instructions into host code.
    1.  **Add Opcode:** Define the `custom-0` opcode in QEMU's RISC-V instruction decoder (`target/riscv/insn32.decode` or `insn64.decode`).
    2.  **Translation Logic:** Implement a new translation function (helper function in C) for each "Y" instruction variant (based on `funct3`/`funct7`).
    3.  **Interaction with Keystone Model:**
        *   These translation functions will not directly execute AXI transactions like the hardware.
        *   Instead, they will call C functions that interact with the QEMU model of the Keystone Coprocessor.
        *   For example, a `BPF.VM.START` instruction's translation function would call a function like `keystone_copro_start_vm(cpu_env, vm_idx)`. This C function within the Keystone QEMU model would then update the model's state.
        *   For CSR accesses (like setting `PROG_ADDR_LOW_REG`), the "Y" instruction translation would call a function like `keystone_copro_csr_write(cpu_env, reg_addr, value)`.

### 2.3. Keystone Coprocessor QEMU Model
A new QEMU device model (e.g., `hw/misc/keystone_copro.c`) will be created.
*   **Registers:**
    *   Implement an array or struct to represent all CSRs defined in `AXI_Lite_Memory_Map.txt`.
    *   Provide memory-mapped I/O handlers (`readfn`, `writefn`) for QEMU to access these registers when the CPU model writes to the `0x1000_0000` region.
*   **Behavioral Modeling of DMA:**
    *   When `LOAD_PROG` or `LOAD_DATA_IN` is commanded via CSR write:
        *   The model will read the `PROG_ADDR_LOW_REG`, `DATA_LEN_REG`.
        *   It will simulate a DMA read by directly accessing QEMU's host memory representation of the guest's main memory (DRAM) at the specified address.
        *   The "read" data will be conceptually stored or directly "written" to a placeholder for the target VM's program memory within the coprocessor model.
        *   Signal DMA completion (and set `DMA_DONE_IRQ`).
*   **Behavioral Modeling of eBPF VM Lifecycles:**
    *   No need to emulate PicoRV32 instruction-by-instruction.
    *   When a `START_VM` command is received: Mark the VM model as "running".
    *   When a `STOP_VM` command is received: Mark as "stopped".
    *   Mailbox interaction:
        *   CPU writes to IN mailbox CSRs: Store data in the model's representation of `vm_mailboxes_in`.
        *   CPU reads from OUT mailbox CSRs: Return data from `vm_mailboxes_out`.
        *   The QEMU model will need internal state for `vm_mailboxes_out` that can be "written" by a conceptual VM (e.g., a test function in QEMU can populate this).
*   **Interrupt Simulation:**
    *   The model will have an internal `INT_STATUS_REG` representation.
    *   When a VM "completes" (simulated event, e.g., after a delay or a specific mailbox write from a test), or DMA "completes", set the corresponding bit in the model's `INT_STATUS_REG`.
    *   If the corresponding bit in `INT_ENABLE_REG` (also part of the model) is set, assert the QEMU IRQ line connected to the PLIC.

### 2.4. Peripheral Models
*   **UART:** Use QEMU's existing `serial` device model (e.g., `TYPE_SERIAL_MM`). Map its registers to `0x0200_0000` + offsets.
*   **PLIC/CLINT:** Use QEMU's standard RISC-V PLIC and CLINT models.
*   **Timer:** If using a standard RISC-V timer (via CLINT), no separate model is needed. If custom, a simple model might be required.

### 2.5. Boot Process in QEMU
*   **U-Boot:**
    *   Compile U-Boot for the `kestrel-v-soc-machine`.
    *   Load U-Boot binary using QEMU's `-bios` option or as a general memory load if FSBL is part of the QEMU machine model.
*   **Kernel, DTB, Rootfs:**
    *   QEMU command line:
        *   `-kernel path/to/Image` (Linux kernel image)
        *   `-dtb path/to/kestrel_v_soc.dtb`
        *   `-initrd path/to/rootfs.cpio.gz` (for initramfs) or `-drive file=rootfs.ext4,format=raw,id=hd0 -device virtio-blk-device,drive=hd0` (for block device).
    *   U-Boot can also be configured to load these from memory addresses where QEMU has preloaded them (e.g., via `-device loader,...` options).

## 3. Software for PicoRV32 Nano-Controllers (uBPF Runtime)

This firmware runs on the PicoRV32 cores within each `eBPF_VM_Slot.v`.

### 3.1. Toolchain
*   Standard RISC-V GCC toolchain (e.g., `riscv64-unknown-elf-gcc` or a baremetal variant).
*   Target architecture: `rv32im` or `rv32imc` depending on PicoRV32 configuration (`NANO_CTRL_ENABLE_COMPRESSED`).
*   Compiler flags: `-march=rv32im[c] -mabi=ilp32 -Os -nostdlib -ffreestanding`.

### 3.2. uBPF Interpreter Porting
*   **Source:** Use a lightweight eBPF interpreter like `uBPF` (generic C version).
*   **Key Considerations:**
    *   **Memory Access:** Modify uBPF's memory access functions (`mem_load`, `mem_store`) to use PicoRV32's memory-mapped interface to access:
        *   eBPF Program Memory (`EBPF_PROG_MEM_BASE_ADDR`).
        *   eBPF Stack Memory (`EBPF_STACK_MEM_BASE_ADDR`).
        *   Mailbox regions (`EBPF_MAILBOX_IN_BASE_ADDR`, `EBPF_MAILBOX_OUT_BASE_ADDR`).
    *   **Division/Multiplication:** Ensure PicoRV32 configuration (`ENABLE_MUL`, `ENABLE_DIV`) matches the operations used by uBPF or provide software emulation for missing instructions if necessary (though `ENABLE_MUL` is set, `ENABLE_DIV` is currently off).
    *   **Alignment:** Handle potential unaligned accesses if eBPF programs might generate them and PicoRV32 doesn't support them directly (PicoRV32 typically traps on unaligned access if `ENABLE_MISALIGNED` is not set).
    *   **Stack Setup:** PicoRV32 will need its stack pointer initialized. The firmware will set this up.

### 3.3. Memory Layout
*   **PicoRV32 Local Instruction ROM (`nano_ctrl_instr_rom`):**
    *   The compiled uBPF interpreter binary (text, rodata sections) must fit within the 8KB ROM.
    *   Linker script (`.ld`) will be crucial to place code and data correctly, starting at `0x0000_0000`.
*   **PicoRV32 Local Data RAM (`nano_ctrl_data_ram`):**
    *   Used for PicoRV32's stack and any read/write data of the interpreter itself.
    *   Linker script will define stack location and `.data`/`.bss` sections.

### 3.4. Helper Function Implementation
eBPF programs can call "helper functions." These need to be implemented in the PicoRV32 firmware.
*   **Mailbox Access:**
    *   `bpf_mailbox_send(uint32_t mbox_idx, uint32_t data)`: Writes `data` to `EBPF_MAILBOX_OUT_BASE_ADDR + (mbox_idx * 4)`.
    *   `bpf_mailbox_recv(uint32_t mbox_idx)`: Reads from `EBPF_MAILBOX_IN_BASE_ADDR + (mbox_idx * 4)`.
*   **Status Reporting:**
    *   `bpf_vm_set_done()`: Writes `1` to the `done` flag bit in `ADDR_NANO_CTRL_STATUS_REG`.
    *   `bpf_vm_set_error(uint8_t err_code)`: Writes `1` to the `error` flag bit and potentially `err_code` to another part of the status register or a dedicated error code register.
*   **Other Helpers:** Any other standard or custom eBPF helpers needed (e.g., for accessing context data, if such a concept is introduced).

### 3.5. ROM Image Generation
1.  **Compile:** Compile the uBPF interpreter and helper functions using the RISC-V GCC toolchain.
2.  **Link:** Use a linker script to place code and data correctly for the PicoRV32's memory map (ROM at `0x0`, RAM at `0x2000`).
3.  **Convert to Binary:** `objcopy -O binary firmware.elf firmware.bin`.
4.  **Convert to Hex/Mem:**
    *   Use `xxd -p -c4 firmware.bin > firmware.hex` (or similar tool like `srec_cat`) to create a plain hex file.
    *   A script can then convert this hex file into a Verilog `$readmemh` compatible format, or directly into Verilog `initial begin ... end` statements for initializing the `nano_ctrl_instr_rom` array in `eBPF_VM_Slot.v`.

This plan provides a roadmap for both porting Linux to the SoC and creating a functional QEMU emulation environment, including the firmware for the PicoRV32 nano-controllers.Okay, I have created the `Linux_QEMU_Plan.md` document.

It details:

1.  **Linux Board Support Package (BSP) Development:**
    *   **Bootloader:** Covers requirements for a potential FSBL and the porting of U-Boot (configuration, drivers for UART/timer/memory, environment setup).
    *   **Linux Kernel:** Discusses base RISC-V configuration and focuses on the custom **Device Driver for Keystone Coprocessor**. This includes its userspace interface (char device, ioctls), how it will interact with the coprocessor's CSRs by memory-mapping them (simulating ISA "Y" effects rather than direct execution), interrupt handling, and memory management for eBPF programs/data. It also lists other necessary peripheral drivers (UART, Timer, PLIC).
    *   **Device Tree (DTB):** Outlines key components to describe (CPU, memory, Keystone Coprocessor, peripherals) reflecting `SoC_Memory_Map.txt`, including `compatible` strings.
    *   **Root Filesystem:** Briefly mentions Buildroot/Yocto choices and the need for eBPF testing tools.

2.  **QEMU Emulation Environment Setup:**
    *   **QEMU Machine Definition:** Steps for creating a new QEMU machine for the SoC.
    *   **CVA6 CPU Model with ISA "Y":** Approach for modifying QEMU's RISC-V CPU model to recognize `custom-0` opcodes and translate them into calls to the Keystone Coprocessor QEMU model, effectively simulating the "Y" instructions' behavior.
    *   **Keystone Coprocessor QEMU Model:** Details implementing its CSRs, behavioral modeling of DMA (direct memory access on host/QEMU memory), behavioral modeling of eBPF VM lifecycles (state changes, mailbox interaction without full PicoRV32 emulation), and interrupt simulation.
    *   **Peripheral Models:** Use of existing QEMU models for UART, PLIC, CLINT.
    *   **Boot Process in QEMU:** How U-Boot, kernel, DTB, and rootfs would be loaded.

3.  **Software for PicoRV32 Nano-Controllers (uBPF Runtime):**
    *   **Toolchain:** Specifies RISC-V GCC for `rv32im[c]`.
    *   **uBPF Interpreter Porting:** Key considerations like modifying memory access functions to use PicoRV32's memory map (local ROM/RAM, eBPF prog/stack, mailboxes, CSRs).
    *   **Memory Layout:** How the uBPF interpreter binary fits into PicoRV32's local instruction ROM and uses its data RAM.
    *   **Helper Function Implementation:** How eBPF helper functions (mailbox access, status reporting) will be implemented in the PicoRV32 firmware.
    *   **ROM Image Generation:** Process for converting compiled firmware into a Verilog-compatible memory initialization file (e.g., for `nano_ctrl_instr_rom`).

The document provides a comprehensive plan for these significant development and emulation efforts.
