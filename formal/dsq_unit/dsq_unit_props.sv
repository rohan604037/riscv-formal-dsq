// Standalone formal property verification of the tapeout DSQ PCPI co-processor
// (module picorv32_pcpi_dsq in the Silicon SoC kNN picorv32.v).
//
// What is proven (unbounded, via k-induction):
//   P1  result:     a DSQ request accepted at cycle t produces
//                   pcpi_rd == golden_dsq(rs1, rs2) at cycle t+1
//   P2  handshake:  pcpi_wr and pcpi_ready are always asserted together
//   P3  pulse:      pcpi_ready is high for one cycle only per request
//   P4  no-false:   ready is never raised unless a DSQ insn was valid the cycle before
//   P5  wait:       pcpi_wait is never asserted (single-cycle unit)
// Environment (assumptions) model how PicoRV32 drives PCPI:
//   A1  insn/rs1/rs2 stay stable while pcpi_valid is high
//   A2  the core drops pcpi_valid the cycle after it sees pcpi_ready

module dsq_unit_props (
	input        clk,
	input        resetn,
	input        pcpi_valid,
	input [31:0] pcpi_insn,
	input [31:0] pcpi_rs1,
	input [31:0] pcpi_rs2
);
	wire        pcpi_wr, pcpi_wait, pcpi_ready;
	wire [31:0] pcpi_rd;

	picorv32_pcpi_dsq dut (
		.clk(clk), .resetn(resetn),
		.pcpi_valid(pcpi_valid), .pcpi_insn(pcpi_insn),
		.pcpi_rs1(pcpi_rs1), .pcpi_rs2(pcpi_rs2),
		.pcpi_wr(pcpi_wr), .pcpi_rd(pcpi_rd),
		.pcpi_wait(pcpi_wait), .pcpi_ready(pcpi_ready)
	);

	// ---------------- golden model (independent of RTL style) ----------------
	function [31:0] lane_sq;
		input [7:0] a, b;
		reg   [7:0] ad;
		begin
			ad      = (a >= b) ? (a - b) : (b - a);
			lane_sq = ad * ad;
		end
	endfunction

	function [31:0] golden_dsq;
		input [31:0] x, y;
		golden_dsq = lane_sq(x[ 7: 0], y[ 7: 0]) + lane_sq(x[15: 8], y[15: 8])
		           + lane_sq(x[23:16], y[23:16]) + lane_sq(x[31:24], y[31:24]);
	endfunction

	wire is_dsq = pcpi_insn[6:0] == 7'b0110011 && pcpi_insn[31:25] == 7'b0111111 &&
	              pcpi_insn[14:12] == 3'b111;

	// ---------------- environment ----------------
	reg init = 1;
	always @(posedge clk) init <= 0;
	always @* if (init) assume (!resetn);

	always @(posedge clk) if (!init && resetn && $past(resetn)) begin
		// A1: operands stable while the request is pending
		if ($past(pcpi_valid) && pcpi_valid && !$past(pcpi_ready)) begin
			assume ($stable(pcpi_insn));
			assume ($stable(pcpi_rs1));
			assume ($stable(pcpi_rs2));
		end
		// A2: core retires the request when it sees ready
		if ($past(pcpi_ready)) assume (!pcpi_valid);
	end

	// ---------------- properties ----------------
	always @* if (!init && resetn) begin
		assert (pcpi_wr == pcpi_ready);                      // P2
		assert (!pcpi_wait);                                 // P5
	end

	always @(posedge clk) if (!init && resetn && $past(resetn)) begin
		// P1: correct result one cycle after an accepted DSQ request
		if (pcpi_ready)
			assert (pcpi_rd == golden_dsq($past(pcpi_rs1), $past(pcpi_rs2)));
		// P3: single-cycle pulse
		if ($past(pcpi_ready)) assert (!pcpi_ready);
		// P4: no ready without a valid DSQ request in the previous cycle
		if (pcpi_ready) assert ($past(pcpi_valid) && $past(is_dsq));
	end

	// P6 latency: a fresh DSQ request (valid rises) is answered in exactly one cycle
	reg past2_valid = 0;
	always @(posedge clk) past2_valid <= $past(pcpi_valid);
	always @(posedge clk) if (!init && resetn && $past(resetn) && $past(resetn, 2) &&
	                          $past(pcpi_valid) && $past(is_dsq) && !past2_valid)
		assert (pcpi_ready);

	// coverage: show the unit can actually produce a result (non-vacuity)
	always @(posedge clk) if (!init && resetn) begin
		cover (pcpi_ready && pcpi_rd == 32'd260100);  // max distance: all lanes 255 vs 0
		cover (pcpi_ready && pcpi_rd == 32'd1);
	end
endmodule
