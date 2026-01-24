#ifndef ANIGMA_VECTOR_STORE_CAPSULE_H
#define ANIGMA_VECTOR_STORE_CAPSULE_H

#include "anigma_capsule_core.h"
#include "anigma_status.h"

#if defined(__cplusplus)
extern "C" {
#endif

// Register sqlite-vec extension with a SQLite database connection
// db_handle: A pointer to sqlite3*
anigma_status_t anigma_vector_store_register(
    void* db_handle,
    anigma_capsule_error_t* err
);

// Get version of the vector store extension
anigma_status_t anigma_vector_store_version(
    char** out_version, // Caller must free with anigma_free_buffer (or free if malloc used, let's use anigma convention)
    anigma_capsule_error_t* err
);

#if defined(__cplusplus)
}
#endif

#endif
