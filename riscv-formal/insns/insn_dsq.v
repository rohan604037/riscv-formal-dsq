// Golden (ISA-level) model for the custom DSQ instruction used in the
// Silicon SoC kNN tapeout (PicoRV32 + PCPI co-processor).
//
//   dsq rd, rs1, rs2
//   R-type: funct7=0111111 rs2 rs1 funct3=111 rd opcode=0110011
//
//   rd = sum_{i=0..3} (rs1.byte[i] - rs2.byte[i])^2
//   Bytes are UNSIGNED (8-bit pixel intensities). Max result 4*255^2 = 260100,
//   so the 32-bit result never overflows.
//
// This model is written independently of the RTL: it computes the distance in
// plain 32-bit unsigned arithmetic using |a-b| instead of signed 9-bit math.

module rvfi_insn_dsq (
  input                                 rvfi_valid,
  input  [`RISCV_FORMAL_ILEN   - 1 : 0] rvfi_insn,
  input  [`RISCV_FORMAL_XLEN   - 1 : 0] rvfi_pc_rdata,
  input  [`RISCV_FORMAL_XLEN   - 1 : 0] rvfi_rs1_rdata,
  input  [`RISCV_FORMAL_XLEN   - 1 : 0] rvfi_rs2_rdata,
  input  [`RISCV_FORMAL_XLEN   - 1 : 0] rvfi_mem_rdata,
`ifdef RISCV_FORMAL_CSR_MISA
  input  [`RISCV_FORMAL_XLEN   - 1 : 0] rvfi_csr_misa_rdata,
  output [`RISCV_FORMAL_XLEN   - 1 : 0] spec_csr_misa_rmask,
`endif

  output                                spec_valid,
  output                                spec_trap,
  output [                       4 : 0] spec_rs1_addr,
  output [                       4 : 0] spec_rs2_addr,
  output [                       4 : 0] spec_rd_addr,
  output [`RISCV_FORMAL_XLEN   - 1 : 0] spec_rd_wdata,
  output [`RISCV_FORMAL_XLEN   - 1 : 0] spec_pc_wdata,
  output [`RISCV_FORMAL_XLEN   - 1 : 0] spec_mem_addr,
  output [`RISCV_FORMAL_XLEN/8 - 1 : 0] spec_mem_rmask,
  output [`RISCV_FORMAL_XLEN/8 - 1 : 0] spec_mem_wmask,
  output [`RISCV_FORMAL_XLEN   - 1 : 0] spec_mem_wdata
);

  // R-type instruction format
  wire [`RISCV_FORMAL_ILEN-1:0] insn_padding = rvfi_insn >> 16 >> 16;
  wire [6:0] insn_funct7 = rvfi_insn[31:25];
  wire [4:0] insn_rs2    = rvfi_insn[24:20];
  wire [4:0] insn_rs1    = rvfi_insn[19:15];
  wire [2:0] insn_funct3 = rvfi_insn[14:12];
  wire [4:0] insn_rd     = rvfi_insn[11: 7];
  wire [6:0] insn_opcode = rvfi_insn[ 6: 0];

`ifdef RISCV_FORMAL_CSR_MISA
  wire misa_ok = 1;
  assign spec_csr_misa_rmask = 0;
`else
  wire misa_ok = 1;
`endif

  // |a - b| for one unsigned byte lane, then squared (fits in 16 bits)
  function [31:0] lane_sq;
    input [7:0] a, b;
    reg   [7:0] ad;
    begin
      ad      = (a >= b) ? (a - b) : (b - a);
      lane_sq = ad * ad;
    end
  endfunction

`ifdef RISCV_FORMAL_ALTOPS
  // ALTOPS: abstract datapath (real arithmetic is proven in formal/dsq_unit).
  // Checks decode, operand routing, PCPI handshake and rd writeback in the CPU.
  wire [31:0] result = (rvfi_rs1_rdata - rvfi_rs2_rdata) ^ 32'h 5a3c_96e1;
`else
  wire [31:0] result = lane_sq(rvfi_rs1_rdata[ 7: 0], rvfi_rs2_rdata[ 7: 0])
                     + lane_sq(rvfi_rs1_rdata[15: 8], rvfi_rs2_rdata[15: 8])
                     + lane_sq(rvfi_rs1_rdata[23:16], rvfi_rs2_rdata[23:16])
                     + lane_sq(rvfi_rs1_rdata[31:24], rvfi_rs2_rdata[31:24]);
`endif

  assign spec_valid    = rvfi_valid && !insn_padding && insn_funct7 == 7'b 0111111 &&
                         insn_funct3 == 3'b 111 && insn_opcode == 7'b 0110011;
  assign spec_rs1_addr = insn_rs1;
  assign spec_rs2_addr = insn_rs2;
  assign spec_rd_addr  = insn_rd;
  assign spec_rd_wdata = spec_rd_addr ? result : 0;
  assign spec_pc_wdata = rvfi_pc_rdata + 4;

  // default assignments
  assign spec_trap      = !misa_ok;
  assign spec_mem_addr  = 0;
  assign spec_mem_rmask = 0;
  assign spec_mem_wmask = 0;
  assign spec_mem_wdata = 0;
endmodule
