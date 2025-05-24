# PicoRV32 uBPF Interpreter Firmware Plan

## 0. Document Purpose

This document outlines the plan for developing the firmware for the PicoRV32 nano-controller, which will execute an eBPF interpreter (based on `uBPF`) within each `eBPF_VM_Slot` of the Keystone Coprocessor.

## 1. Toolchain Requirements

*   **Compiler:** RISC-V GCC toolchain.
    *   Example: `riscv64-unknown-elf-gcc` (if building on a 64-bit host for a 32-bit target, the toolchain typically supports `march=rv32...`). Alternatively, a dedicated `riscv32-unknown-elf-gcc` or similar.
*   **Target Architecture:** `rv32imc` (since `NANO_CTRL_ENABLE_COMPRESSED=1` and `NANO_CTRL_ENABLE_MUL=1` are set for PicoRV32 in `eBPF_VM_Slot.v`).
*   **Compilation Flags (Example):**
    ```bash
    CFLAGS = -march=rv32imc -mabi=ilp32 -Os \
             -ffreestanding -nostdlib \
             -Wall -Wextra -g \
             -DPICO_MEM_MAP_BASE_ROM=0x00000000 \
             -DPICO_MEM_MAP_BASE_RAM=0x00002000 \
             -DEBPF_PROG_MEM_BASE_ADDR=0x01000000 \
             -DEBPF_STACK_MEM_BASE_ADDR=0x02000000 \
             -DADDR_NANO_CTRL_STATUS_REG=0x00003000 \
             -DEBPF_MAILBOX_IN_BASE_ADDR=0x00003010 \
             -DEBPF_MAILBOX_OUT_BASE_ADDR=0x00003030 \
             -DNUM_MAILBOX_REGS_VM=4
    LDFLAGS = -T pico_firmware.ld -nostdlib --gc-sections
    ```
    (Memory map addresses are passed as defines for C code access).

## 2. uBPF Interpreter Adaptation for PicoRV32

The generic C `uBPF` interpreter (or a similar lightweight interpreter) will be adapted.

### 2.1. Key uBPF Functions for Memory Access Modification

The core of the adaptation involves how uBPF accesses memory for eBPF instruction fetching, data operations (stack, context, globals), and helper function interactions.

*   **eBPF Instruction Fetch:**
    *   `uBPF` typically has a main execution loop that fetches instructions sequentially.
    *   The program counter (PC) for eBPF will be an index into the eBPF program memory.
    *   The function responsible for fetching the next eBPF instruction (e.g., `ubpf_fetch_instruction(vm)`) will need to:
        *   Calculate the actual memory address: `pico_addr = EBPF_PROG_MEM_BASE_ADDR + (ebpf_pc * sizeof(struct ebpf_inst));`
        *   Read the 64-bit eBPF instruction from this address. Since PicoRV32 is 32-bit, this will involve two 32-bit reads:
            ```c
            // Example inside uBPF adaptation layer
            struct ebpf_inst inst;
            uint32_t* inst_ptr = (uint32_t*)(EBPF_PROG_MEM_BASE_ADDR + (vm->pc * 8)); // 8 bytes per eBPF instruction
            inst.opcode = *inst_ptr;         // Read first 32 bits
            inst.regs_dst_src = *(inst_ptr + 1); // Read next 32 bits (example, fields depend on uBPF struct)
            // ... and so on for other parts of the instruction struct.
            // Or, more simply:
            // uint64_t raw_inst_val = ((uint64_t)(*(inst_ptr + 1)) << 32) | (*inst_ptr);
            ```
*   **eBPF Stack Access:**
    *   eBPF programs have a stack. The uBPF VM state usually includes a stack pointer (`SP`).
    *   Memory access instructions in eBPF (e.g., `LDXDW`, `STXDW`, `LDXW`, `STXW`, etc., relative to `SP`) will be handled by functions like `ubpf_load_register(vm, dst_reg, src_reg, offset)` or `ubpf_store_memory(vm, dst_reg, offset, value)`.
    *   These functions must translate the eBPF stack address (`SP + offset`) to a PicoRV32 memory address:
        `pico_stack_addr = EBPF_STACK_MEM_BASE_ADDR + (ebpf_sp_val + offset_val);`
    *   Then perform 32-bit or 64-bit reads/writes at `pico_stack_addr` (again, two 32-bit accesses for 64-bit operations).
        ```c
        // Example for writing a 32-bit value to eBPF stack
        uint32_t* p_stack = (uint32_t*)(EBPF_STACK_MEM_BASE_ADDR + effective_ebpf_stack_address);
        *p_stack = value_to_write;
        ```
*   **Access to eBPF Context Data (if applicable):**
    *   eBPF programs often operate on a "context" (e.g., network packet data). The location of this context data needs to be defined (e.g., passed via an IN Mailbox or a pre-defined memory region).
    *   uBPF functions accessing this context will need to use the appropriate base address.

### 2.2. Implementation Strategy for eBPF Helper Functions

Helper functions are called by eBPF programs. These will be implemented as C functions in the PicoRV32 firmware.

*   **Mailbox Send/Receive:**
    *   `int bpf_mailbox_send(uint32_t mbox_idx, uint64_t data_val)`:
        *   Check `mbox_idx < NUM_MAILBOX_REGS_VM`.
        *   Calculate address: `volatile uint32_t* mbox_addr = (volatile uint32_t*)(EBPF_MAILBOX_OUT_BASE_ADDR + (mbox_idx * 4));`
        *   Write data (potentially two 32-bit writes for `data_val` if it's 64-bit, or handle as two separate 32-bit mailbox registers per 64-bit word):
            ```c
            *(mbox_addr)     = (uint32_t)(data_val & 0xFFFFFFFF);
            // If mailbox entries are 32-bit and data_val is 64-bit, this needs to be handled carefully.
            // The current hardware design assumes 32-bit mailbox words.
            // So, a 64-bit value might need two separate mailbox_send calls or be truncated/split.
            // For now, assume data_val is 32-bit or lower 32-bits are used.
            ```
        *   The hardware `vm_mailbox_out_wen_o` is pulsed automatically by the PicoRV32 memory write to this region.
    *   `int bpf_mailbox_recv(uint32_t mbox_idx, uint64_t* data_val_ptr)`:
        *   Check `mbox_idx < NUM_MAILBOX_REGS_VM`.
        *   Calculate address: `volatile uint32_t* mbox_addr = (volatile uint32_t*)(EBPF_MAILBOX_IN_BASE_ADDR + (mbox_idx * 4));`
        *   Read data:
            ```c
            // Assuming 32-bit mailbox words
            if (data_val_ptr) {
                *data_val_ptr = (uint64_t)(*mbox_addr); // Read one 32-bit word
            }
            ```
*   **Status Reporting:**
    *   `void bpf_vm_set_done(void)`:
        *   `volatile uint32_t* status_reg = (volatile uint32_t*)ADDR_NANO_CTRL_STATUS_REG;`
        *   `*status_reg = (*status_reg & ~0x1) | 0x1; // Set bit 0 (done)`
    *   `void bpf_vm_set_error(uint8_t err_code)`:
        *   `volatile uint32_t* status_reg = (volatile uint32_t*)ADDR_NANO_CTRL_STATUS_REG;`
        *   `uint32_t current_val = *status_reg;`
        *   `current_val |= (1 << 1); // Set bit 1 (error)`
        *   `current_val = (current_val & ~0xF0) | ((err_code & 0xF) << 4); // Set error code in bits [7:4]`
        *   `*status_reg = current_val;`
*   **Registration of Helpers:** uBPF requires helper functions to be registered with it, usually via an array of function pointers and their corresponding eBPF helper IDs.

## 3. PicoRV32 Startup Code (`crt0.S` and C)

*   **`crt0.S` (Assembly Startup):**
    1.  Disable interrupts (PicoRV32 `mie` register, though interrupts are not used yet).
    2.  Initialize stack pointer (`sp`): Load `sp` with `NANO_CTRL_STACKADDR_TOP` (top of PicoRV32 Data RAM).
    3.  (Optional) Initialize `gp` (global pointer) if using certain ABI features, though often not needed for simple baremetal.
    4.  Clear BSS section: Loop through the BSS region (defined by linker script symbols `_bss_start` and `_bss_end`) and write zeros.
    5.  (Optional) Initialize .data section: If `.data` is in RAM and needs to be copied from ROM (less common for small embedded systems where `.data` might be directly in ROM or initialized by C).
    6.  Call C `main()` function.
    7.  After `main()` returns (if it ever does), enter an infinite loop (`wfi` or `j .`).
*   **C Startup / `main()` function:**
    1.  Perform any necessary C runtime initialization (minimal for nostdlib).
    2.  Initialize uBPF VM structure.
    3.  Load eBPF program:
        *   The eBPF program bytecode is already in `prog_mem` (loaded by CCU DMA).
        *   The uBPF VM needs to be configured with the pointer to this memory (`EBPF_PROG_MEM_BASE_ADDR`) and program length (potentially read from a mailbox or a CSR if CCU sets it).
    4.  Register helper functions with uBPF.
    5.  (Optional) Prepare context data for the eBPF program (e.g., read from IN Mailbox).
    6.  Execute the eBPF program using `ubpf_exec(vm, context, context_len)`.
    7.  After execution, read the result from uBPF (e.g., R0 register).
    8.  Report status (done/error) and potentially result via `ADDR_NANO_CTRL_STATUS_REG` or OUT Mailbox.
    9.  Loop or halt.

## 4. Linker Script (`.ld`) Outline

A custom linker script is required to place code and data into the PicoRV32's specific memory layout.

```ld
OUTPUT_ARCH(riscv)
ENTRY(_start) /* Entry point defined in crt0.S */

MEMORY
{
  ROM (rx)  : ORIGIN = 0x00000000, LENGTH = 8K  /* NANO_CTRL_ROM_BASE, NANO_CTRL_ROM_SIZE_BYTES */
  RAM (rwx) : ORIGIN = 0x00002000, LENGTH = 4K  /* NANO_CTRL_RAM_BASE, NANO_CTRL_RAM_SIZE_BYTES */
}

SECTIONS
{
  .text : {
    KEEP(*(.init))  /* Startup code */
    KEEP(*(.vector_table)) /* Placeholder for future interrupt vectors if any */
    *(.text .text.*)
    *(.rodata .rodata.*)
    . = ALIGN(4);
    _etext = .;
  } > ROM

  .data : {
    . = ALIGN(4);
    _sdata = .;
    *(.data .data.*)
    . = ALIGN(4);
    _edata = .;
  } > RAM AT > ROM /* Initialize .data in RAM from ROM if needed, or place directly in ROM if read-only */
                 /* For simple baremetal, often .data is minimal or readonly and part of .rodata */

  .bss : {
    . = ALIGN(4);
    _sbss = .;
    *(.bss .bss.*)
    *(COMMON)
    . = ALIGN(4);
    _ebss = .;
  } > RAM

  /* Stack grows downwards from top of RAM */
  _stack_start = ORIGIN(RAM) + LENGTH(RAM);
}
```
*   `_start`: Entry point, defined in `crt0.S`.
*   `.text`: Code and read-only data, placed in ROM.
*   `.data`: Initialized read-write data. If placed in RAM, it needs to be copied from ROM by startup code, or initialized by the C code.
*   `.bss`: Uninitialized read-write data, zeroed by startup code, placed in RAM.
*   `_stack_start`: Defines the initial stack pointer value (top of RAM).

## 5. ROM Image Generation Steps

1.  **Compile C/Assembly Files:**
    `riscvXX-unknown-elf-gcc $(CFLAGS) -c file1.c -o file1.o`
    `riscvXX-unknown-elf-as $(ASFLAGS) crt0.S -o crt0.o`
2.  **Link:**
    `riscvXX-unknown-elf-gcc $(LDFLAGS) crt0.o file1.o ... -o firmware.elf`
3.  **Convert to Binary (Optional but good for size check):**
    `riscvXX-unknown-elf-objcopy -O binary firmware.elf firmware.bin`
4.  **Convert to Verilog Hex Memory File:**
    *   Using `objcopy` to output Verilog hex:
        `riscvXX-unknown-elf-objcopy -O verilog firmware.elf nano_ctrl_instr_rom_temp.mem`
    *   **Post-process `nano_ctrl_instr_rom_temp.mem`:**
        *   The output of `objcopy -O verilog` might not be directly suitable for `$readmemh` if it includes address tags (`@address`).
        *   A script (Python, awk, sed) will be needed to:
            1.  Remove address tags if present.
            2.  Ensure each line has one 32-bit word in hexadecimal.
            3.  Pad the file with zeros or a known instruction (e.g., NOP = `00000013`) up to `NANO_CTRL_ROM_WORDS_32BIT` if the firmware is smaller than the ROM size.
            4.  The final output should be `nano_ctrl_instr_rom.mem`.

    *   **Alternative using `srec_cat` or custom script:**
        `srec_cat firmware.elf -binary -offset 0x00000000 -fill 0x00 0x00000000 NANO_CTRL_ROM_SIZE_BYTES -o nano_ctrl_instr_rom.hex -Intel` (or other hex format)
        Then convert this hex format to plain word-per-line hex for `$readmemh`.

This plan provides a roadmap for developing the uBPF interpreter firmware for the PicoRV32 nano-controllers.Okay, I have created the `PicoRV32_uBPF_Firmware_Plan.md` document.

Now, I will create the placeholder PicoRV32 ROM image file `nano_ctrl_instr_rom_placeholder.mem`.

This will be a very simple program:
1.  Load an immediate value (address of `ADDR_NANO_CTRL_STATUS_REG`) into a register (e.g., `a0`).
2.  Load an immediate value `0x00000001` (done bit set) into another register (e.g., `a1`).
3.  Store the value from `a1` to the address in `a0`.
4.  Loop indefinitely.

Target Address for Status Register: `0x00003000` (from `ADDR_NANO_CTRL_STATUS_REG` in `eBPF_VM_Slot.v`)
Value to write: `0x00000001` (sets bit 0 - `done_reg_r`)

**Assembly (Conceptual):**

```assembly
_start:
    // Load address of ADDR_NANO_CTRL_STATUS_REG (0x00003000) into a0
    // lui a0, %hi(0x00003000)   // lui a0, 0x00003 (generates 00003537)
    // addi a0, a0, %lo(0x00003000) // addi a0, a0, 0 (0000) (generates 00050513)
    // Corrected for direct address loading if possible, or split if > 12-bit immediate for addi
    // For 0x00003000:
    lui a0, 0x3                // a0 = 0x00003000 (RV32: 00003537)
    // No addi needed if lower 12 bits are 0

    // Load value 0x00000001 into a1
    addi a1, zero, 1           // a1 = 1 (RV32: 00100593)

    // Store a1 to memory address in a0
    sw a1, 0(a0)               // mem[a0] = a1 (RV32: 00b52023)

loop:
    j loop                     // RV32: 0000006F
```

**Hex Machine Code (RV32I):**

1.  `lui a0, 0x3` (`rd=a0=x10`, `imm=0x00003`): `00003537`
2.  `addi a1, zero, 1` (`rd=a1=x11`, `rs1=zero=x0`, `imm=1`): `00100593`
3.  `sw a1, 0(a0)` (`rs2=a1=x11`, `base=a0=x10`, `offset=0`): `00b52023`
4.  `j loop` (actually `jal zero, 0` relative to current PC): `0000006F`

This is a 4-instruction program (16 bytes).
