// Extracted verbatim from tapeout RTL/picorv32.v lines 2644-2726
module picorv32_pcpi_dsq (
    input              clk,
    input              resetn,

    input              pcpi_valid,
    input      [31:0]  pcpi_insn,
    input      [31:0]  pcpi_rs1,  // holds four packed bytes
    input      [31:0]  pcpi_rs2,
    output reg         pcpi_wr,
    output reg [31:0]  pcpi_rd,
    output reg         pcpi_wait,
    output reg         pcpi_ready
);

  // Detect DSQ custom instruction
  wire instr_dsq = pcpi_valid &&
                    pcpi_insn[6:0] == 7'b0110011 &&
                    pcpi_insn[31:25] == 7'b0111111 &&
                    pcpi_insn[14:12] == 3'b111;

  // Extract individual bytes
  wire signed [7:0] b1 = pcpi_rs1[7:0];
  wire signed [7:0] b2 = pcpi_rs1[15:8];
  wire signed [7:0] b3 = pcpi_rs1[23:16];
  wire signed [7:0] b4 = pcpi_rs1[31:24];

  wire signed [7:0] c1 = pcpi_rs2[7:0];
  wire signed [7:0] c2 = pcpi_rs2[15:8];
  wire signed [7:0] c3 = pcpi_rs2[23:16];
  wire signed [7:0] c4 = pcpi_rs2[31:24];

  // Sign-extend to signed 8-bit then subtract ? 9-bit signed diff
  wire signed [8:0] d1 = b1 - c1;
  wire signed [8:0] d2 = b2 - c2;
  wire signed [8:0] d3 = b3 - c3;
  wire signed [8:0] d4 = b4 - c4;

  // Square each diff ? 18 bits
  wire [17:0] sq1 = d1 * d1;
  wire [17:0] sq2 = d2 * d2;
  wire [17:0] sq3 = d3 * d3;
  wire [17:0] sq4 = d4 * d4;

  // Final unsigned 32-bit distance
  wire [31:0] result = sq1 + sq2 + sq3 + sq4;

  reg processing;

  reg seen;

    always @(posedge clk) begin
    	if (!resetn) begin
    	    pcpi_wr    <= 0;
    	    pcpi_rd    <= 0;
    	    pcpi_wait  <= 0;
    	    pcpi_ready <= 0;
    	    seen       <= 0;
    	end
    	else begin
    	    // Default outputs
    	    pcpi_wr    <= 0;
    	    pcpi_ready <= 0;
    	    pcpi_wait  <= 0;

        	// Latch input once
            if (pcpi_valid && instr_dsq && !seen) begin
        	pcpi_rd    <= result;
        	pcpi_wr    <= 1;
        	pcpi_ready <= 1;
        	seen       <= 1;

            //	$display("== DSQ EXECUTED ==");
            //	$display("RESULT = %0d (0x%08x)", result, result);
            end

        // Reset latch when instruction completes
            if (!pcpi_valid)
            	seen <= 0;
    	end
    end


endmodule
