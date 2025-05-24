#include "qemu/osdep.h"
#include "qemu/log.h"
#include "qemu/timer.h"
#include "hw/sysbus.h"
#include "hw/hw.h" // For hwaddr
#include "migration/vmstate.h"
#include "qom/object.h"
#include "exec/address-spaces.h" // For cpu_physical_memory_read/write

#include "qemu_keystone_copro.h"

#define KS_COPRO_LOG(fmt, ...) \
    qemu_log_mask(LOG_GUEST_ERROR, "[%s] " fmt "\n", \
                  TYPE_KEYSTONE_COPRO, ## __VA_ARGS__)

// Forward declarations for static functions
static void ks_copro_update_irq(KeystoneCoproState *s);
static void ks_copro_handle_load_prog_cmd(KeystoneCoproState *s);
static void ks_copro_handle_load_data_in_cmd(KeystoneCoproState *s);
static void ks_copro_handle_start_vm_cmd(KeystoneCoproState *s);
static void ks_copro_handle_stop_vm_cmd(KeystoneCoproState *s);
static void ks_copro_handle_reset_vm_cmd(KeystoneCoproState *s);
static void ks_dma_complete_cb(void *opaque);


uint64_t keystone_copro_read(void *opaque, hwaddr offset, unsigned size) {
    KeystoneCoproState *s = KEYSTONE_COPRO(opaque);
    uint64_t val = 0;

    // KS_COPRO_LOG("CSR Read: offset=0x%02lx, size=%u", offset, size);

    switch (offset) {
        case ADDR_COPRO_CMD_REG:
            val = s->copro_cmd_reg; // SC bits are already cleared by write logic conceptually
            break;
        case ADDR_VM_SELECT_REG:
            val = s->vm_select_id;
            break;
        case ADDR_COPRO_STATUS_REG:
            // Reconstruct on read
            s->active_vm_mask = 0;
            for (int i = 0; i < NUM_VM_SLOTS_QEMU; i++) {
                if (s->vm_contexts[i].running) {
                    s->active_vm_mask |= (1 << i);
                }
            }
            s->copro_busy_status = s->dma_active || (s->active_vm_mask != 0);
            val = (s->active_vm_mask << 8) | (s->copro_busy_status & 0x1);
            break;
        case ADDR_PROG_ADDR_LOW_REG:
            val = s->prog_addr_low_reg;
            break;
        case ADDR_PROG_ADDR_HIGH_REG:
            val = s->prog_addr_high_reg;
            break;
        case ADDR_DATA_IN_ADDR_LOW_REG:
            val = s->data_in_addr_low_reg;
            break;
        case ADDR_DATA_IN_ADDR_HIGH_REG:
            val = s->data_in_addr_high_reg;
            break;
        case ADDR_DATA_OUT_ADDR_LOW_REG:
            val = s->data_out_addr_low_reg;
            break;
        case ADDR_DATA_OUT_ADDR_HIGH_REG:
            val = s->data_out_addr_high_reg;
            break;
        case ADDR_DATA_LEN_REG:
            val = s->data_len_reg;
            break;
        case ADDR_INT_STATUS_REG:
            val = s->int_status_reg;
            // RC behavior: reading clears the readable bits that were set
            // Assuming CPU reads the register and then writes back to clear specific bits.
            // True RC (clear on read) means after this read, bits should be cleared.
            // However, typical implementations require a write-to-clear for specific bits.
            // For now, we model W1C in the write function. If pure RC is needed:
            // s->int_status_reg = 0; // Or clear only bits that were read (val)
            // ks_copro_update_irq(s);
            break;
        case ADDR_INT_ENABLE_REG:
            val = s->int_enable_reg;
            break;
        case ADDR_SELECTED_VM_STATUS_REG:
            if (s->vm_select_id < NUM_VM_SLOTS_QEMU) {
                KeystoneVMContext *vm = &s->vm_contexts[s->vm_select_id];
                uint8_t status_byte = 0;
                if (vm->running) status_byte |= (1 << 1);
                if (vm->error_state) status_byte |= (1 << 3) | ((vm->error_code & 0xF) << 4);
                // Bit 2 (DONE) would be set by the VM model when it finishes.
                // Bit 0 (READY) can be assumed true if not running/error.
                if (!vm->running && !vm->error_state) status_byte |= (1 << 0);
                val = status_byte;
            } else {
                val = 0; // Or error value
            }
            break;
        case ADDR_SELECTED_VM_PC_REG:
             if (s->vm_select_id < NUM_VM_SLOTS_QEMU) {
                val = s->vm_contexts[s->vm_select_id].pc;
            } else {
                val = 0;
            }
            break;
        case ADDR_SELECTED_VM_DATA_OUT_ADDR_REG:
            // This would be an address in main memory where VM wrote output,
            // needs to be set by the VM model if it performs DMA itself.
            // For now, returns 0.
            val = 0;
            break;
        case ADDR_COPRO_VERSION_REG:
            val = 0x00010000; // Example Version 1.0.0
            break;
        default:
            if (offset >= ADDR_MAILBOX_DATA_IN_0_REG && offset < (ADDR_MAILBOX_DATA_IN_0_REG + NUM_MAILBOX_REGS_QEMU * 4)) {
                unsigned mbox_idx = (offset - ADDR_MAILBOX_DATA_IN_0_REG) / 4;
                if (s->vm_select_id < NUM_VM_SLOTS_QEMU && mbox_idx < NUM_MAILBOX_REGS_QEMU) {
                    val = s->vm_mailboxes_in[s->vm_select_id][mbox_idx];
                } else {
                    KS_COPRO_LOG("Read from invalid IN Mailbox: vm_id %u, idx %u", s->vm_select_id, mbox_idx);
                }
            } else if (offset >= ADDR_MAILBOX_DATA_OUT_0_REG && offset < (ADDR_MAILBOX_DATA_OUT_0_REG + NUM_MAILBOX_REGS_QEMU * 4)) {
                unsigned mbox_idx = (offset - ADDR_MAILBOX_DATA_OUT_0_REG) / 4;
                 if (s->vm_select_id < NUM_VM_SLOTS_QEMU && mbox_idx < NUM_MAILBOX_REGS_QEMU) {
                    val = s->vm_mailboxes_out[s->vm_select_id][mbox_idx];
                } else {
                    KS_COPRO_LOG("Read from invalid OUT Mailbox: vm_id %u, idx %u", s->vm_select_id, mbox_idx);
                }
            } else {
                KS_COPRO_LOG("Read from undefined CSR offset 0x%02lx", offset);
                // qemu_log_mask(LOG_GUEST_ERROR, ...) is preferred
            }
            break;
    }
    // KS_COPRO_LOG("Read value 0x%08x from offset 0x%02lx", (unsigned)val, offset);
    return val;
}

void keystone_copro_write(void *opaque, hwaddr offset, uint64_t val, unsigned size) {
    KeystoneCoproState *s = KEYSTONE_COPRO(opaque);
    uint32_t value = val; // Assuming 32-bit writes

    // KS_COPRO_LOG("CSR Write: offset=0x%02lx, value=0x%08x, size=%u", offset, value, size);

    switch (offset) {
        case ADDR_COPRO_CMD_REG:
            s->copro_cmd_reg = value; // Store written value
            if (value & CMD_LOAD_PROG) {
                ks_copro_handle_load_prog_cmd(s);
                s->copro_cmd_reg &= ~CMD_LOAD_PROG; // SC behavior
            }
            if (value & CMD_LOAD_DATA_IN) {
                ks_copro_handle_load_data_in_cmd(s);
                s->copro_cmd_reg &= ~CMD_LOAD_DATA_IN; // SC behavior
            }
            if (value & CMD_START_VM) {
                ks_copro_handle_start_vm_cmd(s);
                s->copro_cmd_reg &= ~CMD_START_VM; // SC behavior
            }
            if (value & CMD_STOP_VM) {
                ks_copro_handle_stop_vm_cmd(s);
                s->copro_cmd_reg &= ~CMD_STOP_VM; // SC behavior
            }
            if (value & CMD_RESET_VM) {
                ks_copro_handle_reset_vm_cmd(s);
                s->copro_cmd_reg &= ~CMD_RESET_VM; // SC behavior
            }
            // Other bits in command_reg are not SC and remain until changed.
            break;
        case ADDR_VM_SELECT_REG:
            s->vm_select_id = value & 0x7; // Only 3 bits for VM ID
            break;
        // COPRO_STATUS_REG is Read-Only
        case ADDR_PROG_ADDR_LOW_REG:
            s->prog_addr_low_reg = value;
            break;
        case ADDR_PROG_ADDR_HIGH_REG:
            s->prog_addr_high_reg = value;
            break;
        case ADDR_DATA_IN_ADDR_LOW_REG:
            s->data_in_addr_low_reg = value;
            break;
        case ADDR_DATA_IN_ADDR_HIGH_REG:
            s->data_in_addr_high_reg = value;
            break;
        case ADDR_DATA_OUT_ADDR_LOW_REG:
            s->data_out_addr_low_reg = value;
            break;
        case ADDR_DATA_OUT_ADDR_HIGH_REG:
            s->data_out_addr_high_reg = value;
            break;
        case ADDR_DATA_LEN_REG:
            s->data_len_reg = value;
            break;
        case ADDR_INT_STATUS_REG:
            // W1C (Write-1-to-Clear) behavior
            s->int_status_reg &= ~value;
            ks_copro_update_irq(s);
            break;
        case ADDR_INT_ENABLE_REG:
            s->int_enable_reg = value & 0x0003FFFF; // Mask to relevant 18 bits
            ks_copro_update_irq(s);
            break;
        // SELECTED_VM_* registers are Read-Only by CPU
        case ADDR_COPRO_VERSION_REG: // Read-Only
            break; 
        default:
            if (offset >= ADDR_MAILBOX_DATA_IN_0_REG && offset < (ADDR_MAILBOX_DATA_IN_0_REG + NUM_MAILBOX_REGS_QEMU * 4)) {
                unsigned mbox_idx = (offset - ADDR_MAILBOX_DATA_IN_0_REG) / 4;
                if (s->vm_select_id < NUM_VM_SLOTS_QEMU && mbox_idx < NUM_MAILBOX_REGS_QEMU) {
                    s->vm_mailboxes_in[s->vm_select_id][mbox_idx] = value;
                    KS_COPRO_LOG("CPU wrote 0x%x to VM%d IN Mailbox[%d]", value, s->vm_select_id, mbox_idx);
                    // TODO: Potentially signal to the VM model that new data is available in its IN mailbox.
                } else {
                    KS_COPRO_LOG("Write to invalid IN Mailbox: vm_id %u, idx %u", s->vm_select_id, mbox_idx);
                }
            } else if (offset >= ADDR_MAILBOX_DATA_OUT_0_REG && offset < (ADDR_MAILBOX_DATA_OUT_0_REG + NUM_MAILBOX_REGS_QEMU * 4)) {
                // CPU typically does not write to OUT mailboxes. This is where VM writes.
                KS_COPRO_LOG("CPU attempted write to OUT Mailbox offset 0x%02lx (ignored)", offset);
            } else {
                KS_COPRO_LOG("Write to undefined CSR offset 0x%02lx, value 0x%08x", offset, value);
            }
            break;
    }
}

static void ks_copro_update_irq(KeystoneCoproState *s) {
    bool irq_level = (s->int_status_reg & s->int_enable_reg) != 0;
    qemu_set_irq(s->irq, irq_level);
    // KS_COPRO_LOG("IRQ update: status=0x%x, enable=0x%x, level=%d", s->int_status_reg, s->int_enable_reg, irq_level);
}

static void ks_dma_complete_cb(void *opaque) {
    KeystoneCoproState *s = KEYSTONE_COPRO(opaque);
    KS_COPRO_LOG("DMA operation complete. Target VM: %d, Type: %s", 
                 s->dma_target_vm_id, s->dma_is_prog_load ? "PROG_LOAD" : "DATA_IN_LOAD");

    if (s->dma_active) { // Should always be true if timer fired for DMA
        // Simulate data transfer
        if (s->dma_buffer) {
            // In a real model, this buffer would be filled from guest memory
            // and then "written" to the conceptual VM program/data memory.
            // For now, we just log.
            KS_COPRO_LOG("DMA: conceptually transferred %u bytes from 0x%0lx", s->dma_len, s->dma_src_addr);
            // Example: If loading program, mark VM as having program loaded
            if (s->dma_is_prog_load && s->dma_target_vm_id < NUM_VM_SLOTS_QEMU) {
                // s->vm_contexts[s->dma_target_vm_id].has_program = true; // Add this field to KeystoneVMContext
                KS_COPRO_LOG("VM %d program memory conceptually loaded.", s->dma_target_vm_id);
            }
            g_free(s->dma_buffer);
            s->dma_buffer = NULL;
        }

        s->dma_active = false;
        s->int_status_reg |= IRQ_DMA_DONE; // Set DMA done interrupt
        ks_copro_update_irq(s);
    }
}


static void ks_copro_handle_load_prog_cmd(KeystoneCoproState *s) {
    if (s->dma_active) {
        KS_COPRO_LOG("DMA busy, LOAD_PROG for VM %u ignored.", s->vm_select_id);
        s->int_status_reg |= IRQ_DMA_ERROR; // Or some other error indication
        ks_copro_update_irq(s);
        return;
    }
    if (s->vm_select_id >= NUM_VM_SLOTS_QEMU) {
        KS_COPRO_LOG("LOAD_PROG: Invalid VM ID %u", s->vm_select_id);
        s->int_status_reg |= IRQ_DMA_ERROR; // Indicate error
        ks_copro_update_irq(s);
        return;
    }

    s->dma_active = true;
    s->dma_target_vm_id = s->vm_select_id;
    s->dma_src_addr = ((uint64_t)s->prog_addr_high_reg << 32) | s->prog_addr_low_reg;
    s->dma_len = s->data_len_reg;
    s->dma_is_prog_load = true;

    KS_COPRO_LOG("LOAD_PROG cmd: VM_ID=%u, Addr=0x%0lx, Len=%u",
                 s->dma_target_vm_id, s->dma_src_addr, s->dma_len);

    if (s->dma_len == 0) {
        KS_COPRO_LOG("LOAD_PROG: Zero length, completing immediately.");
        s->dma_active = false; // No actual DMA
        s->int_status_reg |= IRQ_DMA_DONE;
        ks_copro_update_irq(s);
        return;
    }
    
    // Simulate DMA by reading from guest memory
    // In a real QEMU model, you'd use AddressSpace and cpu_physical_memory_read
    // For this stub, we'll just log and simulate delay.
    s->dma_buffer = g_malloc(s->dma_len);
    // cpu_physical_memory_read(s->dma_src_addr, s->dma_buffer, s->dma_len);
    // KS_COPRO_LOG("DMA: Read %d bytes from guest RAM @ 0x%lx (simulated)", s->dma_len, s->dma_src_addr);
    
    // Simulate DMA delay
    timer_mod(&s->dma_timer, qemu_clock_get_ms(QEMU_CLOCK_VIRTUAL) + 1); // 1ms delay
}

static void ks_copro_handle_load_data_in_cmd(KeystoneCoproState *s) {
    if (s->dma_active) {
        KS_COPRO_LOG("DMA busy, LOAD_DATA_IN for VM %u ignored.", s->vm_select_id);
        s->int_status_reg |= IRQ_DMA_ERROR;
        ks_copro_update_irq(s);
        return;
    }
     if (s->vm_select_id >= NUM_VM_SLOTS_QEMU) {
        KS_COPRO_LOG("LOAD_DATA_IN: Invalid VM ID %u", s->vm_select_id);
        s->int_status_reg |= IRQ_DMA_ERROR; // Indicate error
        ks_copro_update_irq(s);
        return;
    }

    s->dma_active = true;
    s->dma_target_vm_id = s->vm_select_id;
    s->dma_src_addr = ((uint64_t)s->data_in_addr_high_reg << 32) | s->data_in_addr_low_reg;
    s->dma_len = s->data_len_reg;
    s->dma_is_prog_load = false;

    KS_COPRO_LOG("LOAD_DATA_IN cmd: VM_ID=%u, Addr=0x%0lx, Len=%u",
                 s->dma_target_vm_id, s->dma_src_addr, s->dma_len);
    
    // Simulate DMA (similar to LOAD_PROG)
    s->dma_buffer = g_malloc(s->dma_len);
    // cpu_physical_memory_read(s->dma_src_addr, s->dma_buffer, s->dma_len);
    // KS_COPRO_LOG("DMA: Read %d bytes for DATA_IN from guest RAM @ 0x%lx (simulated)", s->dma_len, s->dma_src_addr);

    timer_mod(&s->dma_timer, qemu_clock_get_ms(QEMU_CLOCK_VIRTUAL) + 1); // 1ms delay
}

static void ks_copro_handle_start_vm_cmd(KeystoneCoproState *s) {
    if (s->vm_select_id < NUM_VM_SLOTS_QEMU) {
        KeystoneVMContext *vm = &s->vm_contexts[s->vm_select_id];
        // TODO: Check if program is loaded before starting
        vm->running = true;
        vm->error_state = false;
        vm->error_code = 0;
        vm->pc = 0; // Reset PC on start
        KS_COPRO_LOG("START_VM cmd: VM_ID=%u", s->vm_select_id);
        // In a more complex model, this would trigger the PicoRV32 model to start execution.
        // For now, it just sets a flag. We can simulate VM completion via a timer or mailbox write.
    } else {
        KS_COPRO_LOG("START_VM cmd: Invalid VM_ID=%u", s->vm_select_id);
    }
    ks_copro_update_irq(s); // Update busy status
}

static void ks_copro_handle_stop_vm_cmd(KeystoneCoproState *s) {
    if (s->vm_select_id < NUM_VM_SLOTS_QEMU) {
        s->vm_contexts[s->vm_select_id].running = false;
        KS_COPRO_LOG("STOP_VM cmd: VM_ID=%u", s->vm_select_id);
        // This could also set a 'done' flag if stop implies completion.
        // s->int_status_reg |= (IRQ_VM0_DONE << s->vm_select_id);
    } else {
        KS_COPRO_LOG("STOP_VM cmd: Invalid VM_ID=%u", s->vm_select_id);
    }
    ks_copro_update_irq(s); // Update busy status
}

static void ks_copro_handle_reset_vm_cmd(KeystoneCoproState *s) {
    if (s->vm_select_id < NUM_VM_SLOTS_QEMU) {
        KeystoneVMContext *vm = &s->vm_contexts[s->vm_select_id];
        vm->running = false;
        vm->error_state = false;
        vm->error_code = 0;
        vm->pc = 0;
        // TODO: Clear VM's program memory, stack, mailboxes if applicable in a full model.
        KS_COPRO_LOG("RESET_VM cmd: VM_ID=%u", s->vm_select_id);
    } else {
        KS_COPRO_LOG("RESET_VM cmd: Invalid VM_ID=%u", s->vm_select_id);
    }
    ks_copro_update_irq(s); // Update busy status
}


static const MemoryRegionOps keystone_copro_ops = {
    .read = keystone_copro_read,
    .write = keystone_copro_write,
    .endianness = DEVICE_NATIVE_ENDIAN,
    .valid = {
        .min_access_size = 4,
        .max_access_size = 4,
    },
};

static void keystone_copro_reset(DeviceState *dev) {
    KeystoneCoproState *s = KEYSTONE_COPRO(dev);
    KS_COPRO_LOG("Resetting Keystone Coprocessor");

    s->copro_cmd_reg = 0;
    s->vm_select_id = 0;
    s->prog_addr_low_reg = 0;
    s->prog_addr_high_reg = 0;
    s->data_in_addr_low_reg = 0;
    s->data_in_addr_high_reg = 0;
    s->data_out_addr_low_reg = 0;
    s->data_out_addr_high_reg = 0;
    s->data_len_reg = 0;
    s->int_status_reg = 0;
    s->int_enable_reg = 0;

    s->dma_active = false;
    s->dma_src_addr = 0;
    s->dma_len = 0;
    s->dma_target_vm_id = 0;
    s->dma_is_prog_load = false;
    if (s->dma_buffer) {
        g_free(s->dma_buffer);
        s->dma_buffer = NULL;
    }
    timer_del(&s->dma_timer);


    for (int i = 0; i < NUM_VM_SLOTS_QEMU; i++) {
        s->vm_contexts[i].running = false;
        s->vm_contexts[i].error_state = false;
        s->vm_contexts[i].error_code = 0;
        s->vm_contexts[i].pc = 0;
        for (int j = 0; j < NUM_MAILBOX_REGS_QEMU; j++) {
            s->vm_mailboxes_in[i][j] = 0;
            s->vm_mailboxes_out[i][j] = 0;
        }
    }
    s->active_vm_mask = 0;
    s->copro_busy_status = false;
    ks_copro_update_irq(s);
}

static void keystone_copro_init(Object *obj) {
    KeystoneCoproState *s = KEYSTONE_COPRO(obj);

    KS_COPRO_LOG("Initializing Keystone Coprocessor device model");

    memory_region_init_io(&s->iomem, obj, &keystone_copro_ops, s,
                          TYPE_KEYSTONE_COPRO, KS_COPRO_CSR_SIZE);
    sysbus_init_mmio(SYS_BUS_DEVICE(obj), &s->iomem);

    qdev_init_gpio_out(DEVICE(obj), &s->irq, 1);

    timer_init_ms(&s->dma_timer, QEMU_CLOCK_VIRTUAL, ks_dma_complete_cb, s);

    // Initialize VM contexts (done in reset, but good practice)
    for (int i = 0; i < NUM_VM_SLOTS_QEMU; i++) {
        s->vm_contexts[i].running = false;
        s->vm_contexts[i].error_state = false;
         s->vm_contexts[i].error_code = 0;
        s->vm_contexts[i].pc = 0;
    }
    s->dma_buffer = NULL;
}

static const VMStateDescription vmstate_keystone_copro = {
    .name = TYPE_KEYSTONE_COPRO,
    .version_id = 1,
    .minimum_version_id = 1,
    .fields = (VMStateField[]) {
        VMSTATE_UINT32(copro_cmd_reg, KeystoneCoproState),
        VMSTATE_UINT32(vm_select_id, KeystoneCoproState),
        VMSTATE_UINT32(prog_addr_low_reg, KeystoneCoproState),
        VMSTATE_UINT32(prog_addr_high_reg, KeystoneCoproState),
        VMSTATE_UINT32(data_in_addr_low_reg, KeystoneCoproState),
        VMSTATE_UINT32(data_in_addr_high_reg, KeystoneCoproState),
        VMSTATE_UINT32(data_out_addr_low_reg, KeystoneCoproState),
        VMSTATE_UINT32(data_out_addr_high_reg, KeystoneCoproState),
        VMSTATE_UINT32(data_len_reg, KeystoneCoproState),
        VMSTATE_UINT32(int_status_reg, KeystoneCoproState),
        VMSTATE_UINT32(int_enable_reg, KeystoneCoproState),

        VMSTATE_PARTRAY_OF_UINT32(vm_mailboxes_in, KeystoneCoproState, NUM_VM_SLOTS_QEMU, NUM_MAILBOX_REGS_QEMU),
        VMSTATE_PARTRAY_OF_UINT32(vm_mailboxes_out, KeystoneCoproState, NUM_VM_SLOTS_QEMU, NUM_MAILBOX_REGS_QEMU),
        
        // KeystoneVMContext is simple enough to add directly, or use a sub-vmstate
        // For now, only saving 'running' and 'error_state' for simplicity. A full VM state would be more complex.
        // VMSTATE_STRUCT_ARRAY(vm_contexts, KeystoneCoproState, NUM_VM_SLOTS_QEMU, 1, vmstate_keystone_vm_context, KeystoneVMContext),

        VMSTATE_BOOL(dma_active, KeystoneCoproState),
        VMSTATE_UINT64(dma_src_addr, KeystoneCoproState),
        VMSTATE_UINT32(dma_len, KeystoneCoproState),
        VMSTATE_UINT8(dma_target_vm_id, KeystoneCoproState),
        VMSTATE_BOOL(dma_is_prog_load, KeystoneCoproState),
        VMSTATE_TIMER(dma_timer, KeystoneCoproState),

        VMSTATE_END_OF_LIST()
    }
};


static void keystone_copro_class_init(ObjectClass *klass, void *data) {
    DeviceClass *dc = DEVICE_CLASS(klass);
    dc->reset = keystone_copro_reset;
    dc->vmsd = &vmstate_keystone_copro;
    // dc->props = ...; // For QEMU properties if any
}

static const TypeInfo keystone_copro_info = {
    .name          = TYPE_KEYSTONE_COPRO,
    .parent        = TYPE_SYS_BUS_DEVICE,
    .instance_size = sizeof(KeystoneCoproState),
    .instance_init = keystone_copro_init,
    .class_init    = keystone_copro_class_init,
};

static void keystone_copro_register_types(void) {
    type_register_static(&keystone_copro_info);
}

type_init(keystone_copro_register_types)
