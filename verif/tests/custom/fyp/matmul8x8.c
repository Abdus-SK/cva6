// FYP scalar baseline: 8x8 matrix multiply C = A x B on CVA6, no accelerator.
// Types: int8 and int16 inputs (int32 accumulate), fp32, fp64.
// Inputs are small whole numbers (-7..7), so every result is exact in all four
// types: each must give sum=157, wsum=725, C[0][0]=2.
//
// No printf: the CVA6 Verilator testbench does not answer print syscalls, so a
// printf would hang the core. The test checks itself and reports via exit code:
//   0 = all correct; otherwise 10*type + check (type 1..4 = int8,int16,fp32,fp64;
//   check 1 = sum, 2 = wsum, 3 = C[0][0]). The testbench shows tohost = 2*code+1.
//
// -DFYP_COUNT : read mcycle/minstret before and after the measured run of each
//               kernel (Verilator-only runs; Spike counts cycles differently).
//               fyp-notes/csr-deltas.py reads the values from the RTL trace.
#include <stdint.h>

#define N 8
#define EXP_SUM  157
#define EXP_WSUM 725
#define EXP_C00  2

static int8_t  a8[N][N],  b8[N][N];  static int32_t c8[N][N];
static int16_t a16[N][N], b16[N][N]; static int32_t c16[N][N];
static float   a32[N][N], b32[N][N]; static float   c32[N][N];
static double  a64[N][N], b64[N][N]; static double  c64[N][N];

volatile uint64_t fyp_stats[4][2];   // cycles, instret per type (also visible in memory)

static inline uint64_t rd_cycle(void) {
#ifdef FYP_COUNT
  uint64_t x; __asm__ volatile ("csrr %0, mcycle" : "=r"(x) :: "memory"); return x;
#else
  return 0;
#endif
}
static inline uint64_t rd_instret(void) {
#ifdef FYP_COUNT
  uint64_t x; __asm__ volatile ("csrr %0, minstret" : "=r"(x) :: "memory"); return x;
#else
  return 0;
#endif
}

static void init(void) {
  for (int i = 0; i < N; i++)
    for (int j = 0; j < N; j++) {
      int va = ((i * 7 + j * 3) % 15) - 7;   // -7..7
      int vb = ((i * 5 + j * 11) % 13) - 6;  // -6..6
      a8[i][j]  = (int8_t)va;  b8[i][j]  = (int8_t)vb;
      a16[i][j] = (int16_t)va; b16[i][j] = (int16_t)vb;
      a32[i][j] = (float)va;   b32[i][j] = (float)vb;
      a64[i][j] = (double)va;  b64[i][j] = (double)vb;
    }
}

#define MATMUL(name, TA, TC)                                         \
  __attribute__((noinline)) static void name(TA a[N][N], TA b[N][N], \
                                             TC c[N][N]) {           \
    for (int i = 0; i < N; i++)                                      \
      for (int j = 0; j < N; j++) {                                  \
        TC acc = 0;                                                  \
        for (int k = 0; k < N; k++) acc += (TC)a[i][k] * (TC)b[k][j];\
        c[i][j] = acc;                                               \
      }                                                              \
  }
MATMUL(mm_i8,  int8_t,  int32_t)
MATMUL(mm_i16, int16_t, int32_t)
MATMUL(mm_f32, float,   float)
MATMUL(mm_f64, double,  double)

// Run once to warm the caches, measure the second run, then check the result.
#define RUN(t, fn, a, b, c)                                                \
  do {                                                                     \
    fn(a, b, c);                                                           \
    uint64_t c0 = rd_cycle(), i0 = rd_instret();                           \
    fn(a, b, c);                                                           \
    uint64_t c1 = rd_cycle(), i1 = rd_instret();                           \
    fyp_stats[t - 1][0] = c1 - c0;                                         \
    fyp_stats[t - 1][1] = i1 - i0;                                         \
    long s = 0, w = 0;                                                     \
    for (int i = 0; i < N; i++)                                            \
      for (int j = 0; j < N; j++) {                                        \
        long v = (long)c[i][j];                                            \
        s += v; w += v * (i * N + j + 1);                                  \
      }                                                                    \
    if (s != EXP_SUM)              return 10 * t + 1;                      \
    if (w != EXP_WSUM)             return 10 * t + 2;                      \
    if ((long)c[0][0] != EXP_C00)  return 10 * t + 3;                      \
  } while (0)

int main(void) {
  init();
  RUN(1, mm_i8,  a8,  b8,  c8);
  RUN(2, mm_i16, a16, b16, c16);
  RUN(3, mm_f32, a32, b32, c32);
  RUN(4, mm_f64, a64, b64, c64);
  return 0;
}
