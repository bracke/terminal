#include <GLFW/glfw3.h>

typedef void (*bracke_path_callback)(const char *path);

static bracke_path_callback bracke_drop_target;

static void bracke_drop_callback(GLFWwindow *window, int count,
                                 const char **paths) {
    int index;
    (void)window;
    if (bracke_drop_target == NULL || paths == NULL || count <= 0) {
        return;
    }
    for (index = 0; index < count; ++index) {
        if (paths[index] != NULL) {
            bracke_drop_target(paths[index]);
        }
    }
}

void bracke_file_drop_install(GLFWwindow *window,
                              bracke_path_callback callback) {
    bracke_drop_target = callback;
    glfwSetDropCallback(window, callback == NULL ? NULL : bracke_drop_callback);
}

void bracke_file_drop_uninstall(GLFWwindow *window) {
    glfwSetDropCallback(window, NULL);
    bracke_drop_target = NULL;
}
