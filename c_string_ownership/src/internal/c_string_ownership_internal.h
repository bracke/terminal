#ifndef C_STRING_OWNERSHIP_INTERNAL_H
#define C_STRING_OWNERSHIP_INTERNAL_H

#include <stddef.h>

/* PE objects have no ELF visibility; GCC warns there (an error under
   -Werror). Unexported symbols stay internal to the DLL there anyway. */
#if defined(__GNUC__) && !defined(_WIN32)
# define C_STRING_OWNERSHIP_INTERNAL __attribute__((visibility("hidden")))
#else
# define C_STRING_OWNERSHIP_INTERNAL
#endif

C_STRING_OWNERSHIP_INTERNAL
int c_string_ownership_allocate_owned
  (char **target, const char *source, size_t length);
C_STRING_OWNERSHIP_INTERNAL
char *c_string_ownership_consume_owned(char **target);
C_STRING_OWNERSHIP_INTERNAL
void c_string_ownership_free_owned(char **target);

#endif
