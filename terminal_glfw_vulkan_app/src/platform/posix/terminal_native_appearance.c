#if defined(__linux__) && !defined(__APPLE__)
#define GLFW_EXPOSE_NATIVE_X11
#include <GLFW/glfw3.h>
#include <GLFW/glfw3native.h>
#include <X11/Xatom.h>
#include <X11/Xlib.h>

int terminal_native_set_background_blur(void *window_handle, int enabled)
{
    GLFWwindow *glfw_window = (GLFWwindow *)window_handle;
    Display *display;
    Window window;
    Atom property;

    if (glfw_window == NULL) {
        return 2;
    }
    display = glfwGetX11Display();
    window = glfwGetX11Window(glfw_window);
    if (display == NULL || window == 0) {
        return 1;
    }
    property = XInternAtom(display, "_KDE_NET_WM_BLUR_BEHIND_REGION", False);
    if (property == None) {
        return 3;
    }
    if (enabled != 0) {
        /* An empty region requests blur behind the complete window. */
        XChangeProperty(display, window, property, XA_CARDINAL, 32,
                        PropModeReplace, NULL, 0);
    } else {
        XDeleteProperty(display, window, property);
    }
    XFlush(display);
    return 0;
}
#else
int terminal_native_set_background_blur(void *window_handle, int enabled)
{
    (void)enabled;
    return window_handle == 0 ? 2 : 1;
}
#endif
