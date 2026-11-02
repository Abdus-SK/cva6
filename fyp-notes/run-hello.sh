#!/bin/bash
# Hello world on a CVA6 target. Usage: bash fyp-notes/run-hello.sh cv32a65x   (or cv32a6_imac_sv32)
TARGET=${1:-cv32a65x}
cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/.." || exit 1
source fyp-notes/cva6-env.sh
source ./verif/regress/install-verilator.sh
source ./verif/regress/install-spike.sh
source ./verif/sim/setup-env.sh
export UVM_VERBOSITY=UVM_NONE
export DV_OPTS="$DV_OPTS --issrun_opts=+debug_disable=1+UVM_VERBOSITY=$UVM_VERBOSITY"
CC_OPTS="-static -mcmodel=medany -fvisibility=hidden -nostdlib -nostartfiles -g ../tests/custom/common/syscalls.c ../tests/custom/common/crt.S -I../tests/custom/env -I../tests/custom/common -lgcc"
LINKER=../../config/gen_from_riscv_config/linker/link.ld
[ "$TARGET" = "cv32a65x" ] && LINKER=../../config/gen_from_riscv_config/cv32a65x/linker/link.ld
cd verif/sim
make -C ../.. clean
make clean_all
python3 cva6.py --c_tests ../tests/custom/hello_world/hello_world.c --iss_yaml cva6.yaml --target $TARGET --iss=$DV_SIMULATORS --linker=$LINKER --gcc_opts="$CC_OPTS -nostdlib -lgcc" $DV_OPTS
make -C ../.. clean
