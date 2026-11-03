#!/bin/bash
# Run any bare-metal C test on a CVA6 target.
# Usage: bash fyp-notes/run-c.sh <target> <c-file> [simulators] [extra gcc options]
#   simulators default: veri-testharness,spike (trace compare). Use veri-testharness alone for cycle counts.
# Example: bash fyp-notes/run-c.sh cv64a6_imafdc_sv39 verif/tests/custom/fyp/matmul8x8.c veri-testharness -DFYP_COUNT
TARGET=${1:-cv64a6_imafdc_sv39}
CFILE=${2:?give a C file, e.g. verif/tests/custom/fyp/matmul8x8.c}
SIMS=$3
EXTRA=$4
cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/.." || exit 1
CFILE="$(readlink -f "$CFILE")"
[ -f "$CFILE" ] || { echo "No such C file: $CFILE"; exit 1; }
source fyp-notes/cva6-env.sh
source ./verif/regress/install-verilator.sh
source ./verif/regress/install-spike.sh
source ./verif/sim/setup-env.sh
[ -n "$SIMS" ] && export DV_SIMULATORS="$SIMS"
echo "FYP-RUN target=$TARGET file=$CFILE simulators=$DV_SIMULATORS extra=$EXTRA"
export UVM_VERBOSITY=UVM_NONE
export DV_OPTS="$DV_OPTS --issrun_opts=+debug_disable=1+UVM_VERBOSITY=$UVM_VERBOSITY"
CC_OPTS="-static -mcmodel=medany -fvisibility=hidden -nostdlib -nostartfiles -g -O2 $EXTRA ../tests/custom/common/syscalls.c ../tests/custom/common/crt.S -I../tests/custom/env -I../tests/custom/common -lgcc"
LINKER=../../config/gen_from_riscv_config/linker/link.ld
[ -f "config/gen_from_riscv_config/$TARGET/linker/link.ld" ] && LINKER="../../config/gen_from_riscv_config/$TARGET/linker/link.ld"
cd verif/sim
make -C ../.. clean
make clean_all
python3 cva6.py --c_tests "$CFILE" --iss_yaml cva6.yaml --target $TARGET --iss=$DV_SIMULATORS --linker=$LINKER --gcc_opts="$CC_OPTS -nostdlib -lgcc" $DV_OPTS
make -C ../.. clean
