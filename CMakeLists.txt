cmake_minimum_required(VERSION 3.22)
project(OpenDesertCombat VERSION 0.1.0 LANGUAGES C CXX)

set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_EXPORT_COMPILE_COMMANDS ON)

# Compiler flags
if(CMAKE_CXX_COMPILER_ID MATCHES "GNU|Clang")
    add_compile_options(-Wall -Wextra -Wpedantic)
endif()

# Directories
add_subdirectory(tools/odc-converter)
# add_subdirectory(src/engine)
# add_subdirectory(src/game)
