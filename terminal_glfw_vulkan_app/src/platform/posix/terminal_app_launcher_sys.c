#include <errno.h>
#include <signal.h>
#include <spawn.h>
#include <sys/types.h>
#include <sys/wait.h>

/* Publish either a valid spawned PID or zero before returning to cancellable
   Ada code. POSIX leaves the pid output unspecified when posix_spawnp fails. */
int terminal_app_launcher_spawn
  (int *process,
   const char *path,
   const posix_spawn_file_actions_t *file_actions,
   const posix_spawnattr_t *attributes,
   char *const arguments[],
   char *const environment[])
{
   pid_t child = 0;
   int result = posix_spawnp
     (&child, path, file_actions, attributes, arguments, environment);
   *process = result == 0 ? (int) child : 0;
   return result;
}

int terminal_app_launcher_poll_child(int process, int *error_code)
{
   int status;
   pid_t result;

   *error_code = 0;
   do {
      result = waitpid((pid_t) process, &status, WNOHANG);
   } while (result < 0 && errno == EINTR);

   if (result == 0) {
      return 0;
   }
   if (result == (pid_t) process || (result < 0 && errno == ECHILD)) {
      return 1;
   }
   if (result < 0) {
      *error_code = errno;
   }
   return 2;
}

/* Last-resort ownership sink when the Ada tracker cannot retain a child. */
void terminal_app_launcher_dispose_child(int process)
{
   int status;
   pid_t result;

   if (process <= 0) {
      return;
   }
   kill((pid_t) process, SIGKILL);
   do {
      result = waitpid((pid_t) process, &status, 0);
   } while (result < 0 && errno == EINTR);
}
