#ifndef ANIGMA_OBSERVABILITY_SHIM_H
#define ANIGMA_OBSERVABILITY_SHIM_H

#include "anigma_native_common.h"

#if defined(__cplusplus)
extern "C" {
#endif

// --- Logging ---

typedef enum {
    ANIGMA_LOG_DEBUG,
    ANIGMA_LOG_INFO,
    ANIGMA_LOG_WARN,
    ANIGMA_LOG_ERROR,
    ANIGMA_LOG_CRITICAL
} anigma_log_level_t;

/**
 * Initialize the native logging subsystem (spdlog).
 */
anigma_result_t anigma_log_init(
    const char* file_path,
    bool console_output
);

/**
 * Log a structured message.
 * Fields are key=value pairs, null terminated array of strings.
 */
void anigma_log_write(
    anigma_log_level_t level,
    const char* message,
    const char** fields,
    size_t field_count
);

// --- Tracing ---

typedef struct anigma_span_s* anigma_span_t;

/**
 * Start a trace span.
 */
anigma_span_t anigma_trace_start(const char* name, anigma_span_t parent);

/**
 * End a trace span.
 */
void anigma_trace_end(anigma_span_t span);

#if defined(__cplusplus)
}
#endif

#endif // ANIGMA_OBSERVABILITY_SHIM_H
