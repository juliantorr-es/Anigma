#include "anigma_capsule_core.h"
extern "C" {
anigma_capsule_identity_t anigma_media_fingerprint_capsule_get_identity(void) {
    static const anigma_capsule_identity_t identity = { "media_fingerprint_capsule", "v1.0.0-stub", "1.0", 1 };
    return identity;
}
}
