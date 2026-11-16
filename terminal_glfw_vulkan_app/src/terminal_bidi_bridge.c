#include <fribidi/fribidi.h>
#include <stddef.h>
#include <stdint.h>

/*
 * Keep FriBidi's ABI details out of Ada.  The bridge uses fixed-width values
 * and reports logical-to-visual positions as ordinary signed integers.
 */
int terminal_bidi_resolve(const uint32_t *logical,
                          int count,
                          int *logical_to_visual,
                          uint8_t *levels,
                          uint32_t *visual,
                          int *base_direction)
{
    FriBidiParType base = FRIBIDI_PAR_ON;

    if (logical == NULL || logical_to_visual == NULL || levels == NULL ||
        visual == NULL || base_direction == NULL || count <= 0) {
        return 0;
    }

    if (!fribidi_log2vis((const FriBidiChar *)logical,
                         (FriBidiStrIndex)count,
                         &base,
                         (FriBidiChar *)visual,
                         (FriBidiStrIndex *)logical_to_visual,
                         NULL,
                         (FriBidiLevel *)levels)) {
        return 0;
    }

    *base_direction = FRIBIDI_IS_RTL(base) ? 1 : 0;
    return 1;
}

int terminal_bidi_join_group(uint32_t codepoint)
{
    const FriBidiCharType type = fribidi_get_bidi_type((FriBidiChar)codepoint);

    if (type == FRIBIDI_TYPE_LTR) {
        return 1;
    }
    if (type == FRIBIDI_TYPE_RTL) {
        return 2;
    }
    if (type == FRIBIDI_TYPE_AL) {
        return 3;
    }
    if (type == FRIBIDI_TYPE_EN) {
        return 4;
    }
    if (type == FRIBIDI_TYPE_AN) {
        return 5;
    }
    if (type == FRIBIDI_TYPE_WS) {
        return 6;
    }
    return 0;
}
