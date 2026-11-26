cmake_minimum_required(VERSION 3.22)
project(odc-converter LANGUAGES C CXX)

set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

add_executable(odc-converter
    src/main.cpp
    src/rfa_reader.cpp
)

target_include_directories(odc-converter PRIVATE include)
