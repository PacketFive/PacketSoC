// Boot ROM Stub
// Date: 2024-03-14
`timescale 1ns / 1ps

module Boot_ROM_Stub (
    input  wire         clk,
    input  wire         resetn, // Active low reset

    // CPU Interface (Simplified - not a full AXI slave for this stub)
    // Assumes CPU has a way to provide address and read data directly.
    // In a real system, this might be an AXI-Lite slave or a dedicated boot bus.
    input  wire [15:0]  boot_addr_i, // Example: 64KB ROM, so 16-bit address (word aligned)
    output wire [31:0]  boot_data_o
);

    localparam ROM_DEPTH = (64 * 1024) / 4; // 64KB ROM, 32-bit words
    reg [31:0] rom_mem [0:ROM_DEPTH-1];

    // Initialize ROM with some dummy data (e.g., a simple jump instruction)
    initial begin
        // Example: lui a0, %hi(0x80000000); addi a0, a0, %lo(0x80000000) -> jump to DRAM
        // This is just a placeholder. Actual boot code would be more complex.
        rom_mem[0] = 32'h80000537; // lui a0, 0x80000
        rom_mem[1] = 32'h00050513; // addi a0, a0, 0
        rom_mem[2] = 32'h000500E7; // jalr zero, a0, 0 (jalr x0, x10, 0) -> jump to a0
        // Fill rest with NOPs (addi x0, x0, 0) or zeros
        for (integer i = 3; i < ROM_DEPTH; i = i + 1) begin
            rom_mem[i] = 32'h00000013; // NOP
        end
    end

    // Combinatorial read based on boot_addr_i
    // Assuming boot_addr_i is word-aligned.
    assign boot_data_o = (boot_addr_i < ROM_DEPTH) ? rom_mem[boot_addr_i] : 32'hDEADBEEF;

endmodule
