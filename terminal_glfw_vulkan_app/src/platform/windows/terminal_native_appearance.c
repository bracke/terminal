#define GLFW_EXPOSE_NATIVE_WIN32
#include <windows.h>
#include <GLFW/glfw3.h>
#include <GLFW/glfw3native.h>

typedef HRESULT (WINAPI *dwm_set_window_attribute_fn)
    (HWND, DWORD, LPCVOID, DWORD);

int terminal_native_set_background_blur(void *window_handle, int enabled)
{
    GLFWwindow *glfw_window = (GLFWwindow *)window_handle;
    HMODULE library;
    dwm_set_window_attribute_fn set_attribute;
    HWND window;
    int backdrop;
    HRESULT result;

    if (glfw_window == NULL) {
        return 2;
    }
    window = glfwGetWin32Window(glfw_window);
    if (window == NULL) {
        return 2;
    }
    library = LoadLibraryW(L"dwmapi.dll");
    if (library == NULL) {
        return 1;
    }
    set_attribute = (dwm_set_window_attribute_fn)(void *)
        GetProcAddress(library, "DwmSetWindowAttribute");
    if (set_attribute == NULL) {
        FreeLibrary(library);
        return 1;
    }
    /* DWMWA_SYSTEMBACKDROP_TYPE (38): 2 is Mica, 1 disables the backdrop. */
    backdrop = enabled != 0 ? 2 : 1;
    result = set_attribute(window, 38U, &backdrop, (DWORD)sizeof(backdrop));
    FreeLibrary(library);
    return SUCCEEDED(result) ? 0 : 3;
}
