cmake_minimum_required(VERSION 3.20)

project(sa_legacy LANGUAGES C CXX)

set(REPO_ROOT "${CMAKE_CURRENT_LIST_DIR}/../.." CACHE PATH "mad-sa repository root")
set(GODOT_CPP_DIR "${REPO_ROOT}/build/godot-deps/godot-cpp" CACHE PATH "Pinned godot-cpp checkout")
set(SA_GODOT_CPP_TAG "godot-4.5-stable")
set(SA_GODOT_CPP_COMMIT "e83fd0904c13356ed1d4c3d09f8bb9132bdc6b77")

if(NOT EXISTS "${GODOT_CPP_DIR}/CMakeLists.txt")
    message(FATAL_ERROR "GODOT_CPP_DIR does not contain a godot-cpp checkout: ${GODOT_CPP_DIR}")
endif()
if(NOT EXISTS "${REPO_ROOT}/gta-reversed/vendor/librw/CMakeLists.txt")
    message(FATAL_ERROR "REPO_ROOT does not contain gta-reversed/vendor/librw: ${REPO_ROOT}")
endif()

find_package(Git REQUIRED)
if(NOT EXISTS "${GODOT_CPP_DIR}/.git")
    message(FATAL_ERROR "GODOT_CPP_DIR must be a Git checkout so the binding commit can be verified")
endif()
execute_process(
    COMMAND "${GIT_EXECUTABLE}" -C "${GODOT_CPP_DIR}" rev-parse HEAD
    RESULT_VARIABLE GODOT_CPP_GIT_RESULT
    OUTPUT_VARIABLE GODOT_CPP_HEAD
    OUTPUT_STRIP_TRAILING_WHITESPACE
)
if(NOT GODOT_CPP_GIT_RESULT EQUAL 0 OR NOT GODOT_CPP_HEAD STREQUAL SA_GODOT_CPP_COMMIT)
    message(FATAL_ERROR
        "godot-cpp must be ${SA_GODOT_CPP_TAG} at ${SA_GODOT_CPP_COMMIT}; found ${GODOT_CPP_HEAD}")
endif()

set(CMAKE_POSITION_INDEPENDENT_CODE ON)
set(GODOT_CPP_SYSTEM_HEADERS ON CACHE BOOL "" FORCE)
add_subdirectory("${GODOT_CPP_DIR}" "${CMAKE_BINARY_DIR}/godot-cpp" EXCLUDE_FROM_ALL)

set(LIBRW_PLATFORM "NULL" CACHE STRING "" FORCE)
set(LIBRW_TOOLS OFF CACHE BOOL "" FORCE)
set(LIBRW_EXAMPLES OFF CACHE BOOL "" FORCE)
set(LIBRW_INSTALL OFF CACHE BOOL "" FORCE)
add_subdirectory(
    "${REPO_ROOT}/gta-reversed/vendor/librw"
    "${CMAKE_BINARY_DIR}/librw"
    EXCLUDE_FROM_ALL
)
set_target_properties(librw PROPERTIES POSITION_INDEPENDENT_CODE ON)

set(NATIVE_SOURCE_DIR "${REPO_ROOT}/gta-reversed/source")
add_library(sa_legacy SHARED
    register_types.cpp
    sa_legacy_bridge.cpp
    os_file_posix.cpp
    "${NATIVE_SOURCE_DIR}/app/platform/linux/StreamPager.cpp"
    "${NATIVE_SOURCE_DIR}/app/platform/linux/TexSample.cpp"
    "${NATIVE_SOURCE_DIR}/app/platform/linux/TimeCycle.cpp"
)
target_compile_features(sa_legacy PRIVATE cxx_std_20)
target_include_directories(sa_legacy PRIVATE
    "${CMAKE_CURRENT_LIST_DIR}"
    "${NATIVE_SOURCE_DIR}"
)
find_package(Threads REQUIRED)
target_link_libraries(sa_legacy PRIVATE godot-cpp librw::librw Threads::Threads)
if(CMAKE_CXX_COMPILER_ID MATCHES "GNU|Clang")
    target_compile_options(sa_legacy PRIVATE -Wall -Wextra -Wpedantic)
endif()
set_target_properties(sa_legacy PROPERTIES
    OUTPUT_NAME "sa_legacy"
    LIBRARY_OUTPUT_DIRECTORY "${CMAKE_CURRENT_LIST_DIR}/../bin"
)
