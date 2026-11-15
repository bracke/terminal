#include "terminal_pty_windows_internal.h"

#include <stdint.h>
#include <stdlib.h>
#include <string.h>

static int terminal_pty_replaced_environment_name(const char *value)
{
   return _strnicmp(value, "TERM=", 5) == 0
       || _strnicmp(value, "COLORTERM=", 10) == 0
       || _strnicmp(value, "TERM_PROGRAM=", 13) == 0
       || _strnicmp(value, "TERM_PROGRAM_VERSION=", 21) == 0
       || _strnicmp(value, "TERM_FEATURES=", 14) == 0;
}

static int terminal_pty_compare_environment_entries
  (const void *left, const void *right)
{
   const char *const *left_entry = (const char *const *) left;
   const char *const *right_entry = (const char *const *) right;
   return _stricmp(*left_entry, *right_entry);
}

/* Build a sorted ANSI environment block for one child without changing the
   process-global environment. The returned block is owned by the caller. */
void *terminal_pty_build_windows_environment
  (const char *term,
   const char *color_term,
   const char *term_program,
   const char *term_program_version,
   const char *term_features)
{
   const char *replacements[5] =
      {term, color_term, term_program, term_program_version, term_features};
   LPCH inherited = GetEnvironmentStringsA();
   const char *entry;
   const char **entries = NULL;
   char *result = NULL;
   char *target;
   size_t retained = 0;
   size_t count;
   size_t index;
   size_t total = 1;

   if (inherited == NULL) {
      return NULL;
   }
   for (entry = inherited; *entry != '\0'; entry += strlen(entry) + 1) {
      if (!terminal_pty_replaced_environment_name(entry)) {
         ++retained;
      }
   }
   if (retained > SIZE_MAX - 5
       || retained + 5 > SIZE_MAX / sizeof *entries) {
      FreeEnvironmentStringsA(inherited);
      return NULL;
   }
   count = retained + 5;
   entries = (const char **) calloc(count, sizeof *entries);
   if (entries == NULL) {
      FreeEnvironmentStringsA(inherited);
      return NULL;
   }

   index = 0;
   for (entry = inherited; *entry != '\0'; entry += strlen(entry) + 1) {
      if (!terminal_pty_replaced_environment_name(entry)) {
         entries[index++] = entry;
      }
   }
   for (size_t replacement = 0; replacement < 5; ++replacement) {
      entries[index++] = replacements[replacement];
   }
   qsort(entries, count, sizeof *entries,
         terminal_pty_compare_environment_entries);

   for (index = 0; index < count; ++index) {
      size_t length = strlen(entries[index]) + 1;
      if (length > SIZE_MAX - total) {
         free(entries);
         FreeEnvironmentStringsA(inherited);
         return NULL;
      }
      total += length;
   }
   result = (char *) malloc(total);
   if (result == NULL) {
      free(entries);
      FreeEnvironmentStringsA(inherited);
      return NULL;
   }
   target = result;
   for (index = 0; index < count; ++index) {
      size_t length = strlen(entries[index]) + 1;
      memcpy(target, entries[index], length);
      target += length;
   }
   *target = '\0';

   free(entries);
   FreeEnvironmentStringsA(inherited);
   return result;
}

void terminal_pty_free_windows_environment(void *environment)
{
   free(environment);
}

void terminal_pty_free_windows_environment_owned(void **target)
{
   void *owned = *target;
   *target = NULL;
   terminal_pty_free_windows_environment(owned);
}

int terminal_pty_build_windows_environment_owned
  (void **target,
   const char *term,
   const char *color_term,
   const char *term_program,
   const char *term_program_version,
   const char *term_features)
{
   void *result = terminal_pty_build_windows_environment
     (term, color_term, term_program, term_program_version, term_features);
   *target = result;
   return result != NULL;
}
