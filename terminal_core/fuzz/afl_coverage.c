#include <stdint.h>
#include <stdlib.h>
#include <sys/shm.h>

/* AFL++'s default map is 64 KiB.  The target is process-per-testcase, so the
 * previous-location state naturally resets for every input.  This adapter is
 * compiled without sanitizer coverage while GNAT compiles the Ada core with
 * -fsanitize-coverage=trace-pc. */
#define AFL_MAP_SIZE 65536u

static unsigned char *afl_area;
static uintptr_t previous_location;
static int setup_attempted;

static void attach_afl_map(void) {
  const char *identity;
  char *end;
  long shared_memory_id;
  void *mapping;

  if (setup_attempted) {
    return;
  }
  setup_attempted = 1;
  identity = getenv("__AFL_SHM_ID");
  if (identity == NULL || *identity == '\0') {
    return;
  }
  shared_memory_id = strtol(identity, &end, 10);
  if (*end != '\0' || shared_memory_id < 0) {
    return;
  }
  mapping = shmat((int)shared_memory_id, NULL, 0);
  if (mapping != (void *)-1) {
    afl_area = (unsigned char *)mapping;
  }
}

void __sanitizer_cov_trace_pc(void) {
  uintptr_t location;
  uintptr_t edge;

  if (afl_area == NULL) {
    attach_afl_map();
    if (afl_area == NULL) {
      return;
    }
  }
  location = ((uintptr_t)__builtin_return_address(0) >> 4u) &
             (AFL_MAP_SIZE - 1u);
  edge = (location ^ previous_location) & (AFL_MAP_SIZE - 1u);
  afl_area[edge]++;
  previous_location = location >> 1u;
}
