#include "anigma_native_common.h"
#include <stdlib.h>

void anigma_free_buffer(uint8_t* buf) {
    if (buf) {
        free(buf);
    }
}
