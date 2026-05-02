// Minimal source file to make AnigmaNativeShims importable as a Swift module.
// This file exists solely to satisfy SPM's requirement that C targets have at least one source file.
// All actual functionality is provided by the headers in include/.

#include "AnigmaNativeShims.h"

// Empty module initialization function
void anigma_native_shims_init(void) {
    // No-op: headers-only module
}
