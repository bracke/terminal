#include "internal/c_string_ownership_internal.h"

#include <stdint.h>
#include <stdlib.h>
#include <string.h>

/* Publish ownership before returning across a cancellable Ada call boundary. */
int c_string_ownership_allocate_owned
  (char **target, const char *source, size_t length)
{
   char *result;

   *target = NULL;
   if (length == SIZE_MAX) {
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
   *target = result;
   return 1;
}

char *c_string_ownership_consume_owned(char **target)
{
   char *owned = *target;

   *target = NULL;
   return owned;
}

/* Consume the marker before freeing so cancellation cannot cause a retry. */
void c_string_ownership_free_owned(char **target)
{
   free(c_string_ownership_consume_owned(target));
}
