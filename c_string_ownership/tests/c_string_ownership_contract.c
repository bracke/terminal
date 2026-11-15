#include "c_string_ownership_internal.h"

#include <stdint.h>
#include <stdlib.h>

int test_c_string_ownership_contract(void)
{
   static const char source[] = "x";
   char sentinel;
   char *target = &sentinel;
   char *owned;
   int valid;

   if (c_string_ownership_allocate_owned
         (&target, source, SIZE_MAX) != 0 || target != NULL) {
      return 0;
   }
   if (c_string_ownership_allocate_owned(&target, source, 1U) == 0) {
      return 0;
   }
   valid = target != NULL && target[0] == 'x' && target[1] == '\0';
   owned = c_string_ownership_consume_owned(&target);
   valid = valid && target == NULL && owned != NULL;
   free(owned);
   return valid;
}
