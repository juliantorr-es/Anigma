#include "anigma_observability.h"
#include <stdio.h>
#include <stdlib.h>

// Mock implementation of spdlog/OpenTelemetry wrapper

anigma_result_t anigma_log_init(
    const char* file_path,
    bool console_output
) {
    // Mock init
    return (anigma_result_t){ANIGMA_OK, NULL};
}

void anigma_log_write(
    anigma_log_level_t level,
    const char* message,
    const char** fields,
    size_t field_count
) {
    // Mock: just print to stdout for now
    // In real impl, this would go to spdlog async logger
    // printf("[LOG %d] %s\n", level, message);
}

struct anigma_span_s {
    const char* name;
};

anigma_span_t anigma_trace_start(const char* name, anigma_span_t parent) {
    struct anigma_span_s* s = (struct anigma_span_s*)malloc(sizeof(struct anigma_span_s));
    if (s) s->name = name;
    return s;
}

void anigma_trace_end(anigma_span_t span) {
    if (span) free(span);
}
