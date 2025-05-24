#include "qemu/osdep.h"
#include "qemu/error-report.h"
#include "hw/riscv/riscv.h"       // For RISC-V CPU stuff
#include "hw/riscv/htif.h"        // If using HTIF console (less likely for full SoC)
#include "hw/char/serial.h"       // For serial UART
#include "hw/intc/riscv_plic.h"   // For PLIC
#include "hw/timer/riscv_clint.h" // For CLINT
#include "sysemu/sysemu.h"
#include "sysemu/qtest.h"         // If needed for testing
#include "hw/boards.h"
#include "exec/address-spaces.h"
#include "qemu/log.h"

// Custom Keystone Coprocessor header
#include "qemu_keystone_copro.h" // Assumes this file is in a path QEMU can find

#define TYPE_KEYSTONE_SOC_MACHINE "keystone-soc"
OBJECT_DECLARE_SIMPLE_TYPE(KeystoneSoCMachineState, KEYSTONE_SOC_MACHINE)

// Memory Map Constants (must align with SoC_Memory_Map.txt and device models)
// These should ideally be defined in a shared header or derived from DT
#define MAIN_MEM_BASE_ADDR_QEMU         0x80000000UL
// #define BOOT_ROM_BASE_ADDR_QEMU      0x00010000UL // If CVA6 boot vector is here
// #define BOOT_ROM_SIZE_QEMU           (64 * 1024)
#define KEYSTONE_COPRO_CSR_BASE_ADDR_QEMU 0x10000000UL
#define PERIPHERALS_BASE_ADDR_QEMU      0x02000000UL // Base for generic peripherals
#define UART_MM_OFFSET_QEMU             0x0000 // UART within peripheral region
#define UART_BASE_ADDR_QEMU             (PERIPHERALS_BASE_ADDR_QEMU + UART_MM_OFFSET_QEMU)
#define PLIC_BASE_ADDR_QEMU             0x0C000000UL // Common PLIC base
#define CLINT_BASE_ADDR_QEMU            0x02000000UL // Common CLINT base (Note: This overlaps with PERIPHERALS_BASE_ADDR_QEMU in this example, adjust as needed)
                                                  // Often CLINT is 0x02000000 - 0x0200BFFF, PLIC 0x0C000000 - 0x0FFFFFFF

// Interrupt Numbers for PLIC
// These are the "sources" for the PLIC.
#define UART0_IRQ_NUM_QEMU              1  // Example PLIC source ID for UART
#define KEYSTONE_COPRO_IRQ_NUM_QEMU     2  // Example PLIC source ID for Keystone Copro

// Default CVA6 CPU type with "Y" extension (to be defined in QEMU CPU model)
#define DEFAULT_CPU_TYPE RISCV_CPU_TYPE_NAME("rv64gcsu-cva6-y")

struct KeystoneSoCMachineState {
    /*< private >*/
    MachineState parent_obj;

    /*< public >*/
    RISCVCPU *cpu;
    DeviceState *plic;
    DeviceState *clint;
    DeviceState *keystone_copro;
    DeviceState *uart0;

    MemoryRegion ram;
    // MemoryRegion boot_rom; // If explicitly loading a ROM file for CVA6 boot
};

static void keystone_soc_init(MachineState *machine) {
    KeystoneSoCMachineState *s = KEYSTONE_SOC_MACHINE(machine);
    MemoryRegion *system_memory = get_system_memory();
    Error *errp = NULL; // For error reporting

    qemu_log_mask(LOG_TRACE, "[%s] Initializing machine\n", machine->type_name);

    // 1. Setup Memory (DRAM)
    if (machine->ram_size == 0) {
        // This case might occur if ram_size is not set by QEMU command line
        // or if there's an issue with default_ram_size in MachineClass.
        // Set a default if it's zero, or error out.
        qemu_log_mask(LOG_WARNING, "[%s] RAM size is 0, defaulting to 1GiB\n", machine->type_name);
        machine->ram_size = 1 * GiB;
    }
    memory_region_allocate_system_memory(&s->ram, OBJECT(machine), "keystone_soc.ram",
                                         machine->ram_size);
    memory_region_add_subregion(system_memory, MAIN_MEM_BASE_ADDR_QEMU, &s->ram);
    qemu_log_mask(LOG_TRACE, "[%s] RAM allocated at 0x%08lx, size %" PRId64 " MiB\n",
                  machine->type_name, MAIN_MEM_BASE_ADDR_QEMU, machine->ram_size / MiB);


    // 2. Create CPU
    if (machine->cpu_type == NULL) {
        machine->cpu_type = DEFAULT_CPU_TYPE;
        qemu_log_mask(LOG_TRACE, "[%s] CPU type not specified, using default: %s\n",
                      machine->type_name, machine->cpu_type);
    }
    s->cpu = cpu_riscv_init(machine->cpu_type);
    if (s->cpu == NULL) {
        error_setg(&errp, "Unable to initialize CPU %s", machine->cpu_type);
        goto error_out;
    }
    // Configure CPU features (MISA, priv spec)
    // Example: RV64GC + Supervisor mode. The "Y" extension would be part of the CPU type.
    // This is often handled by the CPU model itself based on its type string.
    // For explicit MISA setting if needed:
    // riscv_cpu_set_priv_spec(s->cpu, PRIV_SPEC_VERSION_1_11);
    // uint64_t misa = riscv_cpu_misa_from_str(s->cpu, "rv64gcsu"); // Check if "Y" needs to be in MISA string
    // riscv_cpu_set_misa(s->cpu, misa);
    qemu_log_mask(LOG_TRACE, "[%s] CPU initialized: %s\n", machine->type_name, machine->cpu_type);


    // 3. PLIC (Platform-Level Interrupt Controller)
    s->plic = qdev_new(TYPE_RISCV_PLIC);
    // Define number of sources, priority levels, etc.
    // qdev_prop_set_uint32(DEVICE(s->plic), "num_sources", NUM_PLIC_SOURCES_QEMU);
    // qdev_prop_set_uint32(DEVICE(s->plic), "num_priorities", NUM_PLIC_PRIORITIES_QEMU);
    sysbus_realize_and_unref(SYS_BUS_DEVICE(s->plic), &errp);
    if (errp) goto error_out;
    sysbus_mmio_map(SYS_BUS_DEVICE(s->plic), 0, PLIC_BASE_ADDR_QEMU);
    qdev_connect_gpio_out(DEVICE(s->plic), 0, s->cpu->env.irq[IRQ_S_EXT]); // Connect PLIC output to CPU S-mode EXT IRQ
    // Or IRQ_M_EXT if CPU runs in M-mode primarily for kernel
    qemu_log_mask(LOG_TRACE, "[%s] PLIC initialized at 0x%08lx\n", machine->type_name, PLIC_BASE_ADDR_QEMU);


    // 4. CLINT (Core Local Interruptor)
    s->clint = qdev_new(TYPE_RISCV_CLINT);
    // qdev_prop_set_uint32(DEVICE(s->clint), "num_harts", 1); // Assuming 1 hart for now
    sysbus_realize_and_unref(SYS_BUS_DEVICE(s->clint), &errp);
    if (errp) goto error_out;
    sysbus_mmio_map(SYS_BUS_DEVICE(s->clint), 0, CLINT_BASE_ADDR_QEMU);
    qdev_connect_gpio_out_named(DEVICE(s->clint), "mtip", 0, s->cpu->env.irq[IRQ_S_TIMER]); // S-mode timer
    qdev_connect_gpio_out_named(DEVICE(s->clint), "msip", 0, s->cpu->env.irq[IRQ_S_SOFT]);  // S-mode software
    // Or M-mode: IRQ_M_TIMER, IRQ_M_SOFT
    qemu_log_mask(LOG_TRACE, "[%s] CLINT initialized at 0x%08lx\n", machine->type_name, CLINT_BASE_ADDR_QEMU);


    // 5. Keystone Coprocessor Device
    s->keystone_copro = qdev_new(TYPE_KEYSTONE_COPRO);
    sysbus_realize_and_unref(SYS_BUS_DEVICE(s->keystone_copro), &errp);
    if (errp) goto error_out;
    sysbus_mmio_map(SYS_BUS_DEVICE(s->keystone_copro), 0, KEYSTONE_COPRO_CSR_BASE_ADDR_QEMU);
    qdev_connect_gpio_out(DEVICE(s->keystone_copro), 0, qdev_get_gpio_in(DEVICE(s->plic), KEYSTONE_COPRO_IRQ_NUM_QEMU));
    qemu_log_mask(LOG_TRACE, "[%s] Keystone Coprocessor initialized at 0x%08lx, IRQ connected to PLIC source %d\n",
                  machine->type_name, KEYSTONE_COPRO_CSR_BASE_ADDR_QEMU, KEYSTONE_COPRO_IRQ_NUM_QEMU);


    // 6. UART (Serial Port)
    s->uart0 = qdev_new(TYPE_SERIAL_MM);
    if (serial_hd(0)) { // Check if a host serial backend is available (e.g., -serial stdio)
        qdev_prop_set_chr(DEVICE(s->uart0), "chardev", serial_hd(0));
    } else {
        qemu_log_mask(LOG_WARNING, "[%s] No host serial backend for UART0, console may not be visible.\n", machine->type_name);
    }
    sysbus_realize_and_unref(SYS_BUS_DEVICE(s->uart0), &errp);
    if (errp) goto error_out;
    sysbus_mmio_map(SYS_BUS_DEVICE(s->uart0), 0, UART_BASE_ADDR_QEMU);
    qdev_connect_gpio_out(DEVICE(s->uart0), 0, qdev_get_gpio_in(DEVICE(s->plic), UART0_IRQ_NUM_QEMU));
    qemu_log_mask(LOG_TRACE, "[%s] UART0 initialized at 0x%08lx, IRQ connected to PLIC source %d\n",
                  machine->type_name, UART_BASE_ADDR_QEMU, UART0_IRQ_NUM_QEMU);


    // 7. Boot ROM (Optional - if not using QEMU -bios or equivalent direct kernel load)
    // If using a boot ROM that CVA6 fetches from:
    // memory_region_init_rom(&s->boot_rom, OBJECT(machine), "keystone_soc.bootrom",
    //                        BOOT_ROM_SIZE_QEMU, &errp);
    // if (errp) goto error_out;
    // rom_add_file_fixed(machine->kernel_filename ? machine->kernel_filename : "bootrom.bin", // Or a fixed name
    //                    &s->boot_rom, BOOT_ROM_SIZE_QEMU, CPU_ADDRESS_SPACE(s->cpu), &errp);
    // if (errp) goto error_out;
    // memory_region_add_subregion(system_memory, BOOT_ROM_BASE_ADDR_QEMU, &s->boot_rom);
    // qemu_log_mask(LOG_TRACE, "[%s] Boot ROM mapped at 0x%08lx\n", machine->type_name, BOOT_ROM_BASE_ADDR_QEMU);


    // 8. Provide reset vector / boot address to CPU
    // This depends on the CVA6 model's reset behavior.
    // Typically, the CPU model has a default reset vector.
    // If it needs to be overridden by the machine:
    // s->cpu->env.pc = BOOT_ROM_BASE_ADDR_QEMU; // Or wherever U-Boot/kernel is loaded by QEMU

    qemu_log_mask(LOG_TRACE, "[%s] Machine initialization complete.\n", machine->type_name);
    return;

error_out:
    error_report("Error initializing Keystone SoC machine: %s", error_get_pretty(errp));
    error_free(errp);
    exit(1); // Or handle error more gracefully if possible
}

static void keystone_soc_machine_class_init(ObjectClass *oc, void *data) {
    MachineClass *mc = MACHINE_CLASS(oc);

    mc->desc = "Keystone SoC with CVA6 and eBPF Coprocessor";
    mc->init = keystone_soc_init;
    mc->default_cpu_type = DEFAULT_CPU_TYPE;
    mc->default_ram_size = 1 * GiB; // 1 GB
    mc->min_cpus = 1;
    mc->max_cpus = 1; // For now, single core CVA6
    // mc->default_ram_id = ...; // If needed
    // mc->reset = ...; // If a custom machine reset beyond device resets is needed
}

static const TypeInfo keystone_soc_machine_info = {
    .name = TYPE_KEYSTONE_SOC_MACHINE,
    .parent = TYPE_MACHINE,
    .instance_size = sizeof(KeystoneSoCMachineState),
    .class_init = keystone_soc_machine_class_init,
};

static void keystone_soc_machine_register_types(void) {
    type_register_static(&keystone_soc_machine_info);
}

type_init(keystone_soc_machine_register_types);
