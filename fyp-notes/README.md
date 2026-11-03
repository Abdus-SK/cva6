# FYP: Matrix multiplication engine + vector-lite unit on CVA6

Author: Abdus Salam Khan · Fork: https://github.com/Abdus-SK/cva6

This folder is the project journal. It records the setup, every change made to the
CVA6 base and why, and how to rebuild and rerun everything. Paste this file into a
new chat to resume work.

## Base version (frozen)

| Item | Value |
|---|---|
| Upstream | https://github.com/openhwgroup/cva6 |
| Pinned commit | `81245a47fad8fe1a5d562d953ef2662e099def76` (2026-09-15, "Fix hgatp unsupported mode writes (#3552)") |
| Tag | `fyp-base` |
| Branch | `master` of the fork, no upstream remote (by decision) |

Rules: never press GitHub's "Sync fork". Compare against the base with
`git diff fyp-base`. Submodule versions are locked by the pinned commit.

## FYP base configuration: cv64a6_imafdc_sv39

| Setting | Value | Why it matters |
|---|---|---|
| XLEN | 64 | Supervisor requires RV64 |
| F, D | on | Supervisor requires floating point |
| CvxifEn | 1 | Coprocessor port for the matrix engine and vector-lite unit |
| SuperscalarEn | 0 | Single-issue (NrCommitPorts 2 = two can retire per cycle, not dual issue) |
| MmuPresent | 1 (sv39) | Not needed for bare metal; harmless |
| Linker | generic `config/gen_from_riscv_config/linker/link.ld` | No target-specific one |

Default target in the Makefile (line 104). Rejected: cv32a65x (dual-issue, 32-bit), cv32a6_imac_sv32 (no CV-X-IF),
cv32a60x (32-bit, no FPU). All three still pass hello world.

Open design question: vectors are 256-bit (int32 x 8), four times XLEN, so the vector-lite unit needs its own
register file. Check whether this CVA6 implements the CV-X-IF memory interface (coprocessor loads/stores).
FPGA target: DE10 (Cyclone V) or DE25; CVA6's FPGA flow is Xilinx-based, so a Quartus port and area check are needed.

## Machine and tools

- Arch Linux, kernel 7.2.11-arch1-1, fish shell, VSCodium. 12 cores, 7.2 GiB RAM (the limit, so `NUM_JOBS=4`), zram + 4 GB swap.
- System: git 2.56.0, Python 3.14.8, GCC 16.2.1, cmake 4.4.4, make 4.4.1, help2man.
- RISC-V toolchain: `riscv64-elf-gcc` 16.2.0, `riscv64-elf-binutils` 2.47, `riscv64-elf-newlib` 4.6.0.20260123 (Arch packages, multilib includes rv32 variants).
- Verilator **5.008 (mod)**, built by `verif/regress/install-verilator.sh` into `cva6/tools/verilator-v5.008` (git-ignored). The system Verilator 5.052 is NOT used.
- Spike **1.1.1-dev b3149ab0**, built from the in-tree source into `cva6/tools/spike` (git-ignored).

## Folder layout

| Path | What |
|---|---|
| `~/FYP/fyp/cva6` | This repo |
| `~/FYP/fyp/riscv/bin` | 28 links to `/usr/bin/riscv64-elf-*` (used as `$RISCV`) |
| `cva6/tools/` | Built Verilator and Spike (git-ignored) |
| `cva6/verif/sim/out_<date>/` | Simulation results (git-ignored) |
| `cva6/fyp-notes/` | This journal, env file, helper scripts, evidence logs |
| `~/FYP/tools`, `riscv-isa-sim`, `riscv-pk`, `riscv-tests`, ... | Old June-July attempts, not used |

## How to run (hello world)

From the `cva6` folder, in any shell:

```
bash fyp-notes/run-hello.sh cv32a65x
bash fyp-notes/run-hello.sh cv32a6_imac_sv32
```

Success = `[PASSED]: 717 matched` and `0 FAILED` in the output.
Results: `verif/sim/out_<date>/iss_regr.log` (cumulative per day).

`fyp-notes/cva6-env.sh` sets every variable explicitly, because the login shell
still sets old values (`VERILATOR_INSTALL_DIR=/usr`, `VERILATOR_ROOT=/usr/share/verilator`,
`RISCV` and `SPIKE_INSTALL_DIR` pointing into `~/FYP/tools`). CVA6 scripts are bash, so
run them through bash, never source them in fish.

## Rebuild recipes (new machine or clean install)

```
# RISC-V link folder
mkdir -p ~/FYP/fyp/riscv/bin
for f in /usr/bin/riscv64-elf-*; do ln -sf "$f" ~/FYP/fyp/riscv/bin/; done

# Verilator 5.008 (from the cva6 folder, needs help2man, about 12 min)
env -u VERILATOR_INSTALL_DIR -u VERILATOR_BUILD_DIR -u VERILATOR_ROOT NUM_JOBS=4 bash verif/regress/install-verilator.sh

# Spike (from the cva6 folder, about 23 min)
env -u SPIKE_INSTALL_DIR -u SPIKE_SRC_DIR CXXFLAGS="-include cstdint" CMAKE_POLICY_VERSION_MINIMUM=3.5 RISCV=$HOME/FYP/fyp/riscv NUM_JOBS=4 bash verif/regress/install-spike.sh
```

Why the Spike flags: the bundled yaml-cpp misses `#include <cstdint>` (needed since
GCC 13), and CMake 4 refuses projects declaring a minimum below 3.5.

## Changes to the CVA6 base

| Commit | File | Change | Why |
|---|---|---|---|
| `75634edc` | `verif/sim/cva6.py` line 987 | `split(" ")[2]` to `split(" ")[-1]` | Arch GCC prints `(Arch Linux Repositories) 16.2.0`, so the version check read "Linux" and crashed |
| `d889c4cd` (tag `fyp-hello-pass`) | `verif/tests/custom/common/syscalls.c` lines 180-181 | `static __thread` to `static` | Arch GCC has no native TLS for bare metal; emulated TLS needs `malloc`, absent with `-nostdlib`. CVA6 is single-hart, so equivalent |
| `f53ce7c9` | `verif/tests/custom/common/util.h` line 49 | `static __thread` to `static` | Same issue; this code is only compiled with the A extension (`#ifdef __riscv_atomic`), so it hit cv32a6_imac_sv32 but not cv32a65x |

Note: `verif/tests/custom/Zcmp/` has its own copies of the same `__thread` lines (not fixed, not used yet).

## Results

| Date | Target | Result | Log |
|---|---|---|---|
| 2026-11-02 | cv32a65x | PASSED, 717 matched | |
| 2026-11-02 | cv32a6_imac_sv32 | PASSED, 717 matched | `logs/hello-cv32a6_imac_sv32-run2.log` |
| 2026-11-03 | cv32a65x (via `fyp-notes/run-hello.sh`) | PASSED, 717 matched | `logs/hello-cv32a65x-run4.log` |
| 2026-11-03 | cv32a60x (own linker script) | PASSED, 717 matched | `logs/hello-cv32a60x-run5.log` |
| 2026-11-03 | cv32a65x (recheck after linker change) | PASSED, 717 matched | |
| 2026-11-03 | **cv64a6_imafdc_sv39 (FYP base)** | PASSED, 780 matched, 63 s | `logs/hello-cv64a6_imafdc_sv39.log` |

## Gotchas

- The scripts' exit code is not reliable (0 even on failure). Always read the log.
- `iss_regr.log` appends per run, so totals like "2 PASSED" include earlier runs that day.
- fish: quote wildcards in arguments (`'--include=*.py'`); use `git --no-pager` (no `less` installed).
- `smoke-gen_tests.sh` defaults to a commercial simulator (vcs-uvm); skipped.
- The official test suites (riscv-tests, riscv-compliance, riscv-arch-test) are not installed yet.
- `.gitignore` line 25 (`*.log`) ignores logs everywhere: add evidence logs with `git add -f`.
- `run-hello.sh` uses a target's own `config/gen_from_riscv_config/<target>/linker/link.ld` if it exists, else the generic one.
## Journal

- **2026-10-23**: Tool inventory, forked CVA6, cloned, pinned commit, tagged `fyp-base`, fetched submodules.
- **2026-10-31**: System update (for help2man), built `$RISCV` link folder, Verilator 5.008 and Spike.
- **2026-11-02**: Fixed `cva6.py` and `syscalls.c`; cv32a65x hello world passed. Logged in with `gh`, pushed. Fixed `util.h`; cv32a6_imac_sv32 passed. Pushed.
- **2026-11-03**: Moved env file and hello script into `fyp-notes/`, made them location-independent; cv32a65x passed through them. Wrote this journal.
- **2026-11-03**: Compared configs. Supervisor requires RV64 + floating point, so the base is cv64a6_imafdc_sv39 (CV-X-IF on, single-issue). Made the linker choice general in `run-hello.sh`. Hello world passed on cv32a60x (717) and cv64a6_imafdc_sv39 (780). Tagged `fyp-cv64-base`.

## Next steps
1. Run the official suites (riscv-tests, riscv-arch-test, riscv-compliance) on cv64a6_imafdc_sv39 as a baseline.
2. Study CV-X-IF in this CVA6: interface signals, the example coprocessor, and whether the memory interface exists.
3. Define the custom instructions and the 256-bit vector register file; prototype with `.insn`.
4. Check FPGA fit: CVA6 area vs DE10 / DE25.