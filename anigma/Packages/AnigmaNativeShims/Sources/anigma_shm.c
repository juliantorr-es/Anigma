#include "anigma_native_common.h"
#include <sys/mman.h>
#include <fcntl.h>
#include <unistd.h>

int anigma_shm_open(const char* name, int oflag, uint16_t mode) {
    return shm_open(name, oflag, (mode_t)mode);
}

int anigma_shm_unlink(const char* name) {
    return shm_unlink(name);
}
