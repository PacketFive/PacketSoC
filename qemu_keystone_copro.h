#ifndef QEMU_KEYSTONE_COPRO_H
#define QEMU_KEYSTONE_COPRO_H

#include "hw/sysbus.h"
#include "hw/hw.h"
#include "qom/object.h"
#include "exec/memory.h"

#define TYPE_KEYSTONE_COPRO "keystone-copro"
OBJECT_DECLARE_SIMPLE_TYPE(KeystoneCoproState, KEYSTONE_COPRO)

#define NUM_VM_SLOTS_QEMU 8
#define NUM_MAILBOX_REGS_QEMU 4

// Mirroring AXI_Lite_Memory_Map.txt offsets
#define ADDR_COPRO_CMD_REG                0x00
#define ADDR_VM_SELECT_REG                0x04
#define ADDR_COPRO_STATUS_REG             0x08
#define ADDR_PROG_ADDR_LOW_REG            0x0C
#define ADDR_PROG_ADDR_HIGH_REG           0x10
#define ADDR_DATA_IN_ADDR_LOW_REG         0x14
#define ADDR_DATA_IN_ADDR_HIGH_REG        0x18
#define ADDR_DATA_OUT_ADDR_LOW_REG        0x1C
#define ADDR_DATA_OUT_ADDR_HIGH_REG       0x20
#define ADDR_DATA_LEN_REG                 0x24
#define ADDR_INT_STATUS_REG               0x28
#define ADDR_INT_ENABLE_REG               0x2C
#define ADDR_SELECTED_VM_STATUS_REG       0x30
#define ADDR_SELECTED_VM_PC_REG           0x34
#define ADDR_SELECTED_VM_DATA_OUT_ADDR_REG 0x38
#define ADDR_MAILBOX_DATA_IN_0_REG        0x80
#define ADDR_MAILBOX_DATA_OUT_0_REG       0xA0
#define ADDR_COPRO_VERSION_REG            0xFC

#define KS_COPRO_CSR_SIZE                 0x100 // 256 bytes for CSRs

// COPRO_CMD_REG bits
#define CMD_START_VM        (1 << 0)
#define CMD_STOP_VM         (1 << 1)
#define CMD_RESET_VM        (1 << 2)
#define CMD_LOAD_PROG       (1 << 3)
#define CMD_LOAD_DATA_IN    (1 << 4)

// INT_STATUS_REG / INT_ENABLE_REG bits (example)
#define IRQ_VM0_DONE        (1 << 0)
// ... (VM1-7 DONE)
#define IRQ_VM7_DONE        (1 << 7)
#define IRQ_VM0_ERROR       (1 << 8)
// ... (VM1-7 ERROR)
#define IRQ_VM7_ERROR       (1 << 15)
#define IRQ_DMA_DONE        (1 << 16)
#define IRQ_DMA_ERROR       (1 << 17)


typedef struct KeystoneVMContext {
    bool running;
    bool error_state; // Generic error flag
    uint32_t error_code; // Specific error from VM
    uint32_t pc;         // Placeholder for VM's Program Counter
    // Add other VM-specific state if needed by the model
} KeystoneVMContext;

typedef struct KeystoneCoproState {
    /*< private >*/
    SysBusDevice parent_obj;

    /*< public >*/
    MemoryRegion iomem; // For AXI-Lite CSR interface
    qemu_irq irq;       // Interrupt output line

    // CSRs defined in AXI_Lite_Memory_Map.txt
    uint32_t copro_cmd_reg;
    uint32_t vm_select_id; // Only 3 bits used [2:0]
    // COPRO_STATUS_REG is composed of active_vm_mask and busy_status
    // uint32_t copro_status_reg; // Read-only by CPU
    uint32_t prog_addr_low_reg;
    uint32_t prog_addr_high_reg;
    uint32_t data_in_addr_low_reg;
    uint32_t data_in_addr_high_reg;
    uint32_t data_out_addr_low_reg;
    uint32_t data_out_addr_high_reg;
    uint32_t data_len_reg;
    uint32_t int_status_reg;
    uint32_t int_enable_reg;
    // SELECTED_VM_STATUS_REG, SELECTED_VM_PC_REG, SELECTED_VM_DATA_OUT_ADDR_REG are read-only,
    // their values are derived from vm_contexts and dma_target_vm_id for selected VM.

    // Mailbox storage for each VM
    uint32_t vm_mailboxes_in[NUM_VM_SLOTS_QEMU][NUM_MAILBOX_REGS_QEMU];  // CPU writes, VM reads
    uint32_t vm_mailboxes_out[NUM_VM_SLOTS_QEMU][NUM_MAILBOX_REGS_QEMU]; // VM writes, CPU reads

    // VM Contexts
    KeystoneVMContext vm_contexts[NUM_VM_SLOTS_QEMU];

    // Internal DMA state variables
    bool dma_active;
    uint64_t dma_src_addr; // Assuming system address can be 64-bit
    uint32_t dma_len;
    uint8_t dma_target_vm_id; // Which VM this DMA is for
    bool dma_is_prog_load;   // True if program load, false if data_in load
    // Potentially a QEMUTimer for DMA delay/completion
    QEMUTimer dma_timer;
    // Placeholder for data being DMA'd (e.g., to VM's program memory)
    // In a real model, this might interact with a representation of VM memory.
    uint8_t* dma_buffer; // Temporary buffer for DMA data

    // Derived status for COPRO_STATUS_REG
    bool copro_busy_status; // True if DMA active or any VM running
    uint8_t active_vm_mask; // Bitmask of running VMs

} KeystoneCoproState;

// Function declarations for memory-mapped I/O
uint64_t keystone_copro_read(void *opaque, hwaddr offset, unsigned size);
void keystone_copro_write(void *opaque, hwaddr offset, uint64_t val, unsigned size);

// Other function declarations can go here if needed for external interaction,
// but most will be static within the .c file.

#endif // QEMU_KEYSTONE_COPRO_H
