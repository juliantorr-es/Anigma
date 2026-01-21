#ifndef SQLITE_VEC_H
#define SQLITE_VEC_H

#include <sqlite3.h>

#ifdef __cplusplus
extern "C" {
#endif

// sqlite-vec initialization function
// Call this before using vec0 virtual tables
int sqlite3_vec_init(
    sqlite3 *db,
    char **pzErrMsg,
    const sqlite3_api_routines *pApi
);

#ifdef __cplusplus
}
#endif

#endif /* SQLITE_VEC_H */
