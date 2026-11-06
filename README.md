# riscv-formal-dsq

Formal verification of a **taped-out PicoRV32 RISC-V core** (Silicon SoC kNN, SCL 180 nm)
and its **custom DSQ instruction** — a kNN squared-distance accelerator attached through
PicoRV32's PCPI co-processor port — using
[riscv-formal](https://github.com/YosysHQ/riscv-formal), Yosys, SymbiYosys and SMT solvers.

The core under test is the exact `picorv32.v` from the tapeout repository (not upstream
PicoRV32), with the same parameters the SoC instantiates. The only edits are formal-only
`` `ifdef RISCV_FORMAL_ALTOPS `` blocks, which are inactive in synthesis.

**Headline:** 59/59 riscv-formal checks pass on the tapeout core; the DSQ datapath has an
unbounded proof; every injected bug is caught; and the investigation surfaced a
reset-robustness issue in upstream PicoRV32's slow multiplier (masked in this SoC by its
multi-cycle reset). See [Findings](#findings).

## The DSQ instruction

```
dsq rd, rs1, rs2        R-type: funct7=0111111  funct3=111  opcode=0110011

rd = Σ_{i=0..3} (rs1.byte[i] − rs2.byte[i])²       bytes are unsigned pixels
```

Max result is 4·255² = 260100, so the 32-bit result never overflows. It is implemented as
a single-cycle PCPI co-processor (`picorv32_pcpi_dsq`).

## Verification strategy

Verifying the full CPU *and* four 9-bit squarers in one bounded proof is expensive for an
SMT solver (multiplier equivalence is a classic hard case). The proof is therefore split
compositionally — the same approach riscv-formal uses for MUL/DIV (`RISCV_FORMAL_ALTOPS`):

| Layer | What is proven | How | Where |
|---|---|---|---|
| **1. DSQ unit** | Datapath = golden model; PCPI handshake (P1–P6) | **Unbounded** proof, k-induction | [`formal/dsq_unit/`](formal/dsq_unit/) |
| **2. DSQ in the CPU** | Decode, operand routing, PCPI handshake, `rd` write-back, PC update | riscv-formal `insn` check, ALTOPS datapath stand-in | [`riscv-formal/cores/picorv32_dsq/`](riscv-formal/cores/picorv32_dsq/) |
| **3. Whole core** | Every RV32I + Zmmul instruction, register file, PC continuity, liveness, uniqueness, CSRs | riscv-formal full suite on the tapeout core | same |

### Layer 1 — DSQ unit properties ([`dsq_unit_props.sv`](formal/dsq_unit/dsq_unit_props.sv))

| | Property |
|---|---|
| P1 | `pcpi_rd` equals an independently written golden model, one cycle after the request |
| P2 | `pcpi_wr` and `pcpi_ready` are always asserted together |
| P3 | `pcpi_ready` is a single-cycle pulse |
| P4 | `pcpi_ready` is never raised without a valid DSQ request |
| P5 | `pcpi_wait` is never asserted |
| P6 | a fresh request is answered in exactly one cycle |
| A1/A2 | environment: operands stable while pending; core drops `pcpi_valid` after `ready` |
| Cover | max distance (260100) and distance 1 are reachable (non-vacuity) |

### Bug injection (mutation testing)

To show the properties actually catch bugs, four realistic mutants of the tapeout RTL are
checked; each must produce a counterexample.

| Mutant | Bug | Caught by |
|---|---|---|
| `mut_signed` | bytes treated as signed (the older, commented-out RTL version) | P1 |
| `mut_drop_lane` | one byte lane missing from the sum | P1 |
| `mut_narrow_diff` | 8-bit difference → overflow | P1 |
| `mut_no_seen` | `seen` latch removed → result issued twice | P3 |

Lesson learned: `mut_no_seen` initially *survived* at BMC depth 4. Yosys checks clocked
assertions one cycle late, so the double-pulse only becomes visible at step 4; raising the
depth to 8 killed it. A surviving mutant is a hole in either the properties or the bounds.

## Results

| Run | Result | Notes |
|---|---|---|
| DSQ unit — unbounded proof (k-induction) | **PASS** | P1–P6; ~5 min |
| DSQ unit — cover | **PASS** | both cover points reached |
| DSQ unit — bug injection | **4 / 4 caught** | [`mutants/summary.txt`](formal/dsq_unit/mutants/summary.txt) |
| DSQ in the CPU (`insn_dsq`, ALTOPS) | **PASS** | 32 s |
| DSQ in the CPU — decode-bug injection | **caught** | [`dsq_cpu_mutant.txt`](results/dsq_cpu_mutant.txt) |
| **Tapeout core, full riscv-formal suite** | **59 / 59 PASS** | [`tapeout.txt`](results/tapeout.txt); RV32I + Zmmul + DSQ, reg, pc_fwd/bwd, liveness, unique, causal, CSRs |
| Upstream PicoRV32 reference (RV32IMC) | **87 / 87 PASS** | [`baseline.txt`](results/baseline.txt) |
| DSQ in the CPU **without** ALTOPS | did not converge in 40+ min | motivates the compositional split |

Tools: Yosys 0.70, SymbiYosys, Boolector (riscv-formal checks), Bitwuzla (DSQ unit),
on WSL2 Ubuntu, 12 cores.

## Findings

The first full run of the tapeout core had **13 failing checks**. Each counterexample was
traced in the waveform ([`scripts/vcd_dump.py`](scripts/vcd_dump.py)) and classified as
either an environment/spec mismatch or a real design issue:

| # | Symptom | Root cause | Classification | Resolution |
|---|---|---|---|---|
| 1 | Branches, JAL/JALR, LH: `spec_trap != trap` | With `ENABLE_IRQ=1`, PicoRV32 signals misaligned accesses through its **custom bus-error IRQ** instead of a trap once firmware unmasks it with `maskirq` (`picorv32_dsq.v:1958`) | Non-standard ISA behaviour (not a bug) | Confirmed by re-running JAL with IRQ off (PASS). Kept the tapeout config and added a documented assumption: firmware does not issue PicoRV32 custom-0 IRQ instructions. `irq_mask` resets to all-ones, so misalignment then traps normally. |
| 2 | Liveness: no instruction retires | Fetched `waitirq` blocks forever with IRQs tied off. My first assumption constrained *retired* instructions only, and `waitirq` never retires. | **Hole in my own environment model**, exposed by the liveness check | Assumption moved to instruction **fetch**. |
| 3 | MUL*: "assumptions unsatisfiable" | Tapeout uses the slow `picorv32_pcpi_mul` (32 / 64 cycles); 20-cycle window too short | Proof-bound issue | Depth 50 (MUL) / 90 (MULH*); liveness window 100. |
| 4 | MUL*: wrong `rd` value | Upstream slow `picorv32_pcpi_mul` has no `RISCV_FORMAL_ALTOPS` branch (only `fast_mul` does), so RTL computed real products vs the ALTOPS spec | Verification-hook gap in upstream | Added a formal-only ALTOPS branch with riscv-formal's constants. Reproduced on **upstream** PicoRV32 (slow MUL) too, so it is not a tapeout change. |
| 5 | MUL: stale result accepted | **`pcpi_wait` / `pcpi_wait_q` in `picorv32_pcpi_mul` are not reset** (the divider gates them with `resetn`). After a **1-cycle reset** they can leave reset as 1/0, start a phantom 32-cycle multiply, and its late `pcpi_ready` is accepted as the result of an unrelated MUL. ([`cex_slow_mul_1cycle_reset.txt`](results/cex_slow_mul_1cycle_reset.txt)) | **Real reset-robustness issue in upstream PicoRV32**; masked in this SoC | The SoC's `reset_synch.v` (`FF_COUNT=5`) holds core reset for several cycles, which flushes both flops, so the **silicon is not affected**. The wrapper models a 3-cycle reset (conservative). Any SoC that pulses `resetn` for one cycle would be exposed; the fix is `pcpi_wait <= instr_any_mul && resetn`, as in `pcpi_div`. |

Other observations:

- **DSQ spec ambiguity resolved by the formal model.** The RTL comment says bytes are
  "sign-extended", but the code computes on **unsigned** bytes (correct for pixels). An older,
  commented-out version used signed bytes. Writing a golden model forced the intended
  semantics to be pinned down; the signed version is mutant `mut_signed` and is rejected.
- `mut_no_seen` initially *survived* at BMC depth 4 because Yosys evaluates clocked
  assertions one cycle late; raising the depth killed it.
- The CPU-level decode mutant shows up as `PREUNSAT` at the default 20-cycle window (the PCPI
  timeout + illegal-instruction trap does not fit). It is a visible error, not a silent
  pass, and at 40 cycles it fails on `rd`, `pc` and `trap`.

### Assumptions and formal-only edits (all marked in the source)

| Where | What | Why |
|---|---|---|
| `wrapper.sv` `DSQ_NO_IRQ_INSNS` | no custom-0 (PicoRV32 IRQ) instructions fetched | riscv-formal models the RISC-V ISA, not PicoRV32's IRQ extension |
| `wrapper.sv` `DSQ_EXTRA_RESET_CYCLES 2` | core reset held 3 cycles | matches the SoC's multi-cycle reset (finding 5) |
| `wrapper.sv` | external PCPI port and `irq` tied to 0 | same as the SoC (`core_intermediate.v`) |
| `picorv32_dsq.v` `` `ifdef RISCV_FORMAL_ALTOPS `` | stand-in datapath for DSQ and slow MUL | arithmetic proven separately / standard riscv-formal practice |
| `dsq_unit_props.sv` A1/A2 | operands stable while pending; core drops `valid` after `ready` | PicoRV32 PCPI protocol |

## Reproduce

Requires Linux/WSL and [OSS CAD Suite](https://github.com/YosysHQ/oss-cad-suite-build).

```bash
bash scripts/install_tools.sh          # OSS CAD Suite -> ~/tools (no profile changes)
source scripts/env.sh

bash scripts/run_dsq_unit.sh           # layer 1: unbounded proof + cover
bash scripts/run_dsq_mutants.sh        # bug injection (expect FAIL for every mutant)

bash scripts/gen_checks.sh picorv32_dsq
bash scripts/run_checks.sh -c picorv32_dsq -j 4 insn_dsq_ch0     # layer 2
bash scripts/run_all.sh picorv32_dsq 8 tapeout                     # layer 3 (~20 min)
bash scripts/summarize.sh picorv32_dsq tapeout                     # rebuild results/tapeout.txt

bash scripts/progress.sh               # live progress bars
python3 scripts/vcd_dump.py <trace.vcd> --from 0 --to 100 rvfi_valid rvfi_insn ...   # read a counterexample
```

## Layout

```
formal/dsq_unit/                standalone DSQ proof, properties, mutants
riscv-formal/cores/picorv32_dsq tapeout core, wrapper, checks.cfg
riscv-formal/insns/insn_dsq.v   ISA-level golden model of DSQ (+ ALTOPS variant)
riscv-formal/insns/isa_rv32iZmmul_Xdsq.txt   RV32I + Zmmul + DSQ instruction list
scripts/                        setup, run, mutation and progress scripts
results/                        check summaries
UPSTREAM.txt                    upstream riscv-formal / picorv32 commits used
```

## Credits

- riscv-formal and PicoRV32 by YosysHQ / Claire Xenia Wolf (ISC license, see `riscv-formal/COPYING`).
- Tapeout SoC RTL: Silicon SoC kNN team, CIE PES University.
- Formal verification (this repository): Rohan R.
