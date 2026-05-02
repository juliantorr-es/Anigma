cmake_minimum_required(VERSION 3.15)
project(AnigmaNativeBenchmarks VERSION 1.0.0 LANGUAGES CXX)

# C++ Standard
set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -Wall -Wextra -O3")

# Platform-specific settings
if(APPLE)
    set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -march=native")
    find_library(MACH_LIB mach)
    find_library(SYSTEM_LIB System)
elseif(UNIX AND NOT APPLE)
    set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -march=native")
    set(CMAKE_CXX_FLAGS_RELEASE "${CMAKE_CXX_FLAGS_RELEASE} -flto")
endif()

# Include directories
include_directories(include)

# Source files
set(BENCHMARK_SOURCES
    src/main.cpp
    src/text_benchmarks.cpp
    src/hashing_benchmarks.cpp
    src/vector_benchmarks.cpp
    src/compression_benchmarks.cpp
    src/memory_benchmarks.cpp
    src/concurrent_benchmarks.cpp
)

# Create executable
add_executable(anigma_benchmarks ${BENCHMARK_SOURCES})

# Link libraries
target_link_libraries(anigma_benchmarks PRIVATE pthread)

if(APPLE)
    target_link_libraries(anigma_benchmarks PRIVATE ${MACH_LIB} ${SYSTEM_LIB})
endif()

# Output directory
set_target_properties(anigma_benchmarks PROPERTIES
    RUNTIME_OUTPUT_DIRECTORY "${CMAKE_BINARY_DIR}/bin"
)

# Installation
install(TARGETS anigma_benchmarks 
    RUNTIME DESTINATION bin
)

# Enable testing
enable_testing()

# Add custom test that runs benchmarks
add_test(
    NAME AnigmaBenchmarks
    COMMAND anigma_benchmarks
    WORKING_DIRECTORY ${CMAKE_BINARY_DIR}/bin
)

# Print configuration
message(STATUS "Anigma Native Benchmarks Configuration:")
message(STATUS "  C++ Standard: ${CMAKE_CXX_STANDARD}")
message(STATUS "  Build Type: ${CMAKE_BUILD_TYPE}")
message(STATUS "  Compiler: ${CMAKE_CXX_COMPILER}")
message(STATUS "  Optimization: -O3")
message(STATUS "  Platform: ${CMAKE_SYSTEM_NAME}")
