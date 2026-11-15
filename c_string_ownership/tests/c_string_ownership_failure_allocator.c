#include <stddef.h>
#include <stdatomic.h>
#include <stdlib.h>
#include <string.h>

enum allocation_mode {
   ALLOCATE_NORMALLY,
   FAIL_WITHOUT_PUBLICATION,
   SUCCEED_WITHOUT_PUBLICATION,
   BLOCK_AFTER_PUBLICATION
};

static atomic_int next_mode = ATOMIC_VAR_INIT(ALLOCATE_NORMALLY);
static atomic_int live_allocations = ATOMIC_VAR_INIT(0);

extern void test_c_string_ownership_notify_allocation_published(void);
extern void test_c_string_ownership_wait_for_allocation_return(void);

void test_c_string_ownership_fail_next_allocation(void)
{
   atomic_store(&next_mode, FAIL_WITHOUT_PUBLICATION);
}

void test_c_string_ownership_break_next_publication(void)
{
   atomic_store(&next_mode, SUCCEED_WITHOUT_PUBLICATION);
}

void test_c_string_ownership_block_next_allocation(void)
{
   atomic_store(&next_mode, BLOCK_AFTER_PUBLICATION);
}

int test_c_string_ownership_live_allocation_count(void)
{
   return atomic_load(&live_allocations);
}

int c_string_ownership_allocate_owned
  (char **target, const char *source, size_t length)
{
   enum allocation_mode mode = (enum allocation_mode)
     atomic_exchange(&next_mode, ALLOCATE_NORMALLY);
   char *result;

   *target = NULL;
   if (mode == FAIL_WITHOUT_PUBLICATION) {
      return 0;
   }
   if (mode == SUCCEED_WITHOUT_PUBLICATION) {
      return 1;
   }
   if (length == (size_t) -1) {
      return 0;
   }
   result = (char *) malloc(length + 1U);
   if (result == NULL) {
      return 0;
   }
   if (length > 0U) {
      memcpy(result, source, length);
   }
   result[length] = '\0';
   atomic_fetch_add(&live_allocations, 1);
   *target = result;
   if (mode == BLOCK_AFTER_PUBLICATION) {
      test_c_string_ownership_notify_allocation_published();
      test_c_string_ownership_wait_for_allocation_return();
   }
   return 1;
}

void c_string_ownership_free_owned(char **target)
{
   char *owned = *target;

   *target = NULL;
   if (owned != NULL) {
      atomic_fetch_sub(&live_allocations, 1);
   }
   free(owned);
}
