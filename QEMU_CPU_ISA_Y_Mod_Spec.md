# QEMU RISC-V CPU Model Modification Specification for ISA Extension "Y"

## 0. Document Purpose

This document specifies the modifications required for QEMU's RISC-V CPU model to decode and translate the custom ISA Extension "Y" instructions. These instructions are designed for interaction with the Keystone Coprocessor QEMU model.

## 1. QEMU Instruction Definition Format Overview

QEMU's RISC-V instruction set is typically extended by:

1.  **Defining Instruction Patterns:** In files like `target/riscv/insn_trans.h` (older QEMU) or by adding entries to instruction pattern tables used by the TCG (Tiny Code Generator) frontend for RISC-V. These patterns consist of a bitmask and a required value that uniquely identifies the instruction.
2.  **Mapping Patterns to Translator Functions:** Each pattern is associated with a C function (often a "helper" function) that implements the instruction's behavior. When the CPU fetches an instruction that matches a pattern, the corresponding translator function is called.
3.  **Implementing Translator Functions:** These C functions, typically in `target/riscv/insn_trans.c` or a new C file for custom extensions, receive CPU state (`CPURISCVState *env`) and decoded operands (e.g., register indices, immediate values) as arguments. They manipulate the CPU state (GPRs, PC) and interact with other QEMU components (like device models) to emulate the instruction.

For ISA Extension "Y", all instructions use the `custom-0` opcode (`0001011`). They are further differentiated by `funct3` and `funct7` fields, similar to R-type or I-type instructions.

## 2. "Y" Instruction Decoder Entries and Helper Function Mapping

The following table details the bit patterns and corresponding C helper functions for each "Y" instruction. The `custom-0` opcode is `0001011`.

**Instruction Format Recap (R-Type like for most):**
`| funct7 (31:25) | rs2 (24:20) | rs1 (19:15) | funct3 (14:12) | rd (11:7) | opcode (6:0) |`

**Instruction Patterns and Helpers:**

1.  **`BPF.VM.LOAD_PROG rd, rs1, rs2`**
    *   Opcode: `0001011` (`OPC_CUSTOM_0`)
    *   funct3: `000`
    *   funct7: `0000000`
    *   **QEMU Pattern:**
        *   Mask:  `0xFE00707F` (Match `funct7`, `funct3`, `opcode`)
        *   Value: `0x0000000B` (`funct7=0, funct3=0, opcode=custom-0`)
    *   **Helper Function:** `void helper_bpf_vm_load_prog(CPURISCVState *env, DisasContext *ctx, uint32_t rd_idx, uint32_t rs1_val, uint32_t rs2_val);`
        *   `rd_idx`: Decoded `rd` register index.
        *   `rs1_val`: Value from GPR specified by `rs1`.
        *   `rs2_val`: Value from GPR specified by `rs2`.
        *   `ctx` provides access to PC and other context.

2.  **`BPF.VM.START rd, rs1`**
    *   Opcode: `0001011`
    *   funct3: `001`
    *   funct7: `0000000`
    *   **QEMU Pattern:**
        *   Mask:  `0xFE00707F`
        *   Value: `0x0000100B` (`funct7=0, funct3=1, opcode=custom-0`)
    *   **Helper Function:** `void helper_bpf_vm_start(CPURISCVState *env, DisasContext *ctx, uint32_t rd_idx, uint32_t rs1_val);`

3.  **`BPF.VM.STOP rd, rs1`**
    *   Opcode: `0001011`
    *   funct3: `010`
    *   funct7: `0000000`
    *   **QEMU Pattern:**
        *   Mask:  `0xFE00707F`
        *   Value: `0x0000200B` (`funct7=0, funct3=2, opcode=custom-0`)
    *   **Helper Function:** `void helper_bpf_vm_stop(CPURISCVState *env, DisasContext *ctx, uint32_t rd_idx, uint32_t rs1_val);`

4.  **`BPF.VM.RESET rd, rs1`**
    *   Opcode: `0001011`
    *   funct3: `011`
    *   funct7: `0000000`
    *   **QEMU Pattern:**
        *   Mask:  `0xFE00707F`
        *   Value: `0x0000300B` (`funct7=0, funct3=3, opcode=custom-0`)
    *   **Helper Function:** `void helper_bpf_vm_reset(CPURISCVState *env, DisasContext *ctx, uint32_t rd_idx, uint32_t rs1_val);`

5.  **`BPF.VM.STATUS rd, rs1`**
    *   Opcode: `0001011`
    *   funct3: `100`
    *   funct7: `0000000`
    *   **QEMU Pattern:**
        *   Mask:  `0xFE00707F`
        *   Value: `0x0000400B` (`funct7=0, funct3=4, opcode=custom-0`)
    *   **Helper Function:** `void helper_bpf_vm_status(CPURISCVState *env, DisasContext *ctx, uint32_t rd_idx, uint32_t rs1_val);`

6.  **`BPF.VM.SEND rd, rs1, rs2`** (Mailbox index from `imm[6:5]` of I-type like encoding)
    *   Opcode: `0001011`
    *   funct3: `101`
    *   Instruction bits `[26:25]` will contain `mbox_idx`.
    *   **QEMU Pattern:**
        *   Mask:  `0x0000707F` (Match `funct3`, `opcode`; `funct7` part (`imm[11:5]`) is variable)
        *   Value: `0x0000500B` (`funct3=5, opcode=custom-0`)
    *   **Helper Function:** `void helper_bpf_vm_send(CPURISCVState *env, DisasContext *ctx, uint32_t rd_idx, uint32_t rs1_val, uint32_t rs2_val, uint32_t mbox_idx);`
        *   `mbox_idx` will be extracted by the decoder from `ctx->insn` bits `[26:25]` (or as per QEMU's immediate extraction for custom formats).

7.  **`BPF.VM.RECV rd, rs1, imm`** (Mailbox index from `imm[6:5]` of I-type like encoding)
    *   Opcode: `0001011`
    *   funct3: `110`
    *   Instruction bits `[26:25]` will contain `mbox_idx`.
    *   **QEMU Pattern:**
        *   Mask:  `0x0000707F`
        *   Value: `0x0000600B` (`funct3=6, opcode=custom-0`)
    *   **Helper Function:** `void helper_bpf_vm_recv(CPURISCVState *env, DisasContext *ctx, uint32_t rd_idx, uint32_t rs1_val, uint32_t mbox_idx);`
        *   `mbox_idx` extracted from `ctx->insn` bits `[26:25]`.

8.  **`BPF.CONF.SETLEN rd, rs1, rs2`**
    *   Opcode: `0001011`
    *   funct3: `111`
    *   funct7: `0000000`
    *   **QEMU Pattern:**
        *   Mask:  `0xFE00707F`
        *   Value: `0x0000700B` (`funct7=0, funct3=7, opcode=custom-0`)
    *   **Helper Function:** `void helper_bpf_conf_setlen(CPURISCVState *env, DisasContext *ctx, uint32_t rd_idx, uint32_t rs1_val, uint32_t rs2_val);`

**Note on `DisasContext *ctx`:** This structure typically provides access to the raw instruction (`ctx->insn`), the PC (`ctx->pc`), and other decoding context. QEMU's operand extraction mechanism might pass register values directly or their indices. Helper signatures should align with how QEMU's translation pipeline passes these. For simplicity, `rsX_val` is used here, implying values are already fetched. If only indices are passed, GPR access `env->gpr[rsX_idx]` would be needed within the helper.

## 3. C Helper Function Specifications

All helper functions will need to:
1.  Locate the `KeystoneCoproState` device model instance. This can be done using QEMU's device model APIs, typically by finding the device by its path or type if a global pointer isn't easily available. A common approach is to have a global or per-CPU pointer to critical devices initialized during machine setup.
2.  Interact with the `KeystoneCoproState` model by calling its C functions (e.g., `keystone_copro_csr_write`, `keystone_copro_csr_read`, or more abstract functions like `keystone_copro_start_vm_cmd`).
3.  Update the guest CPU's GPRs (`env->gpr[rd_idx] = result;`) if `rd_idx != 0`.
4.  QEMU's TCG frontend usually handles PC advancement after the helper function returns.

**Base Address for Keystone Coprocessor CSRs:** `0x1000_0000` (from `SoC_Memory_Map.txt`).
The `KeystoneCoproState* s;` variable in pseudo-code refers to the pointer to the coprocessor model instance.

---

**1. `helper_bpf_vm_load_prog(CPURISCVState *env, DisasContext *ctx, uint32_t rd_idx, uint32_t rs1_val, uint32_t rs2_val)`**
*   **Behavior:**
    1.  `vm_idx = rs1_val & 0x7;`
    2.  `prog_addr = rs2_val;`
    3.  `len_val = /* Read from DATA_LEN_REG via CSR read or assume pre-set. For simplicity, assume pre-set or another instruction handles it. */`
    4.  `// keystone_copro_csr_write(s, ADDR_VM_SELECT_REG, vm_idx);`
    5.  `// keystone_copro_csr_write(s, ADDR_PROG_ADDR_LOW_REG, prog_addr);`
    6.  `// keystone_copro_csr_write(s, ADDR_DATA_LEN_REG, len_val); // If len comes from another reg or is implicit`
    7.  `// keystone_copro_csr_write(s, ADDR_COPRO_CMD_REG, CMD_LOAD_PROG);`
    8.  Simulate the sequence of CSR writes to the Keystone Coprocessor model:
        *   Write `vm_idx` to `VM_SELECT_REG` (`0x04`).
        *   Write `prog_addr` to `PROG_ADDR_LOW_REG` (`0x0C`). (Assume `PROG_ADDR_HIGH_REG` is 0 or handled separately if needed).
        *   Write `CMD_LOAD_PROG` (bit 3) to `COPRO_CMD_REG` (`0x00`).
    9.  `status = 0; // Placeholder for actual status (e.g., from a read-back or copro model)`
    10. `if (rd_idx != 0) env->gpr[rd_idx] = status;`

---

**2. `helper_bpf_vm_start(CPURISCVState *env, DisasContext *ctx, uint32_t rd_idx, uint32_t rs1_val)`**
*   **Behavior:**
    1.  `vm_idx = rs1_val & 0x7;`
    2.  Simulate CSR writes:
        *   Write `vm_idx` to `VM_SELECT_REG` (`0x04`).
        *   Write `CMD_START_VM` (bit 0) to `COPRO_CMD_REG` (`0x00`).
    3.  `status = 0; // Placeholder`
    4.  `if (rd_idx != 0) env->gpr[rd_idx] = status;`

---

**3. `helper_bpf_vm_stop(CPURISCVState *env, DisasContext *ctx, uint32_t rd_idx, uint32_t rs1_val)`**
*   **Behavior:**
    1.  `vm_idx = rs1_val & 0x7;`
    2.  Simulate CSR writes:
        *   Write `vm_idx` to `VM_SELECT_REG` (`0x04`).
        *   Write `CMD_STOP_VM` (bit 1) to `COPRO_CMD_REG` (`0x00`).
    3.  `status = 0; // Placeholder`
    4.  `if (rd_idx != 0) env->gpr[rd_idx] = status;`

---

**4. `helper_bpf_vm_reset(CPURISCVState *env, DisasContext *ctx, uint32_t rd_idx, uint32_t rs1_val)`**
*   **Behavior:**
    1.  `vm_idx = rs1_val & 0x7;`
    2.  Simulate CSR writes:
        *   Write `vm_idx` to `VM_SELECT_REG` (`0x04`).
        *   Write `CMD_RESET_VM` (bit 2) to `COPRO_CMD_REG` (`0x00`).
    3.  `status = 0; // Placeholder`
    4.  `if (rd_idx != 0) env->gpr[rd_idx] = status;`

---

**5. `helper_bpf_vm_status(CPURISCVState *env, DisasContext *ctx, uint32_t rd_idx, uint32_t rs1_val)`**
*   **Behavior:**
    1.  `vm_idx = rs1_val & 0x7;`
    2.  Simulate CSR writes/reads:
        *   Write `vm_idx` to `VM_SELECT_REG` (`0x04`).
        *   `result = /* keystone_copro_csr_read(s, ADDR_SELECTED_VM_STATUS_REG (0x30)) */;`
    3.  `if (rd_idx != 0) env->gpr[rd_idx] = result;`

---

**6. `helper_bpf_vm_send(CPURISCVState *env, DisasContext *ctx, uint32_t rd_idx, uint32_t rs1_val, uint32_t rs2_val, uint32_t mbox_idx)`**
    *   `mbox_idx` is extracted from instruction bits `[26:25]` by the decoder.
*   **Behavior:**
    1.  `vm_idx = rs1_val & 0x7;`
    2.  `data_to_send = rs2_val;`
    3.  `mailbox_offset = ADDR_MAILBOX_DATA_IN_0_REG + (mbox_idx * 4);`
    4.  Simulate CSR writes:
        *   Write `vm_idx` to `VM_SELECT_REG` (`0x04`).
        *   `// keystone_copro_csr_write(s, mailbox_offset, data_to_send);`
    5.  `status = 0; // Placeholder`
    6.  `if (rd_idx != 0) env->gpr[rd_idx] = status;`

---

**7. `helper_bpf_vm_recv(CPURISCVState *env, DisasContext *ctx, uint32_t rd_idx, uint32_t rs1_val, uint32_t mbox_idx)`**
    *   `mbox_idx` is extracted from instruction bits `[26:25]` by the decoder.
*   **Behavior:**
    1.  `vm_idx = rs1_val & 0x7;`
    2.  `mailbox_offset = ADDR_MAILBOX_DATA_OUT_0_REG + (mbox_idx * 4);`
    3.  Simulate CSR writes/reads:
        *   Write `vm_idx` to `VM_SELECT_REG` (`0x04`).
        *   `result = /* keystone_copro_csr_read(s, mailbox_offset) */;`
    4.  `if (rd_idx != 0) env->gpr[rd_idx] = result;`

---

**8. `helper_bpf_conf_setlen(CPURISCVState *env, DisasContext *ctx, uint32_t rd_idx, uint32_t rs1_val, uint32_t rs2_val)`**
*   **Behavior:**
    1.  `vm_idx = rs1_val & 0x7;` // Though DATA_LEN_REG is not per-VM in current map, vm_select might be used for future per-VM DATA_LEN.
    2.  `length_val = rs2_val;`
    3.  Simulate CSR writes:
        *   `// keystone_copro_csr_write(s, ADDR_VM_SELECT_REG, vm_idx); // If DATA_LEN becomes per-VM`
        *   `// keystone_copro_csr_write(s, ADDR_DATA_LEN_REG (0x24), length_val);`
    4.  `status = 0; // Placeholder`
    5.  `if (rd_idx != 0) env->gpr[rd_idx] = status;`

---

**Interaction with Keystone Coprocessor Model (`KeystoneCoproState *s`):**

Each helper function will need to obtain a pointer to the `KeystoneCoproState` instance. This is typically done by finding the device instance within QEMU's device tree or via a global handle. Once `s` is obtained:

*   Writes to CSRs can be done via: `keystone_copro_write(s, CSR_OFFSET, value, size);`
*   Reads from CSRs can be done via: `value = keystone_copro_read(s, CSR_OFFSET, size);`

These `keystone_copro_write/read` functions are already defined in the `qemu_keystone_copro.c` model and will update the internal state of the coprocessor model (including triggering DMA or VM state changes as per their logic).

This specification provides the necessary information to integrate ISA Extension "Y" into QEMU's RISC-V CPU model, enabling software simulation and testing of programs utilizing this extension.
