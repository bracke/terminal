/* Resolve POSIX constants and descriptor paths through host headers. */

#include <fcntl.h>
#include <limits.h>
#include <stdio.h>
#include <string.h>
#include <sys/mman.h>
#include <sys/types.h>
#include <unistd.h>

int terminal_media_local_file_transfers_available (void)
{
#if defined(__linux__) || defined(__APPLE__)
   return 1;
#else
   return 0;
#endif
}

int terminal_media_open_read_no_follow (const char *path)
{
   return open (path, O_RDONLY | O_NOFOLLOW | O_CLOEXEC);
}

int terminal_media_descriptor_path
  (int fd, char *buffer, size_t capacity)
{
   if (buffer == NULL || capacity == 0) {
      return -1;
   }
#if defined(__APPLE__)
   if (fcntl (fd, F_GETPATH, buffer) != 0) {
      return -1;
   }
   size_t length = strnlen (buffer, capacity);
   return length < capacity ? (int) length : -1;
#elif defined(__linux__)
   char link_path[64];
   int printed = snprintf (link_path, sizeof link_path, "/proc/self/fd/%d", fd);
   if (printed < 0 || (size_t) printed >= sizeof link_path) {
      return -1;
   }
   ssize_t length = readlink (link_path, buffer, capacity - 1);
   if (length < 0 || (size_t) length >= capacity) {
      return -1;
   }
   buffer[length] = '\0';
   return (int) length;
#else
   (void) fd;
   return -1;
#endif
}

int terminal_media_shared_memory_open (const char *name)
{
   return shm_open (name, O_RDONLY, 0);
}

int terminal_media_shared_memory_unlink (const char *name)
{
   return shm_unlink (name);
}

int terminal_media_open_directory_no_follow (const char *path)
{
   return open (path, O_RDONLY | O_DIRECTORY | O_NOFOLLOW | O_CLOEXEC);
}

int terminal_media_open_read_at_no_follow (int directory, const char *name)
{
   return openat (directory, name, O_RDONLY | O_NOFOLLOW | O_CLOEXEC);
}

int terminal_media_create_file_at
  (int directory, const char *name, unsigned int mode)
{
   return openat
     (directory, name,
      O_WRONLY | O_CREAT | O_EXCL | O_NOFOLLOW | O_CLOEXEC,
      (mode_t) mode);
}

long terminal_media_write
  (int fd, const void *buffer, size_t count)
{
   return (long) write (fd, buffer, count);
}

int terminal_media_close (int fd)
{
   return close (fd);
}

int terminal_media_delete_file_at (int directory, const char *name)
{
   return unlinkat (directory, name, 0);
}
