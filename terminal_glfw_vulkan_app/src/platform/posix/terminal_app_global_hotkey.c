#include <X11/Xlib.h>
#include <X11/keysym.h>
#include <ctype.h>
#include <stddef.h>
#include <string.h>

static Display *bracke_hotkey_display;
static Window bracke_hotkey_root;
static unsigned int bracke_hotkey_code;
static unsigned int bracke_hotkey_modifiers;
static int bracke_x_error;

static int bracke_hotkey_error_handler(Display *display, XErrorEvent *event) {
    (void)display;
    (void)event;
    bracke_x_error = 1;
    return 0;
}

static int bracke_equal(const char *left, const char *right) {
    while (*left != '\0' && *right != '\0') {
        if (tolower((unsigned char)*left) != tolower((unsigned char)*right)) {
            return 0;
        }
        ++left;
        ++right;
    }
    return *left == '\0' && *right == '\0';
}

void bracke_global_hotkey_unregister(void) {
    unsigned int ignored[] = {0U, LockMask, Mod2Mask, LockMask | Mod2Mask};
    size_t index;
    if (bracke_hotkey_display != NULL && bracke_hotkey_code != 0) {
        for (index = 0; index < sizeof ignored / sizeof ignored[0]; ++index) {
            XUngrabKey(bracke_hotkey_display, bracke_hotkey_code,
                       bracke_hotkey_modifiers | ignored[index],
                       bracke_hotkey_root);
        }
        XSync(bracke_hotkey_display, False);
    }
    if (bracke_hotkey_display != NULL) {
        XCloseDisplay(bracke_hotkey_display);
    }
    bracke_hotkey_display = NULL;
    bracke_hotkey_root = 0;
    bracke_hotkey_code = 0;
    bracke_hotkey_modifiers = 0U;
}

int bracke_global_hotkey_register(const char *binding) {
    char copy[128];
    char *token;
    char *save = NULL;
    char *key_name = NULL;
    KeySym symbol;
    unsigned int ignored[] = {0U, LockMask, Mod2Mask, LockMask | Mod2Mask};
    size_t index;
    int (*old_handler)(Display *, XErrorEvent *);

    bracke_global_hotkey_unregister();
    if (binding == NULL || binding[0] == '\0' || strlen(binding) >= sizeof copy) {
        return -1;
    }
    memcpy(copy, binding, strlen(binding) + 1U);
    token = strtok_r(copy, "+", &save);
    while (token != NULL) {
        if (bracke_equal(token, "ctrl") || bracke_equal(token, "control")) {
            bracke_hotkey_modifiers |= ControlMask;
        } else if (bracke_equal(token, "alt")) {
            bracke_hotkey_modifiers |= Mod1Mask;
        } else if (bracke_equal(token, "shift")) {
            bracke_hotkey_modifiers |= ShiftMask;
        } else if (bracke_equal(token, "super") || bracke_equal(token, "meta")) {
            bracke_hotkey_modifiers |= Mod4Mask;
        } else if (key_name == NULL) {
            key_name = token;
        } else {
            return -1;
        }
        token = strtok_r(NULL, "+", &save);
    }
    if (key_name == NULL) {
        return -1;
    }
    symbol = XStringToKeysym(key_name);
    if (symbol == NoSymbol && key_name[0] != '\0' && key_name[1] == '\0') {
        char upper[2] = {(char)toupper((unsigned char)key_name[0]), '\0'};
        symbol = XStringToKeysym(upper);
    }
    if (symbol == NoSymbol) {
        return -1;
    }
    bracke_hotkey_display = XOpenDisplay(NULL);
    if (bracke_hotkey_display == NULL) {
        return -2;
    }
    bracke_hotkey_root = DefaultRootWindow(bracke_hotkey_display);
    bracke_hotkey_code = XKeysymToKeycode(bracke_hotkey_display, symbol);
    if (bracke_hotkey_code == 0) {
        bracke_global_hotkey_unregister();
        return -1;
    }
    bracke_x_error = 0;
    old_handler = XSetErrorHandler(bracke_hotkey_error_handler);
    for (index = 0; index < sizeof ignored / sizeof ignored[0]; ++index) {
        XGrabKey(bracke_hotkey_display, bracke_hotkey_code,
                 bracke_hotkey_modifiers | ignored[index], bracke_hotkey_root,
                 False, GrabModeAsync, GrabModeAsync);
    }
    XSync(bracke_hotkey_display, False);
    XSetErrorHandler(old_handler);
    if (bracke_x_error != 0) {
        bracke_global_hotkey_unregister();
        return 0;
    }
    return 1;
}

int bracke_global_hotkey_poll(void) {
    XEvent event;
    int fired = 0;
    if (bracke_hotkey_display == NULL) {
        return 0;
    }
    while (XPending(bracke_hotkey_display) > 0) {
        XNextEvent(bracke_hotkey_display, &event);
        if (event.type == KeyPress && event.xkey.keycode == bracke_hotkey_code) {
            fired = 1;
        }
    }
    return fired;
}
