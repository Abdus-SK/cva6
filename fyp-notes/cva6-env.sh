# CVA6 FYP environment. Use inside bash, from the cva6 folder: source fyp-notes/cva6-env.sh
# CVA6_ROOT is worked out from this file location, so the repo can live anywhere.
export CVA6_ROOT="$(readlink -f "$(dirname "${BASH_SOURCE[0]}")/..")"
# RISCV = folder of links to the riscv64-elf-* tools. Set FYP_RISCV before sourcing to override.
export RISCV="${FYP_RISCV:-/home/BlazeringNoctal/FYP/fyp/riscv}"
export VERILATOR_INSTALL_DIR="$CVA6_ROOT/tools/verilator-v5.008"
unset VERILATOR_ROOT
export SPIKE_INSTALL_DIR="$CVA6_ROOT/tools/spike"
unset SPIKE_SRC_DIR
export NUM_JOBS=4
export DV_SIMULATORS=veri-testharness,spike
export PATH="$VERILATOR_INSTALL_DIR/bin:$SPIKE_INSTALL_DIR/bin:$RISCV/bin:$PATH"
# Only needed when rebuilding Spike with the newer CMake and GCC:
# export CXXFLAGS="-include cstdint" CMAKE_POLICY_VERSION_MINIMUM=3.5
