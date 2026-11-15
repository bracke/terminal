#if defined(__linux__) && !defined(_GNU_SOURCE)
#define _GNU_SOURCE
#endif

#include "terminal_pty_posix_internal.h"

#include <stddef.h>
#include <errno.h>
#include <fcntl.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

#if defined(__APPLE__)
#include <sys/sysctl.h>
#endif

struct terminal_pty_environment {
   char **values;
   size_t count;
   size_t capacity;
};

static char *terminal_pty_copy_string (const char *value)
{
   size_t length = strlen (value) + 1;
   char *copy = (char *) malloc (length);
   if (copy != NULL) {
      memcpy (copy, value, length);
   }
   return copy;
}

static int terminal_pty_replaced_environment_name (const char *value)
{
   return strncmp (value, "TERM=", 5) == 0
       || strncmp (value, "COLORTERM=", 10) == 0
       || strncmp (value, "TERM_PROGRAM=", 13) == 0
       || strncmp (value, "TERM_PROGRAM_VERSION=", 21) == 0
       || strncmp (value, "TERM_FEATURES=", 14) == 0;
}

static int terminal_pty_reserve_environment
  (struct terminal_pty_environment *environment, size_t needed)
{
   size_t capacity;
   char **replacement;

   if (needed <= environment->capacity) {
      return 0;
   }
   capacity = environment->capacity != 0 ? environment->capacity : 16;
   while (capacity < needed) {
      if (capacity > (size_t) -1 / 2) {
         errno = ENOMEM;
         return -1;
      }
      capacity *= 2;
   }
   if (capacity > (size_t) -1 / sizeof *environment->values) {
      errno = ENOMEM;
      return -1;
   }
   replacement = (char **) realloc
     (environment->values, capacity * sizeof *environment->values);
   if (replacement == NULL) {
      return -1;
   }
   environment->values = replacement;
   environment->capacity = capacity;
   return 0;
}

static int terminal_pty_append_environment
  (struct terminal_pty_environment *environment, const char *value)
{
   char *copy;

   if (environment->count == (size_t) -1
       || terminal_pty_reserve_environment
            (environment, environment->count + 1) != 0) {
      errno = ENOMEM;
      return -1;
   }
   copy = terminal_pty_copy_string(value);
   if (copy == NULL) {
      return -1;
   }
   environment->values[environment->count++] = copy;
   return 0;
}

void terminal_pty_free_environment (void *storage)
{
   struct terminal_pty_environment *environment =
      (struct terminal_pty_environment *) storage;
   size_t index;

   if (environment == NULL) {
      return;
   }
   for (index = 0; index < environment->count; ++index) {
      free (environment->values[index]);
   }
   free (environment->values);
   free (environment);
}

static int terminal_pty_finish_environment
  (struct terminal_pty_environment *environment)
{
   if (environment->count == (size_t) -1
       || terminal_pty_reserve_environment
            (environment, environment->count + 1) != 0) {
      return -1;
   }
   environment->values[environment->count] = NULL;
   return 0;
}

static struct terminal_pty_environment *terminal_pty_environment_from_block
  (const char *block, size_t size, size_t start)
{
   struct terminal_pty_environment *result;
   size_t source = start;

   result = (struct terminal_pty_environment *) calloc (1, sizeof *result);
   if (result == NULL) {
      return NULL;
   }
   while (source < size) {
      const char *value = block + source;
      const char *end = (const char *) memchr(value, '\0', size - source);
      size_t length;

      if (end == NULL) {
         terminal_pty_free_environment(result);
         errno = EINVAL;
         return NULL;
      }
      length = (size_t) (end - value);
      source += length + 1;
      if (length == 0 || memchr(value, '=', length) == NULL) {
         continue;
      }
      if (terminal_pty_append_environment(result, value) != 0) {
         terminal_pty_free_environment(result);
         return NULL;
      }
   }
   if (terminal_pty_finish_environment(result) != 0) {
      terminal_pty_free_environment(result);
      return NULL;
   }
   return result;
}

#if defined(__linux__)
static void *terminal_pty_copy_startup_environment (void)
{
   size_t capacity = 4096;
   size_t length = 0;
   char *block;
   int descriptor;
   struct terminal_pty_environment *result;

   descriptor = open("/proc/self/environ", O_RDONLY | O_CLOEXEC);
   if (descriptor < 0) {
      return NULL;
   }
   block = (char *) malloc(capacity + 1);
   if (block == NULL) {
      close(descriptor);
      return NULL;
   }
   for (;;) {
      ssize_t count;
      if (length == capacity) {
         char *replacement;
         if (capacity > ((size_t) -1 - 1) / 2) {
            free(block);
            close(descriptor);
            errno = ENOMEM;
            return NULL;
         }
         capacity *= 2;
         replacement = (char *) realloc(block, capacity + 1);
         if (replacement == NULL) {
            free(block);
            close(descriptor);
            return NULL;
         }
         block = replacement;
      }
      count = read(descriptor, block + length, capacity - length);
      if (count < 0 && errno == EINTR) {
         continue;
      }
      if (count < 0) {
         int saved_error = errno;
         free(block);
         close(descriptor);
         errno = saved_error;
         return NULL;
      }
      if (count == 0) {
         break;
      }
      length += (size_t) count;
   }
   close(descriptor);
   if (length == 0 || block[length - 1] != '\0') {
      block[length++] = '\0';
   }
   result = terminal_pty_environment_from_block(block, length, 0);
   free(block);
   return result;
}
#elif defined(__APPLE__)
static void *terminal_pty_copy_startup_environment (void)
{
   int request[3] = {CTL_KERN, KERN_PROCARGS2, getpid()};
   size_t size = 0;
   size_t cursor;
   char *block;
   int argument_count;
   int argument;
   struct terminal_pty_environment *result;

   if (sysctl(request, 3, NULL, &size, NULL, 0) != 0
       || size < sizeof argument_count) {
      return NULL;
   }
   block = (char *) malloc(size + 1);
   if (block == NULL) {
      return NULL;
   }
   if (sysctl(request, 3, block, &size, NULL, 0) != 0) {
      int saved_error = errno;
      free(block);
      errno = saved_error;
      return NULL;
   }
   block[size] = '\0';
   memcpy(&argument_count, block, sizeof argument_count);
   if (argument_count < 0) {
      free(block);
      errno = EINVAL;
      return NULL;
   }
   cursor = sizeof argument_count;
   while (cursor < size && block[cursor] != '\0') {
      ++cursor;
   }
   while (cursor < size && block[cursor] == '\0') {
      ++cursor;
   }
   for (argument = 0; argument < argument_count; ++argument) {
      while (cursor < size && block[cursor] != '\0') {
         ++cursor;
      }
      if (cursor < size) {
         ++cursor;
      }
   }
   result = terminal_pty_environment_from_block(block, size + 1, cursor);
   free(block);
   return result;
}
#else
static void *terminal_pty_copy_startup_environment (void)
{
   errno = ENOTSUP;
   return NULL;
}
#endif

int terminal_pty_capture_environment_owned (void **target)
{
   void *result = terminal_pty_copy_startup_environment();
   *target = result;
   return result != NULL ? 0 : -1;
}

const char *terminal_pty_environment_value
  (void *storage, const char *name)
{
   struct terminal_pty_environment *environment =
      (struct terminal_pty_environment *) storage;
   size_t name_length;
   size_t index;

   if (environment == NULL || name == NULL) {
      return NULL;
   }
   name_length = strlen(name);
   for (index = 0; index < environment->count; ++index) {
      const char *value = environment->values[index];
      if (strncmp(value, name, name_length) == 0
          && value[name_length] == '=') {
         return value + name_length + 1;
      }
   }
   return NULL;
}

/* Replace the terminal-owned variables in a private copy. The child only
   dereferences this immutable allocation before calling execve. */
void *terminal_pty_build_environment
  (void *base_storage,
   const char *term,
   const char *color_term,
   const char *term_program,
   const char *term_program_version,
   const char *term_features)
{
   const char *replacements[5] =
      {term, color_term, term_program, term_program_version, term_features};
   struct terminal_pty_environment *base =
      (struct terminal_pty_environment *) base_storage;
   struct terminal_pty_environment *result;
   size_t source;

   if (base == NULL) {
      errno = EINVAL;
      return NULL;
   }
   result = (struct terminal_pty_environment *) calloc (1, sizeof *result);
   if (result == NULL) {
      return NULL;
   }
   for (source = 0; source < base->count; ++source) {
      const char *value = base->values[source];
      if (!terminal_pty_replaced_environment_name (value)) {
         if (terminal_pty_append_environment
               (result, value) != 0) {
            terminal_pty_free_environment (result);
            return NULL;
         }
      }
   }
   for (source = 0; source < 5; ++source) {
      if (terminal_pty_append_environment
            (result, replacements[source]) != 0) {
         terminal_pty_free_environment (result);
         return NULL;
      }
   }
   if (terminal_pty_finish_environment(result) != 0) {
      terminal_pty_free_environment(result);
      return NULL;
   }
   return result;
}

int terminal_pty_build_environment_owned
  (void **target,
   void *base_storage,
   const char *term,
   const char *color_term,
   const char *term_program,
   const char *term_program_version,
   const char *term_features)
{
   void *result = terminal_pty_build_environment
     (base_storage, term, color_term, term_program, term_program_version,
      term_features);
   *target = result;
   return result != NULL ? 0 : -1;
}

int terminal_pty_exec_with_environment
  (const char *path, char *const argv[], void *storage)
{
   struct terminal_pty_environment *environment =
      (struct terminal_pty_environment *) storage;
   return execve (path, argv, environment->values);
}
