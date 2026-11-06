// riscv-formal wrapper for the Silicon SoC kNN tapeout PicoRV32 (with DSQ).
// Core parameters mirror RTL/system.v of the tapeout; everything the SoC ties
// off (external PCPI port, IRQ lines) is tied off the same way here.
module rvfi_wrapper (
	input         clock,
	input         reset,
	`RVFI_OUTPUTS
);
	(* keep *) wire trap;

	(* keep *) `rvformal_rand_reg mem_ready;
	(* keep *) `rvformal_rand_reg [31:0] mem_rdata;

	(* keep *) wire        mem_valid;
	(* keep *) wire        mem_instr;
	(* keep *) wire [31:0] mem_addr;
	(* keep *) wire [31:0] mem_wdata;
	(* keep *) wire [3:0]  mem_wstrb;

	// SoC reset model. riscv-formal drives `reset` for 1 cycle; the tapeout SoC
	// holds core reset for several cycles (reset_synch.v, FF_COUNT=5). This matters:
	// picorv32_pcpi_mul's pcpi_wait/pcpi_wait_q are not reset, and with a 1-cycle
	// reset they can start a phantom multiply whose late pcpi_ready is accepted as
	// the result of an unrelated MUL (see results/cex_slow_mul_1cycle_reset.txt).
	// DSQ_EXTRA_RESET_CYCLES extends core reset beyond riscv-formal's 1 cycle
	// (2 extra -> 3 cycles total, enough to flush them; the SoC provides more).
`ifndef DSQ_EXTRA_RESET_CYCLES
`define DSQ_EXTRA_RESET_CYCLES 0
`endif
	reg [3:0] rst_cnt = 0;
	always @(posedge clock)
		if (reset) rst_cnt <= `DSQ_EXTRA_RESET_CYCLES;
		else if (rst_cnt != 0) rst_cnt <= rst_cnt - 1;
	wire core_resetn = !reset && rst_cnt == 0;

	// External PCPI port: tied off exactly like core_intermediate.v
	wire        pcpi_valid;
	wire [31:0] pcpi_insn, pcpi_rs1, pcpi_rs2;

	picorv32 #(
		// tapeout config (system.v + picorv32.v defaults)
		.ENABLE_PCPI      (1),
		.ENABLE_DSQ       (1),
		.ENABLE_MUL       (1),
		.ENABLE_DIV       (0),
		.COMPRESSED_ISA   (0),
		.ENABLE_IRQ       (`DSQ_ENABLE_IRQ),
		.ENABLE_IRQ_TIMER (`DSQ_ENABLE_IRQ),
		.LATCHED_IRQ      (32'hfffffffe)
	) uut (
		.clk        (clock    ),
		.resetn     (core_resetn),
		.trap       (trap     ),

		.mem_valid  (mem_valid),
		.mem_instr  (mem_instr),
		.mem_ready  (mem_ready),
		.mem_addr   (mem_addr ),
		.mem_wdata  (mem_wdata),
		.mem_wstrb  (mem_wstrb),
		.mem_rdata  (mem_rdata),

		.pcpi_valid (pcpi_valid),
		.pcpi_insn  (pcpi_insn ),
		.pcpi_rs1   (pcpi_rs1  ),
		.pcpi_rs2   (pcpi_rs2  ),
		.pcpi_wr    (1'b0      ),
		.pcpi_rd    (32'b0     ),
		.pcpi_wait  (1'b0      ),
		.pcpi_ready (1'b0      ),

		.irq        (32'b0     ),

		`RVFI_CONN
	);

`ifdef DSQ_NO_IRQ_INSNS
	// Environment assumption: software does not use PicoRV32's custom IRQ
	// instructions (custom-0 opcode: getq/setq/retirq/maskirq/waitirq/timer).
	// irq_mask resets to all-ones, so without maskirq the bus-error IRQ stays
	// masked and misaligned accesses take the standard RISC-V trap path that
	// riscv-formal models. (With maskirq, PicoRV32 raises a custom IRQ instead,
	// which is outside the RISC-V ISA spec.)
	// Applied at instruction FETCH, not retirement: waitirq never retires (it
	// blocks until an IRQ), so an rvfi_valid-based assumption would not exclude it
	// (the liveness check found exactly that hole).
	always @* if (!reset && mem_valid && mem_instr && mem_ready)
		assume (mem_rdata[6:0] != 7'b0001011);
`endif

`ifdef PICORV32_FAIRNESS
	reg [2:0] mem_wait = 0;
	always @(posedge clock) begin
		mem_wait <= {mem_wait, mem_valid && !mem_ready};
		assume (~mem_wait || trap);
	end
`endif
endmodule
