#define GLFW_EXPOSE_NATIVE_WIN32
#include <GLFW/glfw3.h>
#include <GLFW/glfw3native.h>
#include <windows.h>
#include <imm.h>

#include <stddef.h>
#include <stdlib.h>

typedef void (*bracke_ime_text_callback)(const char *text);

static HWND ime_window;
static WNDPROC previous_proc;
static bracke_ime_text_callback ime_commit;
static bracke_ime_text_callback ime_preedit;

static char *bracke_utf8(const WCHAR *text, int units)
{
    int bytes;
    char *result;

    if (text == NULL || units <= 0) {
        result = (char *)malloc(1U);
        if (result != NULL) {
            result[0] = '\0';
        }
        return result;
    }
    bytes = WideCharToMultiByte(CP_UTF8, 0, text, units, NULL, 0, NULL, NULL);
    if (bytes <= 0) {
        return NULL;
    }
    result = (char *)malloc((size_t)bytes + 1U);
    if (result != NULL) {
        (void)WideCharToMultiByte(CP_UTF8, 0, text, units, result, bytes,
                                  NULL, NULL);
        result[bytes] = '\0';
    }
    return result;
}

static void bracke_read_composition(LPARAM lparam)
{
    HIMC context = ImmGetContext(ime_window);
    LONG bytes;
    WCHAR *wide;
    char *utf8;
    DWORD kind;
    bracke_ime_text_callback callback;

    if (context == NULL) {
        return;
    }
    kind = (lparam & GCS_RESULTSTR) != 0 ? GCS_RESULTSTR : GCS_COMPSTR;
    callback = kind == GCS_RESULTSTR ? ime_commit : ime_preedit;
    bytes = ImmGetCompositionStringW(context, kind, NULL, 0);
    if (bytes >= 0 && callback != NULL) {
        wide = (WCHAR *)malloc((size_t)bytes + sizeof(WCHAR));
        if (wide != NULL) {
            if (bytes > 0) {
                (void)ImmGetCompositionStringW(context, kind, wide,
                                               (DWORD)bytes);
            }
            wide[bytes / (LONG)sizeof(WCHAR)] = L'\0';
            utf8 = bracke_utf8(wide, bytes / (LONG)sizeof(WCHAR));
            if (utf8 != NULL) {
                callback(utf8);
                free(utf8);
            }
            free(wide);
        }
    }
    ImmReleaseContext(ime_window, context);
}

static LRESULT CALLBACK bracke_ime_window_proc(HWND hwnd, UINT message,
                                                WPARAM wparam, LPARAM lparam)
{
    switch (message) {
    case WM_IME_STARTCOMPOSITION:
        if (ime_preedit != NULL) {
            ime_preedit("");
        }
        break;
    case WM_IME_COMPOSITION:
        bracke_read_composition(lparam);
        if ((lparam & GCS_RESULTSTR) != 0) {
            return 0;
        }
        break;
    case WM_IME_ENDCOMPOSITION:
        if (ime_preedit != NULL) {
            ime_preedit("");
        }
        break;
    default:
        break;
    }
    return CallWindowProcW(previous_proc, hwnd, message, wparam, lparam);
}

int bracke_ime_initialize(void *window, bracke_ime_text_callback commit,
                          bracke_ime_text_callback preedit)
{
    GLFWwindow *glfw_window = (GLFWwindow *)window;
    LONG_PTR old_proc;

    if (glfw_window == NULL) {
        return -1;
    }
    ime_window = glfwGetWin32Window(glfw_window);
    if (ime_window == NULL) {
        return -1;
    }
    ime_commit = commit;
    ime_preedit = preedit;
    SetLastError(0);
    old_proc = SetWindowLongPtrW(ime_window, GWLP_WNDPROC,
                                 (LONG_PTR)bracke_ime_window_proc);
    if (old_proc == 0 && GetLastError() != 0) {
        ime_window = NULL;
        ime_commit = NULL;
        ime_preedit = NULL;
        return 0;
    }
    previous_proc = (WNDPROC)old_proc;
    return 1;
}

void bracke_ime_finalize(void)
{
    if (ime_window != NULL && previous_proc != NULL) {
        (void)SetWindowLongPtrW(ime_window, GWLP_WNDPROC,
                                (LONG_PTR)previous_proc);
    }
    ime_window = NULL;
    previous_proc = NULL;
    ime_commit = NULL;
    ime_preedit = NULL;
}

int bracke_ime_process_key(int scancode, int action, int modifiers)
{
    (void)scancode;
    (void)action;
    (void)modifiers;
    return 0;
}

void bracke_ime_set_focused(int focused)
{
    /* Windows activates the window's input context as focus changes.  Do not
       alter ImmGetOpenStatus here: that is a persistent user choice. */
    (void)focused;
}

void bracke_ime_set_cursor(int x, int y, int width, int height)
{
    HIMC context;
    COMPOSITIONFORM composition;
    CANDIDATEFORM candidate;

    (void)width;
    if (ime_window == NULL) {
        return;
    }
    context = ImmGetContext(ime_window);
    if (context == NULL) {
        return;
    }
    composition.dwStyle = CFS_POINT;
    composition.ptCurrentPos.x = x;
    composition.ptCurrentPos.y = y + height;
    composition.rcArea.left = x;
    composition.rcArea.top = y;
    composition.rcArea.right = x + width;
    composition.rcArea.bottom = y + height;
    (void)ImmSetCompositionWindow(context, &composition);
    candidate.dwIndex = 0;
    candidate.dwStyle = CFS_CANDIDATEPOS;
    candidate.ptCurrentPos.x = x;
    candidate.ptCurrentPos.y = y + height;
    candidate.rcArea = composition.rcArea;
    (void)ImmSetCandidateWindow(context, &candidate);
    ImmReleaseContext(ime_window, context);
}
