# CVA6 ISA Extension "Y" for Keystone Coprocessor Interaction

## 1. Introduction

This document outlines the modifications required to integrate a custom ISA extension, codenamed "Y", into the CVA6 RISC-V CPU core. This extension facilitates communication and control of an external Keystone Coprocessor, which is designed for eBPF virtual machine acceleration. The Keystone Coprocessor has an AXI4-Lite slave interface for control and status register (CSR) access, and the CVA6 CPU will use its AXI4 master interface to interact with it.

## 2. "Y" Instruction Set Definition and Encodings

The "Y" extension instructions will utilize one of the RISC-V custom opcodes. We select `custom-0` (opcode `0001011`). The specific instruction will be differentiated using `funct3` and `funct7` fields.

**Operands and Field Mapping:**

*   `rd`: Destination register. Used to store results from the coprocessor (e.g., status).
*   `rs1`: Source register 1. Typically used for `vm_idx` or data to be sent to the coprocessor.
*   `rs2`: Source register 2. Typically used for addresses or data to be sent to the coprocessor.
*   `vm_idx`: A 3-bit value (0-7) identifying the target eBPF VM slot in the coprocessor. This will often be sourced from the lower bits of `rs1`.
*   `imm`: Immediate values, if needed, could be encoded using the I-type or S-type formats, but for simplicity, we will primarily rely on register operands for addresses and data.

**Instruction Encodings Table:**

We will use a structure similar to R-type or I-type instructions. For instructions that primarily send commands or data, `rd` might not always be used for a result from the coprocessor itself but could store an immediate status (e.g., success/failure of initiating the AXI transaction).

| Instruction Mnemonic        | Opcode   | funct3 | funct7 / imm\[11:5] | rd  | rs1 (vm_idx/data) | rs2 (addr/data) | Description                                                                                                | Notes                                                                    |
| --------------------------- | -------- | ------ | ------------------- | --- | ----------------- | --------------- | ---------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------ |
| **VM Lifecycle & Control**  |          |        |                     |     |                   |                 |                                                                                                            |                                                                          |
| `BPF.VM.LOAD_PROG rd, rs1, rs2` | `0001011`| `000`  | `0000000`           | `rd`  | `rs1` (vm_idx)    | `rs2` (prog_addr) | Sets PROG_ADDR\_(LOW/HIGH) & DATA_LEN, then issues LOAD_PROG cmd. `rd` gets status.                      | `vm_idx` from `rs1[2:0]`. `prog_addr` from `rs2`. Assumes `DATA_LEN` pre-set or part of `rs1`. |
| `BPF.VM.START rd, rs1`      | `0001011`| `001`  | `0000000`           | `rd`  | `rs1` (vm_idx)    | *(unused)*      | Issues START_VM cmd for `vm_idx`. `rd` gets status.                                                        | `vm_idx` from `rs1[2:0]`.                                                  |
| `BPF.VM.STOP rd, rs1`       | `0001011`| `010`  | `0000000`           | `rd`  | `rs1` (vm_idx)    | *(unused)*      | Issues STOP_VM cmd for `vm_idx`. `rd` gets status.                                                         | `vm_idx` from `rs1[2:0]`.                                                  |
| `BPF.VM.RESET rd, rs1`      | `0001011`| `011`  | `0000000`           | `rd`  | `rs1` (vm_idx)    | *(unused)*      | Issues RESET_VM cmd for `vm_idx`. `rd` gets status.                                                        | `vm_idx` from `rs1[2:0]`.                                                  |
| **Status & Data Transfer**  |          |        |                     |     |                   |                 |                                                                                                            |                                                                          |
| `BPF.VM.STATUS rd, rs1`     | `0001011`| `100`  | `0000000`           | `rd`  | `rs1` (vm_idx)    | *(unused)*      | Selects `vm_idx`, reads SELECTED_VM_STATUS_REG into `rd`.                                                  | `vm_idx` from `rs1[2:0]`.                                                  |
| `BPF.VM.SEND rd, rs1, rs2`  | `0001011`| `101`  | `imm[11:5]` (mbox_idx)| `rd`  | `rs1` (vm_idx)    | `rs2` (data)    | Selects `vm_idx`, writes `rs2` to MAILBOX_DATA_IN_`imm`_REG. `rd` gets status.                          | `vm_idx` from `rs1[2:0]`. `mbox_idx` (0-3) from `imm[6:5]`.                |
| `BPF.VM.RECV rd, rs1, imm`  | `0001011`| `110`  | `imm[11:5]` (mbox_idx)| `rd`  | `rs1` (vm_idx)    | *(unused)*      | Selects `vm_idx`, reads MAILBOX_DATA_OUT_`imm`_REG into `rd`.                                              | `vm_idx` from `rs1[2:0]`. `mbox_idx` (0-3) from `imm[6:5]`.                |
| **Configuration**           |          |        |                     |     |                   |                 |                                                                                                            |                                                                          |
| `BPF.CONF.SETLEN rd, rs1, rs2`| `0001011`| `111`  | `0000000`           | `rd`  | `rs1` (vm_idx)    | `rs2` (length)  | Selects `vm_idx`, writes `rs2` to DATA_LEN_REG. `rd` gets status.                                      | `vm_idx` from `rs1[2:0]`.                                                  |

**Notes on Encodings:**

*   We are primarily using an R-type like structure where `funct7` and `funct3` distinguish instructions.
*   For `BPF.VM.SEND` and `BPF.VM.RECV`, the immediate field (bits 25-31 for `funct7` and 20-24 for `imm[4:0]` in I-type, or bits 25-31 for `funct7` and 7-11 for `imm[4:0]` in S-type) can be used to encode the mailbox index (`mbox_idx`). Let's assume an I-type like structure for these, where `imm[11:0]` is available. We only need 2 bits for `mbox_idx` (0-3 for `NUM_MAILBOX_REGS=4`). We can place `mbox_idx` in `imm[6:5]` or `imm[1:0]` of the standard I-type immediate field. For this example, let's use `imm[6:5]` for `mbox_idx`, so `funct7` becomes `imm[11:7]` and `imm[4:0]` remains `imm[4:0]`. The `funct7` column in the table reflects this by showing `imm[11:5]`.
*   The `vm_idx` is consistently taken from `rs1[2:0]`. The remaining bits of `rs1` could be used for other purposes if needed (e.g., specific flags for a command or upper bits of an address if `rs2` is insufficient).
*   `rd` gets an immediate status (0 for success, 1 for failure to initiate AXI) for command-like instructions. For read-like instructions (`BPF.VM.STATUS`, `BPF.VM.RECV`), `rd` receives the data from the coprocessor.

## 3. CVA6 Decoder Modification (`decoder.sv` or similar)

The CVA6 instruction decoder is typically found in the ID (Instruction Decode) stage. The primary task is to identify the `custom-0` opcode and then further decode based on `funct3` and `funct7`.

**Location of Changes:**

*   In CVA6, this would likely be in `ariane/src/decoder.sv` or a submodule it uses.
*   A new block of logic will be added to handle the `custom-0` opcode.

**Logic Description:**

1.  **Opcode Detection:**
    *   The main instruction decoding logic will have a case statement or series of `if-else if` conditions for opcodes. A new condition for `riscv::OpcodeCustom0` will be added.
    ```verilog
    // Example structure in decoder
    always_comb begin
        // ... default assignments ...
        unique case (instr_i[6:0]) // instr_i is the fetched instruction
            // ... other opcodes ...
            riscv::OpcodeCustom0: begin
                // Decode "Y" extension instructions
                is_y_instr = 1'b1; // Signal that it's a "Y" extension instruction
                unique case (instr_i[14:12]) // funct3
                    3'b000: begin // BPF.VM.LOAD_PROG
                        if (instr_i[31:25] == 7'b0000000) begin // funct7
                            is_bpf_load_prog_instr = 1'b1;
                            // Set other control signals: uses_rs1, uses_rs2, uses_rd, is_mem_op (for AXI)
                        end
                    end
                    3'b001: begin // BPF.VM.START
                        if (instr_i[31:25] == 7'b0000000) begin
                            is_bpf_start_instr = 1'b1;
                            // ...
                        end
                    end
                    // ... other funct3 cases for BPF.VM.STOP, BPF.VM.RESET ...
                    3'b100: begin // BPF.VM.STATUS
                        if (instr_i[31:25] == 7'b0000000) begin
                            is_bpf_status_instr = 1'b1;
                            // ... uses_rs1, uses_rd, is_mem_op (for AXI read) ...
                        end
                    end
                    3'b101: begin // BPF.VM.SEND (using imm for mbox_idx)
                        // funct7 is part of immediate, so only funct3 matters here for instruction type
                        is_bpf_send_instr = 1'b1;
                        // Decode mbox_idx from instr_i[26:25] (mapped from imm[6:5])
                        // ... uses_rs1, uses_rs2, uses_rd, is_mem_op (for AXI write) ...
                    end
                    3'b110: begin // BPF.VM.RECV (using imm for mbox_idx)
                        is_bpf_recv_instr = 1'b1;
                        // Decode mbox_idx from instr_i[26:25]
                        // ... uses_rs1, uses_rd, is_mem_op (for AXI read) ...
                    end
                    3'b111: begin // BPF.CONF.SETLEN
                         if (instr_i[31:25] == 7'b0000000) begin
                            is_bpf_conflen_instr = 1'b1;
                            // ...
                        end
                    end
                    default: begin
                        // Illegal "Y" instruction based on funct3
                        is_illegal_instr = 1'b1;
                    end
                endcase
            end
            // ... other opcodes ...
            default: is_illegal_instr = 1'b1;
        endcase
    end
    ```

**Generated Control Signals:**

The decoder will generate a set of control signals that are passed down the pipeline. For each "Y" instruction, specific signals would be asserted:

*   `is_y_instr`: General flag indicating a "Y" extension instruction.
*   `is_bpf_load_prog_instr`: For `BPF.VM.LOAD_PROG`.
*   `is_bpf_start_instr`: For `BPF.VM.START`.
*   `is_bpf_stop_instr`: For `BPF.VM.STOP`.
*   `is_bpf_reset_instr`: For `BPF.VM.RESET`.
*   `is_bpf_status_instr`: For `BPF.VM.STATUS`.
*   `is_bpf_send_instr`: For `BPF.VM.SEND`.
*   `is_bpf_recv_instr`: For `BPF.VM.RECV`.
*   `is_bpf_conflen_instr`: For `BPF.CONF.SETLEN`.
*   `y_instr_vm_idx`: A 3-bit signal extracted from `rs1[2:0]`.
*   `y_instr_mbox_idx`: A 2-bit signal extracted from `instr_i[26:25]` for SEND/RECV.
*   Standard signals like `uses_rs1`, `uses_rs2`, `uses_rd`, `is_mem_op` (repurposed for AXI transactions), `is_load_op`, `is_store_op` would also be set appropriately. For "Y" instructions, `is_mem_op` would indicate an AXI transaction is required. `is_load_op` for reads from coprocessor, `is_store_op` for writes.

These signals are then latched and passed to the subsequent pipeline stages.

## 4. CVA6 Execution/Memory Stage Modification

The Execute (EX) and Memory (MEM) stages will use the control signals from the ID stage to perform the AXI Lite transactions to the Keystone Coprocessor. CVA6's existing LSU (Load/Store Unit) or a similar AXI interface unit will be leveraged.

**Location of Changes:**

*   Likely in `ariane/src/execute_stage.sv` and `ariane/src/load_store_unit.sv` (or its equivalent for AXI transactions).
*   A new state machine or extended logic within the LSU might be needed to handle multi-cycle AXI operations and sequences of AXI transactions for a single "Y" instruction.

**Logic Description:**

1.  **Control Signal Usage:**
    *   The `is_y_instr` flag and specific `is_bpf_..._instr` flags will gate the "Y" instruction logic.
    *   `y_instr_vm_idx` will be used to set the `VM_SELECT_REG` in the coprocessor.
    *   `y_instr_mbox_idx` will be used for mailbox addressing.

2.  **Data and Address Preparation:**
    *   **Source Operands:** `rs1_data` and `rs2_data` are read from the register file in the ID stage and are available in EX.
    *   **AXI Address:** The base address of the Keystone Coprocessor (SoC-dependent) will be the starting point. Offsets from `AXI_Lite_Memory_Map.txt` will be added to target specific registers.
        *   Example: `COPRO_BASE_ADDR + ADDR_VM_SELECT_REG`.
    *   **AXI Write Data:** For writes, data comes from `rs1_data` or `rs2_data` as per the instruction.

3.  **AXI Lite Transaction Initiation:**
    *   A state machine within the EX/MEM stage (or LSU) will manage the sequence of AXI transactions for instructions requiring multiple steps (e.g., `BPF.VM.LOAD_PROG`).
    *   **AXI Write:**
        *   The LSU's AXI master interface will be used.
        *   `AWADDR` is set to the target coprocessor register address.
        *   `AWVALID` is asserted.
        *   Once `AWREADY` is high, `WDATA` is driven with the data, and `WVALID` is asserted.
        *   Wait for `BVALID` (and check `BRESP`).
    *   **AXI Read:**
        *   `ARADDR` is set.
        *   `ARVALID` is asserted.
        *   Wait for `ARREADY`.
        *   Once `RVALID` is high, `RDATA` is captured. `RRESP` is checked.

4.  **Write-Back to `rd`:**
    *   For instructions like `BPF.VM.STATUS` or `BPF.VM.RECV`, the data read from the coprocessor (`RDATA`) is written back to the destination register `rd` in the Write-Back (WB) stage.
    *   For command instructions, `rd` might receive an immediate status (0 for success, 1 for AXI error). This can be generated within the EX/MEM stage.

**Conceptual Verilog/Pseudo-code for `BPF.VM.LOAD_PROG rd, rs1_vm_idx, rs2_prog_addr`:**

This instruction requires multiple AXI writes:
1.  Write `vm_idx` (from `rs1[2:0]`) to `VM_SELECT_REG`.
2.  Write `prog_addr` (from `rs2`) to `PROG_ADDR_LOW_REG` (assuming 32-bit address for now).
3.  (Optionally write to `DATA_LEN_REG` if `BPF.CONF.SETLEN` wasn't used prior).
4.  Write `LOAD_PROG` command (bit 3 = 1) to `COPRO_CMD_REG`.
5.  (Optional) Read `COPRO_STATUS_REG` or `SELECTED_VM_STATUS_REG` into `rd`.

```verilog
// In execute_stage.sv or a dedicated "Y" instruction handler module
// State machine for "Y" instruction execution
localparam Y_IDLE = 0, 
           Y_LOADPROG_SEL_VM = 1, Y_LOADPROG_WR_ADDR = 2, Y_LOADPROG_WR_CMD = 3, 
           Y_LOADPROG_RD_STATUS = 4, Y_LOADPROG_DONE = 5;
reg [2:0] y_state_r;

// Assume these signals are available from ID/EX pipeline registers
logic is_bpf_load_prog_instr_ex;
logic [2:0] vm_idx_ex;         // From rs1[2:0]
logic [31:0] prog_addr_ex;     // From rs2_data
logic [4:0] rd_addr_ex;        // Destination register address

// AXI Master Interface signals (simplified)
logic axi_awvalid_o;
logic [31:0] axi_awaddr_o;
logic axi_wvalid_o;
logic [31:0] axi_wdata_o;
logic axi_bready_o;
logic axi_arvalid_o;
logic [31:0] axi_araddr_o;
logic axi_rready_o;

input axi_awready_i, axi_wready_i, axi_bvalid_i, axi_arready_i, axi_rvalid_i;
input [31:0] axi_rdata_i;
input [1:0] axi_bresp_i, axi_rresp_i;

// Temporary register for result
logic [31:0] result_for_rd_w;
logic write_back_en_w;

always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        y_state_r <= Y_IDLE;
        // Reset AXI signals
        axi_awvalid_o <= 1'b0;
        axi_wvalid_o  <= 1'b0;
        axi_bready_o  <= 1'b0;
        axi_arvalid_o <= 1'b0;
        axi_rready_o  <= 1'b0;
        write_back_en_w <= 1'b0;
    end else begin
        write_back_en_w <= 1'b0; // Default
        axi_awvalid_o <= 1'b0;   // Default
        axi_wvalid_o  <= 1'b0;   // Default
        axi_arvalid_o <= 1'b0;   // Default
        axi_rready_o <= 1'b0;    // Default for most states

        case (y_state_r)
            Y_IDLE: begin
                if (is_bpf_load_prog_instr_ex && !pipeline_stall_i) begin // pipeline_stall_i from CVA6 control
                    y_state_r <= Y_LOADPROG_SEL_VM;
                end
            end

            Y_LOADPROG_SEL_VM: begin // 1. Write VM_SELECT_REG
                axi_awaddr_o <= COPRO_BASE_ADDR + ADDR_VM_SELECT_REG;
                axi_wdata_o  <= {29'b0, vm_idx_ex};
                axi_awvalid_o <= 1'b1;
                axi_wvalid_o  <= 1'b1; 
                if (axi_awvalid_o && axi_awready_i && axi_wvalid_o && axi_wready_i) begin
                    // Both address and data accepted by AXI slave in same cycle (common for AXI-Lite)
                    axi_awvalid_o <= 1'b0; // De-assert for next cycle
                    axi_wvalid_o  <= 1'b0;
                    axi_bready_o  <= 1'b1; // Ready to accept response
                    y_state_r     <= Y_LOADPROG_WR_ADDR;
                end else if (axi_awvalid_o && axi_awready_i) { // Address accepted, wait for data phase
                    axi_awvalid_o <= 1'b0; 
                    // WVALID stays high or goes high when data is ready
                } else if (axi_wvalid_o && axi_wready_i) { // Data accepted after address, less common for simple AXI-Lite master
                    axi_wvalid_o <= 1'b0;
                }
                // Need to handle BVALID response before moving on if strictly following AXI write
                // Simplified: assume BVALID comes quickly or use another state for BVALID.
            end
            
            // Simplified BVALID handling (assuming it completes before next action)
            // More robust FSM would have explicit states for AW->W->B phases.

            Y_LOADPROG_WR_ADDR: begin // 2. Write PROG_ADDR_LOW_REG
                // Wait for BVALID from previous write to complete if necessary.
                // For simplicity, assume previous write completed.
                axi_bready_o <= 1'b0; // De-assert from previous state

                axi_awaddr_o <= COPRO_BASE_ADDR + ADDR_PROG_ADDR_LOW_REG;
                axi_wdata_o  <= prog_addr_ex;
                axi_awvalid_o <= 1'b1;
                axi_wvalid_o  <= 1'b1;
                if (axi_awvalid_o && axi_awready_i && axi_wvalid_o && axi_wready_i) begin
                    axi_awvalid_o <= 1'b0;
                    axi_wvalid_o  <= 1'b0;
                    axi_bready_o  <= 1'b1;
                    y_state_r     <= Y_LOADPROG_WR_CMD;
                end
            end

            Y_LOADPROG_WR_CMD: begin // 3. Write COPRO_CMD_REG
                axi_bready_o <= 1'b0;

                axi_awaddr_o <= COPRO_BASE_ADDR + ADDR_COPRO_CMD_REG;
                axi_wdata_o  <= 32'h00000008; // LOAD_PROG command (bit 3)
                axi_awvalid_o <= 1'b1;
                axi_wvalid_o  <= 1'b1;
                if (axi_awvalid_o && axi_awready_i && axi_wvalid_o && axi_wready_i) begin
                    axi_awvalid_o <= 1'b0;
                    axi_wvalid_o  <= 1'b0;
                    axi_bready_o  <= 1'b1;
                    // Optionally read status, or just be done
                    result_for_rd_w <= 32'b0; // Indicate success to CPU's rd
                    write_back_en_w <= 1'b1;
                    y_state_r     <= Y_LOADPROG_DONE; 
                end
            end
            
            // Y_LOADPROG_RD_STATUS: (Optional status read state)
            // ... similar logic for ARVALID, ARREADY, RVALID, RREADY ...
            // result_for_rd_w <= axi_rdata_i;
            // write_back_en_w <= 1'b1;
            // y_state_r <= Y_LOADPROG_DONE;

            Y_LOADPROG_DONE: begin
                axi_bready_o <= 1'b0;
                // Instruction finished, signal to pipeline control
                // CVA6 uses 'is_completed_instr_o' or similar
                // For now, just go to IDLE
                y_state_r <= Y_IDLE;
            end
            default: y_state_r <= Y_IDLE;
        endcase
        
        // If y_state_r != Y_IDLE, assert pipeline stall to CVA6 core
        // pipeline_stall_o = (y_state_r != Y_IDLE); 
    end
end
```

**Handling Multi-Cycle Operations and Pipeline Stalls:**

*   **Pipeline Stall:** As shown in the pseudo-code, when a "Y" instruction is executing and requires multiple cycles for AXI transactions, the `y_state_r` will not be `Y_IDLE`. This condition should be used to assert a pipeline stall signal to the CVA6 core. This will prevent subsequent instructions from entering the EX stage until the "Y" instruction completes. CVA6 has mechanisms for this (e.g., `busy_o` from LSU, or a specific stall signal from EX stage).
*   **AXI Transaction States:** A more robust AXI FSM would explicitly manage `AWVALID`/`AWREADY`, then `WVALID`/`WREADY`, then `BVALID`/`BREADY` for writes, and `ARVALID`/`ARREADY`, then `RVALID`/`RREADY` for reads. Each of these handshakes can take one or more cycles. The simplified pseudo-code above assumes AXI-Lite where some handshakes might complete in the same cycle if the slave is fast.
*   **State Machine:** The `y_state_r` FSM manages the sequence of operations for a single "Y" instruction. For example, `BPF.VM.LOAD_PROG` involves selecting the VM, writing the program address, and then issuing the command. Each step is a state in the FSM.
*   **AXI Timeouts:** A production-quality design should include AXI timeout mechanisms to prevent locking up the CPU if the coprocessor becomes unresponsive.

## 5. Keystone Coprocessor Base Address

The CVA6 CPU will need to know the base address of the Keystone Coprocessor in the system's memory map. This base address (`COPRO_BASE_ADDR` in the pseudo-code) will be a constant provided during synthesis or configured via a control register in CVA6 if it's dynamically mapped (less likely for this type of coprocessor). All AXI transactions will be relative to this base address.

## 6. Conclusion

Integrating the "Y" ISA extension into CVA6 involves defining new instruction encodings under a custom opcode, modifying the decoder to recognize these instructions and generate appropriate control signals, and enhancing the execution/memory stages to manage AXI Lite transactions with the Keystone Coprocessor. A state machine within the execution stage will be crucial for handling multi-step "Y" instructions and managing pipeline stalls during AXI communication. This allows the CVA6 CPU to effectively control and utilize the eBPF acceleration capabilities of the Keystone Coprocessor.
