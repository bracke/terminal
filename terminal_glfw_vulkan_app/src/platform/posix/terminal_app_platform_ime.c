/* The X input method exists only where GLFW runs on X11; other POSIX hosts
   (macOS) get the stubs at the end, which report no input method. */
#if defined(__linux__) && !defined(__APPLE__)
#define GLFW_EXPOSE_NATIVE_X11
#include <GLFW/glfw3.h>
#include <GLFW/glfw3native.h>
#include <X11/Xlib.h>
#include <X11/Xutil.h>

#include <stddef.h>
#include <stdlib.h>
#include <string.h>
#include <wchar.h>

typedef void (*bracke_ime_text_callback)(const char *text);

static Display *ime_display;
static Window ime_window;
static XIM ime_method;
static XIC ime_context;
static bracke_ime_text_callback ime_commit;
static bracke_ime_text_callback ime_preedit_callback;
static char ime_preedit[1024];
static size_t ime_preedit_length;

static size_t bracke_ime_utf8_offset(const char *text, size_t length,
                                     size_t characters)
{
    size_t offset = 0U;
    size_t count = 0U;
    while (offset < length && count < characters) {
        unsigned char byte = (unsigned char)text[offset++];
        if (byte >= 0xc2U && byte <= 0xdfU && offset < length) {
            offset += 1U;
        } else if (byte >= 0xe0U && byte <= 0xefU && offset + 1U < length) {
            offset += 2U;
        } else if (byte >= 0xf0U && byte <= 0xf4U && offset + 2U < length) {
            offset += 3U;
        }
        ++count;
    }
    return offset > length ? length : offset;
}

static int bracke_ime_preedit_start(XIC context, XPointer client,
                                    XPointer call_data)
{
    (void)context;
    (void)client;
    (void)call_data;
    ime_preedit_length = 0U;
    ime_preedit[0] = '\0';
    if (ime_preedit_callback != NULL) {
        ime_preedit_callback(ime_preedit);
    }
    return (int)(sizeof ime_preedit - 1U);
}

static void bracke_ime_preedit_done(XIC context, XPointer client,
                                    XPointer call_data)
{
    (void)context;
    (void)client;
    (void)call_data;
    ime_preedit_length = 0U;
    ime_preedit[0] = '\0';
    if (ime_preedit_callback != NULL) {
        ime_preedit_callback(ime_preedit);
    }
}

static void bracke_ime_preedit_draw(XIC context, XPointer client,
                                    XPointer call_data)
{
    XIMPreeditDrawCallbackStruct *draw =
        (XIMPreeditDrawCallbackStruct *)call_data;
    size_t first;
    size_t removed;
    const char *insert = "";
    size_t inserted = 0U;
    char converted[sizeof ime_preedit];

    (void)context;
    (void)client;
    if (draw == NULL) {
        return;
    }

    first = bracke_ime_utf8_offset
      (ime_preedit, ime_preedit_length,
       draw->chg_first < 0 ? 0U : (size_t)draw->chg_first);
    removed = bracke_ime_utf8_offset
      (ime_preedit, ime_preedit_length,
       (draw->chg_first < 0 ? 0U : (size_t)draw->chg_first) +
       (draw->chg_length < 0 ? 0U : (size_t)draw->chg_length)) - first;
    if (draw->text != NULL && draw->text->length > 0 &&
        !draw->text->encoding_is_wchar && draw->text->string.multi_byte != NULL) {
        insert = draw->text->string.multi_byte;
        inserted = (size_t)draw->text->length;
    } else if (draw->text != NULL && draw->text->length > 0 &&
               draw->text->encoding_is_wchar &&
               draw->text->string.wide_char != NULL) {
        wchar_t wide[sizeof ime_preedit / sizeof(wchar_t)];
        size_t units = (size_t)draw->text->length;
        size_t result;
        if (units >= sizeof wide / sizeof wide[0]) {
            units = sizeof wide / sizeof wide[0] - 1U;
        }
        memcpy(wide, draw->text->string.wide_char, units * sizeof wide[0]);
        wide[units] = L'\0';
        result = wcstombs(converted, wide, sizeof converted - 1U);
        if (result != (size_t)-1) {
            converted[result] = '\0';
            insert = converted;
            inserted = result;
        }
    }
    if (inserted > sizeof ime_preedit - 1U -
                   (ime_preedit_length - removed)) {
        inserted = sizeof ime_preedit - 1U -
                   (ime_preedit_length - removed);
    }
    memmove(ime_preedit + first + inserted,
            ime_preedit + first + removed,
            ime_preedit_length - first - removed);
    if (inserted > 0U) {
        memcpy(ime_preedit + first, insert, inserted);
    }
    ime_preedit_length = ime_preedit_length - removed + inserted;
    ime_preedit[ime_preedit_length] = '\0';
    if (ime_preedit_callback != NULL) {
        ime_preedit_callback(ime_preedit);
    }
}

static XIMStyle bracke_ime_style(void)
{
    XIMStyles *styles = NULL;
    XIMStyle selected = 0;
    unsigned short i;

    if (XGetIMValues(ime_method, XNQueryInputStyle, &styles, NULL) != NULL ||
        styles == NULL) {
        return 0;
    }
    for (i = 0; i < styles->count_styles; ++i) {
        if (styles->supported_styles[i] ==
            (XIMPreeditCallbacks | XIMStatusNothing)) {
            selected = styles->supported_styles[i];
            break;
        }
    }
    XFree(styles);
    return selected;
}

int bracke_ime_initialize(void *window, bracke_ime_text_callback commit,
                          bracke_ime_text_callback preedit)
{
    GLFWwindow *glfw_window = (GLFWwindow *)window;
    XIMStyle style;
    XIMCallback start;
    XIMCallback done;
    XIMCallback draw;
    XVaNestedList attributes;

    if (glfw_window == NULL) {
        return -1;
    }
    ime_display = glfwGetX11Display();
    ime_window = glfwGetX11Window(glfw_window);
    if (ime_display == NULL || ime_window == (Window)0) {
        return -1;
    }
    XSetLocaleModifiers("");
    ime_method = XOpenIM(ime_display, NULL, NULL, NULL);
    if (ime_method == NULL) {
        return -1;
    }
    style = bracke_ime_style();
    if (style == 0) {
        XCloseIM(ime_method);
        ime_method = NULL;
        return -1;
    }

    ime_commit = commit;
    ime_preedit_callback = preedit;
    ime_preedit_length = 0U;
    ime_preedit[0] = '\0';
    start.client_data = NULL;
    /* Xlib gives every callback slot the generic void-returning XIMProc type,
       although XIMPreeditStartCallback is specified to return the maximum
       pre-edit length.  The cast is the API-prescribed adapter. */
#if defined(__GNUC__)
#pragma GCC diagnostic push
#pragma GCC diagnostic ignored "-Wcast-function-type"
#endif
    start.callback = (XIMProc)bracke_ime_preedit_start;
#if defined(__GNUC__)
#pragma GCC diagnostic pop
#endif
    done.client_data = NULL;
    done.callback = (XIMProc)bracke_ime_preedit_done;
    draw.client_data = NULL;
    draw.callback = (XIMProc)bracke_ime_preedit_draw;
    attributes = XVaCreateNestedList(0,
                                     XNPreeditStartCallback, &start,
                                     XNPreeditDoneCallback, &done,
                                     XNPreeditDrawCallback, &draw,
                                     NULL);
    if (attributes == NULL) {
        XCloseIM(ime_method);
        ime_method = NULL;
        return 0;
    }
    ime_context = XCreateIC(ime_method,
                            XNInputStyle, style,
                            XNClientWindow, ime_window,
                            XNFocusWindow, ime_window,
                            XNPreeditAttributes, attributes,
                            NULL);
    XFree(attributes);
    if (ime_context == NULL) {
        XCloseIM(ime_method);
        ime_method = NULL;
        return 0;
    }
    XSetICFocus(ime_context);
    return 1;
}

void bracke_ime_finalize(void)
{
    if (ime_context != NULL) {
        XUnsetICFocus(ime_context);
        XDestroyIC(ime_context);
    }
    if (ime_method != NULL) {
        XCloseIM(ime_method);
    }
    ime_context = NULL;
    ime_method = NULL;
    ime_display = NULL;
    ime_window = (Window)0;
    ime_commit = NULL;
    ime_preedit_callback = NULL;
    ime_preedit_length = 0U;
    ime_preedit[0] = '\0';
}

int bracke_ime_process_key(int scancode, int action, int modifiers)
{
    XKeyEvent event;
    Status status = XLookupNone;
    KeySym keysym = NoSymbol;
    char stack[128];
    char *buffer = stack;
    int size = (int)sizeof stack;
    int length;
    int characters = 0;

    if (ime_context == NULL || ime_display == NULL || action == 0 ||
        scancode <= 0) {
        return 0;
    }
    /* Reserve Control and Super shortcuts for the application.  Ctrl+Alt is
       retained because it is AltGr on common XKB layouts. */
    if ((modifiers & 8) != 0 ||
        (((modifiers & 2) != 0) && ((modifiers & 4) == 0))) {
        return 0;
    }
    memset(&event, 0, sizeof event);
    event.type = KeyPress;
    event.display = ime_display;
    event.window = ime_window;
    event.root = DefaultRootWindow(ime_display);
    event.time = CurrentTime;
    event.state = ((modifiers & 1) != 0 ? ShiftMask : 0U) |
                  ((modifiers & 2) != 0 ? ControlMask : 0U) |
                  ((modifiers & 4) != 0 ? Mod1Mask : 0U) |
                  ((modifiers & 8) != 0 ? Mod4Mask : 0U);
    event.keycode = (unsigned int)scancode;
    event.same_screen = True;

    length = Xutf8LookupString(ime_context, &event, buffer, size - 1,
                               &keysym, &status);
    if (status == XBufferOverflow && length > 0) {
        buffer = (char *)malloc((size_t)length + 1U);
        if (buffer == NULL) {
            return 0;
        }
        size = length + 1;
        length = Xutf8LookupString(ime_context, &event, buffer, size - 1,
                                   &keysym, &status);
    }
    if (length > 0 &&
        (status == XLookupChars || status == XLookupBoth)) {
        buffer[length] = '\0';
        if (ime_commit != NULL) {
            ime_commit(buffer);
        }
        {
            int i;
            for (i = 0; i < length; ++i) {
                if (((unsigned char)buffer[i] & 0xc0U) != 0x80U) {
                    ++characters;
                }
            }
        }
        if (buffer != stack) {
            free(buffer);
        }
        return characters > 0 ? characters : 1;
    }
    if (buffer != stack) {
        free(buffer);
    }
    return ime_preedit_length > 0U ? -1 : 0;
}

void bracke_ime_set_focused(int focused)
{
    if (ime_context == NULL) {
        return;
    }
    if (focused != 0) {
        XSetICFocus(ime_context);
    } else {
        XUnsetICFocus(ime_context);
    }
}

void bracke_ime_set_cursor(int x, int y, int width, int height)
{
    XPoint spot;
    XVaNestedList attributes;

    (void)width;
    if (ime_context == NULL) {
        return;
    }
    spot.x = (short)x;
    spot.y = (short)(y + height);
    attributes = XVaCreateNestedList(0, XNSpotLocation, &spot, NULL);
    if (attributes != NULL) {
        XSetICValues(ime_context, XNPreeditAttributes, attributes, NULL);
        XFree(attributes);
    }
}
#else
typedef void (*bracke_ime_text_callback)(const char *text);

int bracke_ime_initialize(void *window, bracke_ime_text_callback commit,
                          bracke_ime_text_callback preedit)
{
    (void)window;
    (void)commit;
    (void)preedit;
    return -1;
}

void bracke_ime_finalize(void)
{
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
    (void)focused;
}

void bracke_ime_set_cursor(int x, int y, int width, int height)
{
    (void)x;
    (void)y;
    (void)width;
    (void)height;
}
#endif
