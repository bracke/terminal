#include <windows.h>
#include <ctype.h>
#include <stddef.h>
#include <stdlib.h>
#include <string.h>

#define BRACKE_HOTKEY_ID 0x4252

static int bracke_hotkey_registered;

void bracke_global_hotkey_unregister(void) {
    if (bracke_hotkey_registered != 0) {
        UnregisterHotKey(NULL, BRACKE_HOTKEY_ID);
    }
    bracke_hotkey_registered = 0;
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

int bracke_global_hotkey_register(const char *binding) {
    char copy[128];
    char *token;
    char *context = NULL;
    char *key_name = NULL;
    UINT modifiers = MOD_NOREPEAT;
    UINT key = 0U;
    bracke_global_hotkey_unregister();
    if (binding == NULL || binding[0] == '\0' || strlen(binding) >= sizeof copy) {
        return -1;
    }
    memcpy(copy, binding, strlen(binding) + 1U);
    token = strtok_s(copy, "+", &context);
    while (token != NULL) {
        if (bracke_equal(token, "ctrl") || bracke_equal(token, "control")) {
            modifiers |= MOD_CONTROL;
        } else if (bracke_equal(token, "alt")) {
            modifiers |= MOD_ALT;
        } else if (bracke_equal(token, "shift")) {
            modifiers |= MOD_SHIFT;
        } else if (bracke_equal(token, "super") || bracke_equal(token, "meta")) {
            modifiers |= MOD_WIN;
        } else if (key_name == NULL) {
            key_name = token;
        } else {
            return -1;
        }
        token = strtok_s(NULL, "+", &context);
    }
    if (key_name == NULL) {
        return -1;
    }
    if (key_name[0] != '\0' && key_name[1] == '\0') {
        key = (UINT)toupper((unsigned char)key_name[0]);
    } else if ((key_name[0] == 'F' || key_name[0] == 'f') &&
               isdigit((unsigned char)key_name[1])) {
        int number = atoi(key_name + 1);
        if (number >= 1 && number <= 24) {
            key = (UINT)(VK_F1 + number - 1);
        }
    }
    if (key == 0U) {
        return -1;
    }
    if (RegisterHotKey(NULL, BRACKE_HOTKEY_ID, modifiers, key) == 0) {
        return 0;
    }
    bracke_hotkey_registered = 1;
    return 1;
}

int bracke_global_hotkey_poll(void) {
    MSG message;
    if (bracke_hotkey_registered == 0) {
        return 0;
    }
    if (PeekMessage(&message, NULL, WM_HOTKEY, WM_HOTKEY, PM_REMOVE) != 0 &&
        message.wParam == BRACKE_HOTKEY_ID) {
        return 1;
    }
    return 0;
}
