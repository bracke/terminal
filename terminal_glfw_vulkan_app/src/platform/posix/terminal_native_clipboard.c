#define _POSIX_C_SOURCE 200809L

#include <errno.h>
#include <poll.h>
#include <signal.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/socket.h>
#include <sys/types.h>
#include <sys/wait.h>
#include <time.h>
#include <unistd.h>

enum clipboard_backend {
    CLIPBOARD_NONE = 0,
    CLIPBOARD_WAYLAND = 1,
    CLIPBOARD_X11 = 2
};

static int executable_in_path(const char *name)
{
    const char *path = getenv("PATH");
    const size_t name_length = strlen(name);

    if (path == NULL || name_length == 0U) {
        return 0;
    }

    while (*path != '\0') {
        const char *end = strchr(path, ':');
        const size_t directory_length =
            end == NULL ? strlen(path) : (size_t)(end - path);
        char candidate[4096];
        const char *directory = path;
        size_t used = directory_length;

        if (directory_length == 0U) {
            directory = ".";
            used = 1U;
        }
        if (used + 1U + name_length + 1U <= sizeof(candidate)) {
            memcpy(candidate, directory, used);
            candidate[used] = '/';
            memcpy(candidate + used + 1U, name, name_length + 1U);
            if (access(candidate, X_OK) == 0) {
                return 1;
            }
        }
        if (end == NULL) {
            break;
        }
        path = end + 1;
    }
    return 0;
}

static enum clipboard_backend active_backend(void)
{
    const char *disabled = getenv("TERMINAL_DISABLE_NATIVE_PRIMARY");
    const char *wayland = getenv("WAYLAND_DISPLAY");
    const char *x11 = getenv("DISPLAY");

    if (disabled != NULL && *disabled != '\0') {
        return CLIPBOARD_NONE;
    }
    if (wayland != NULL && *wayland != '\0' &&
        executable_in_path("wl-copy") && executable_in_path("wl-paste")) {
        return CLIPBOARD_WAYLAND;
    }
    if (x11 != NULL && *x11 != '\0' && executable_in_path("xsel")) {
        return CLIPBOARD_X11;
    }
    return CLIPBOARD_NONE;
}

static int wait_bounded(pid_t child)
{
    struct timespec pause_time = {0, 10000000L};
    unsigned int attempts;

    for (attempts = 0U; attempts < 200U; ++attempts) {
        int status = 0;
        const pid_t result = waitpid(child, &status, WNOHANG);
        if (result == child) {
            return WIFEXITED(status) && WEXITSTATUS(status) == 0;
        }
        if (result < 0 && errno != EINTR) {
            return 0;
        }
        (void)nanosleep(&pause_time, NULL);
    }
    (void)kill(child, SIGKILL);
    (void)waitpid(child, NULL, 0);
    return 0;
}

int terminal_primary_clipboard_available(void)
{
    return active_backend() != CLIPBOARD_NONE;
}

int terminal_primary_clipboard_set(const uint8_t *data, size_t length)
{
    const enum clipboard_backend backend = active_backend();
    int sockets[2];
    pid_t child;
    size_t offset = 0U;

    if (backend == CLIPBOARD_NONE || (length > 0U && data == NULL) ||
        socketpair(AF_UNIX, SOCK_STREAM, 0, sockets) != 0) {
        return 0;
    }

    child = fork();
    if (child < 0) {
        (void)close(sockets[0]);
        (void)close(sockets[1]);
        return 0;
    }
    if (child == 0) {
        (void)close(sockets[0]);
        if (dup2(sockets[1], STDIN_FILENO) < 0) {
            _exit(126);
        }
        (void)close(sockets[1]);
        if (backend == CLIPBOARD_WAYLAND) {
            execlp("wl-copy", "wl-copy", "--primary", (char *)NULL);
        } else {
            execlp("xsel", "xsel", "--primary", "--input", (char *)NULL);
        }
        _exit(127);
    }

    (void)close(sockets[1]);
    while (offset < length) {
        const ssize_t written = send(sockets[0], data + offset,
                                     length - offset, MSG_NOSIGNAL);
        if (written > 0) {
            offset += (size_t)written;
        } else if (written < 0 && errno == EINTR) {
            continue;
        } else {
            break;
        }
    }
    (void)shutdown(sockets[0], SHUT_WR);
    (void)close(sockets[0]);
    return offset == length && wait_bounded(child);
}

int terminal_primary_clipboard_get(uint8_t *data, size_t capacity,
                                   size_t *length)
{
    const enum clipboard_backend backend = active_backend();
    int output[2];
    pid_t child;
    size_t used = 0U;
    int truncated = 0;
    int child_ok;

    if (backend == CLIPBOARD_NONE || data == NULL || capacity == 0U ||
        length == NULL || pipe(output) != 0) {
        return 0;
    }
    child = fork();
    if (child < 0) {
        (void)close(output[0]);
        (void)close(output[1]);
        return 0;
    }
    if (child == 0) {
        (void)close(output[0]);
        if (dup2(output[1], STDOUT_FILENO) < 0) {
            _exit(126);
        }
        (void)close(output[1]);
        if (backend == CLIPBOARD_WAYLAND) {
            execlp("wl-paste", "wl-paste", "--primary", "--no-newline",
                   (char *)NULL);
        } else {
            execlp("xsel", "xsel", "--primary", "--output", (char *)NULL);
        }
        _exit(127);
    }

    (void)close(output[1]);
    for (;;) {
        struct pollfd descriptor = {output[0], POLLIN | POLLHUP, 0};
        uint8_t discard[512];
        uint8_t *target = used < capacity ? data + used : discard;
        const size_t available = used < capacity ? capacity - used : sizeof(discard);
        int ready;

        do {
            ready = poll(&descriptor, 1U, 2000);
        } while (ready < 0 && errno == EINTR);
        if (ready <= 0) {
            (void)close(output[0]);
            (void)kill(child, SIGKILL);
            (void)waitpid(child, NULL, 0);
            return 0;
        }

        const ssize_t count = read(output[0], target, available);
        if (count > 0) {
            if (used < capacity) {
                used += (size_t)count;
            } else {
                truncated = 1;
            }
        } else if (count == 0) {
            break;
        } else if (errno != EINTR) {
            (void)close(output[0]);
            (void)kill(child, SIGKILL);
            (void)waitpid(child, NULL, 0);
            return 0;
        }
    }
    (void)close(output[0]);
    child_ok = wait_bounded(child);
    *length = used;
    if (!child_ok) {
        return 0;
    }
    return truncated ? 2 : 1;
}
