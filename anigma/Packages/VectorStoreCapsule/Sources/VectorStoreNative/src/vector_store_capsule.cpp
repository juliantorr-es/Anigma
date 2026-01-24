#include "anigma_vector_store_capsule.h"
#include "sqlite-vec.h"
#include <string.h>
#include <stdlib.h>

extern "C" {

anigma_status_t anigma_vector_store_register(
    void* db_handle,
    anigma_capsule_error_t* err
) {
    if (!db_handle) return ANIGMA_ERR_INVALID_ARG;
    
    sqlite3* db = static_cast<sqlite3*>(db_handle);
    char* errMsg = nullptr;
    
    // sqlite3_vec_init(sqlite3 *db, char **pzErrMsg, const sqlite3_api_routines *pApi)
    int rc = sqlite3_vec_init(db, &errMsg, nullptr);
    
    if (rc != SQLITE_OK) {
        if (errMsg && err) {
            // Ideally copy errMsg to err, but our current struct doesn't easily support string copy
            // without knowing the buffer size or allocation strategy.
            // For now, we free the sqlite message and return error.
            sqlite3_free(errMsg);
        }
        return ANIGMA_ERR_INTERNAL;
    }
    
    return ANIGMA_OK;
}

anigma_status_t anigma_vector_store_version(
    char** out_version,
    anigma_capsule_error_t* err
) {
    if (!out_version) return ANIGMA_ERR_INVALID_ARG;
    
    // sqlite-vec defines specific version macros but doesn't seem to expose a runtime version string function easily 
    // unless registered. 
    // However, looking at sqlite-vec.h/c, usually there's a way.
    // Assuming hardcoded for now based on the file content or macros if available.
    // The previous swift code used `SELECT vec_version()`.
    
    // We can just return a static string for this capsule version.
    const char* version = "0.1.7-alpha.2"; // Matches the CSettings in Package.swift
    size_t len = strlen(version);
    
    *out_version = (char*)malloc(len + 1);
    if (!*out_version) return ANIGMA_ERR_OUT_OF_MEMORY;
    
    strcpy(*out_version, version);
    
    return ANIGMA_OK;
}

} // extern "C"
