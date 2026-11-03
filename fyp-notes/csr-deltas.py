#!/usr/bin/env python3
"""Read mcycle/minstret values from a CVA6 RVFI trace and print per-kernel deltas.

Usage: python3 fyp-notes/csr-deltas.py verif/sim/trace_rvfi_hart_00.dasm [label ...]
A test built with -DFYP_COUNT reads mcycle then minstret before and after each
measured kernel. Each read appears in the trace as
    <priv> 0x<pc> (0x<opcode>) x<rd> 0x<value>   (single-digit rd may be padded: x 9)
where the opcode is csrrs rd, <csr>, x0 (csr 0xB00 = mcycle, 0xB02 = minstret).
"""
import re
import sys

LINE = re.compile(r"\((0x[0-9a-fA-F]+)\)\s+x\s*(\d+)\s+(0x[0-9a-fA-F]+)")  # "x 9" or "x15"
NAMES = {0xB00: "mcycle", 0xB02: "minstret"}


def main():
    if len(sys.argv) < 2:
        sys.exit(__doc__)
    labels = sys.argv[2:] or ["int8", "int16", "fp32", "fp64"]
    reads = {"mcycle": [], "minstret": []}
    with open(sys.argv[1], errors="replace") as f:
        for line in f:
            m = LINE.search(line)
            if not m:
                continue
            op = int(m.group(1), 16)
            if op & 0x7F != 0x73 or (op >> 12) & 0x7 != 0x2 or (op >> 15) & 0x1F != 0:
                continue  # not csrrs rd, csr, x0 (= csrr)
            csr = (op >> 20) & 0xFFF
            if csr in NAMES:
                reads[NAMES[csr]].append(int(m.group(3), 16))
    mc, mi = reads["mcycle"], reads["minstret"]
    print(f"found {len(mc)} mcycle and {len(mi)} minstret reads")
    if len(mc) != 2 * len(labels) or len(mi) != 2 * len(labels):
        print("unexpected number of reads; raw values:")
        print("mcycle  ", mc)
        print("minstret", mi)
        return
    print(f"{'kernel':<8}{'cycles':>10}{'instret':>10}{'IPC':>8}{'cycles/MAC':>12}")
    macs = 8 * 8 * 8
    for k, name in enumerate(labels):
        cyc = mc[2 * k + 1] - mc[2 * k]
        ins = mi[2 * k + 1] - mi[2 * k]
        ipc = ins / cyc if cyc else 0.0
        print(f"{name:<8}{cyc:>10}{ins:>10}{ipc:>8.2f}{cyc / macs:>12.2f}")


if __name__ == "__main__":
    main()
