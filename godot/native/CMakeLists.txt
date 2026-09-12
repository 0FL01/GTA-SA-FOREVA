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
# P1-A04 single-chain sources: strict source float semantics and throwing
# Require() parsers need exceptions even though the extension disables them.
set(NATIVE_LOD_SOURCES
    "${NATIVE_SOURCE_DIR}/app/platform/linux/NativeLodCatalog.cpp"
    "${NATIVE_SOURCE_DIR}/app/platform/linux/NativeWorldEntityInfo.cpp"
    "${NATIVE_SOURCE_DIR}/app/platform/linux/NativeCollisionAssets.cpp"
)
add_library(sa_legacy SHARED
    register_types.cpp
    sa_legacy_bridge.cpp
    sa_input_bridge.cpp
    sa_region_plan.cpp
    sa_region_worker.cpp
    os_file_posix.cpp
    "${NATIVE_SOURCE_DIR}/app/platform/linux/StreamPager.cpp"
    "${NATIVE_SOURCE_DIR}/app/platform/linux/TexSample.cpp"
    "${NATIVE_SOURCE_DIR}/app/platform/linux/TimeCycle.cpp"
    ${NATIVE_LOD_SOURCES}
)
if(CMAKE_CXX_COMPILER_ID MATCHES "GNU|Clang")
    set_source_files_properties(${NATIVE_LOD_SOURCES} PROPERTIES COMPILE_OPTIONS
        "-fexceptions;-fno-fast-math;-ffp-contract=off")
    set_source_files_properties(sa_region_worker.cpp sa_region_plan.cpp PROPERTIES COMPILE_OPTIONS
        "-fexceptions;-fno-fast-math;-ffp-contract=off")
endif()
target_compile_features(sa_legacy PRIVATE cxx_std_20)
target_include_directories(sa_legacy PRIVATE
    "${CMAKE_CURRENT_LIST_DIR}"
    "${NATIVE_SOURCE_DIR}"
)
find_package(Threads REQUIRED)
target_link_libraries(sa_legacy PRIVATE godot-cpp librw::librw Threads::Threads)
if(CMAKE_SYSTEM_NAME STREQUAL "Linux")
    # godot-cpp links libstdc++ statically. Its GNU-unique locale facet IDs
    # must not bind to Mesa's separately loaded dynamic libstdc++ instance.
    # GDExtension exchanges a C interface, not private C++/RW/stdlib symbols.
    target_link_options(sa_legacy PRIVATE
        "LINKER:--version-script=${CMAKE_CURRENT_LIST_DIR}/exports.map")
    set_property(TARGET sa_legacy APPEND PROPERTY LINK_DEPENDS
        "${CMAKE_CURRENT_LIST_DIR}/exports.map")
endif()
if(CMAKE_CXX_COMPILER_ID MATCHES "GNU|Clang")
    target_compile_options(sa_legacy PRIVATE -Wall -Wextra -Wpedantic)
endif()
set_target_properties(sa_legacy PROPERTIES
    OUTPUT_NAME "sa_legacy"
    LIBRARY_OUTPUT_DIRECTORY "${CMAKE_CURRENT_LIST_DIR}/../bin"
)

# P2-A01 owned startup core: existing session + POSIX OS adapter only.
# P2-A02 adds the owned source clock plus the existing source RNG (both
# unchanged API reuse; no extension linkage change).
# P2-A03 adds the pure owned source pad (sibling NativeSourcePad.h/.cpp, no
# session/clock/IO dependency). sa_input_bridge.cpp above is the only
# extension TU that uses it.
set(SA_CORE_SOURCES
    "${NATIVE_SOURCE_DIR}/app/platform/linux/NativeScriptSession.cpp"
    "${NATIVE_SOURCE_DIR}/app/platform/linux/NativeScriptFrame.cpp"
    "${NATIVE_SOURCE_DIR}/app/platform/linux/NativeSourceRng.cpp"
    "${NATIVE_SOURCE_DIR}/app/platform/linux/NativeSourceClock.cpp"
    "${NATIVE_SOURCE_DIR}/app/platform/linux/NativeSourcePad.cpp"
    "${NATIVE_SOURCE_DIR}/app/platform/linux/NativeCollisionAssets.cpp"
    "${NATIVE_SOURCE_DIR}/app/platform/linux/NativeWorldEntityInfo.cpp"
    "${NATIVE_SOURCE_DIR}/app/platform/linux/NativeSourceGround.cpp"
    "${NATIVE_SOURCE_DIR}/app/platform/linux/NativeWorldGround.cpp"
    "${CMAKE_CURRENT_LIST_DIR}/os_file_posix.cpp"
)
add_library(sa_core STATIC ${SA_CORE_SOURCES})
target_include_directories(sa_core PUBLIC
    "${CMAKE_CURRENT_LIST_DIR}"
    "${NATIVE_SOURCE_DIR}"
)
target_compile_features(sa_core PUBLIC cxx_std_20)
if(CMAKE_CXX_COMPILER_ID MATCHES "GNU|Clang")
    target_compile_options(sa_core PRIVATE -Wall -Wextra -Wpedantic)
    set_source_files_properties(
        "${NATIVE_SOURCE_DIR}/app/platform/linux/NativeScriptSession.cpp"
        "${NATIVE_SOURCE_DIR}/app/platform/linux/NativeScriptFrame.cpp"
        PROPERTIES COMPILE_OPTIONS "-fexceptions"
    )
    # Strict source float semantics for the clock, the reused RNG, and the
    # pad axis quantizer; no source-file edits, only build flags.
    set_source_files_properties(
        "${NATIVE_SOURCE_DIR}/app/platform/linux/NativeSourceClock.cpp"
        "${NATIVE_SOURCE_DIR}/app/platform/linux/NativeSourceRng.cpp"
        "${NATIVE_SOURCE_DIR}/app/platform/linux/NativeSourcePad.cpp"
        PROPERTIES COMPILE_OPTIONS "-fno-fast-math;-ffp-contract=off"
    )
    # P2-A04 isolated world authority: existing Assets/EntityInfo/SourceGround/
    # WorldGround with strict source float semantics and throwing Require().
    # Per-file properties are global, so reuse the same full flagset as
    # NATIVE_LOD_SOURCES above; a subset would overwrite the extension flags.
    set_source_files_properties(
        "${NATIVE_SOURCE_DIR}/app/platform/linux/NativeCollisionAssets.cpp"
        "${NATIVE_SOURCE_DIR}/app/platform/linux/NativeWorldEntityInfo.cpp"
        "${NATIVE_SOURCE_DIR}/app/platform/linux/NativeSourceGround.cpp"
        "${NATIVE_SOURCE_DIR}/app/platform/linux/NativeWorldGround.cpp"
        PROPERTIES COMPILE_OPTIONS "-fexceptions;-fno-fast-math;-ffp-contract=off"
    )
endif()
target_link_libraries(sa_core PUBLIC Threads::Threads)

add_executable(sa_core_startup sa_core_startup.cpp)
target_link_libraries(sa_core_startup PRIVATE sa_core)

add_executable(sa_core_frame_probe
    "${NATIVE_SOURCE_DIR}/app/platform/linux/NativeScriptFrameProbe.cpp")
target_link_libraries(sa_core_frame_probe PRIVATE sa_core)
add_executable(sa_core_session_probe
    "${NATIVE_SOURCE_DIR}/app/platform/linux/NativeScriptSessionProbe.cpp")
target_link_libraries(sa_core_session_probe PRIVATE sa_core)
if(CMAKE_CXX_COMPILER_ID MATCHES "GNU|Clang")
    target_compile_options(sa_core_frame_probe PRIVATE -Wall -Wextra -Wpedantic)
    target_compile_options(sa_core_session_probe PRIVATE -Wall -Wextra -Wpedantic)
endif()

# P2-A02 owned source-clock probe: links ONLY sa_core, never the extension.
add_executable(sa_core_clock_probe
    "${NATIVE_SOURCE_DIR}/app/platform/linux/NativeSourceClockProbe.cpp"
)
target_link_libraries(sa_core_clock_probe PRIVATE sa_core)
if(CMAKE_CXX_COMPILER_ID MATCHES "GNU|Clang")
    target_compile_options(sa_core_clock_probe PRIVATE
        -Wall -Wextra -Wpedantic -fno-fast-math -ffp-contract=off)
endif()

# P2-A03 owned source-pad probe: links ONLY sa_core, never the extension.
# Prints the versioned canonical trace to stdout (`--trace`, no path arg, no
# game assets): header plus 11 canonical rows including duplicate2, matching
# the C++ literal oracles that input_trace.gd compares FULL-text.
add_executable(sa_core_input_probe
    "${NATIVE_SOURCE_DIR}/app/platform/linux/NativeSourcePadProbe.cpp"
)
target_link_libraries(sa_core_input_probe PRIVATE sa_core)
if(CMAKE_CXX_COMPILER_ID MATCHES "GNU|Clang")
    target_compile_options(sa_core_input_probe PRIVATE
        -Wall -Wextra -Wpedantic -fno-fast-math -ffp-contract=off)
endif()

# P2-A04 owned isolated world probe: links ONLY sa_core, never the extension.
add_executable(sa_core_world_probe
    "${NATIVE_SOURCE_DIR}/app/platform/linux/NativeCoreWorldProbe.cpp"
)
target_link_libraries(sa_core_world_probe PRIVATE sa_core)
if(CMAKE_CXX_COMPILER_ID MATCHES "GNU|Clang")
    target_compile_options(sa_core_world_probe PRIVATE
        -Wall -Wextra -Wpedantic -fno-fast-math -ffp-contract=off)
endif()

# P2-A03 extension seam: static sa_core link AFTER both targets are defined.
# The archive pulls ONLY the Pad object (SubmitSample/QuantizeAxis/FormatFrame/
# StatusName); Session/Clock/IO objects stay unreferenced. exports.map keeps
# its single sa_legacy_library_init entry; bind/data/worker/.so APIs unchanged.
target_link_libraries(sa_legacy PRIVATE sa_core)

# P2-A06 diagnostic native controller reuse; kept OUT of pure sa_core.
set(SA_DIAGNOSTIC_SOURCES)
foreach(name NativeDiagnosticActors RealtimeGameplay NativePlayerActivity NativePlayerAssets
    IfpAnim SkinPed CarPose Handling Collide ColLoad StreamPager TexSample)
    list(APPEND SA_DIAGNOSTIC_SOURCES "${NATIVE_SOURCE_DIR}/app/platform/linux/${name}.cpp")
endforeach()
add_library(sa_diagnostic STATIC ${SA_DIAGNOSTIC_SOURCES})
target_include_directories(sa_diagnostic PUBLIC "${NATIVE_SOURCE_DIR}")
target_compile_features(sa_diagnostic PUBLIC cxx_std_20)
target_link_libraries(sa_diagnostic PUBLIC sa_core librw::librw)
if(CMAKE_CXX_COMPILER_ID MATCHES "GNU|Clang")
    target_compile_options(sa_diagnostic PRIVATE -fexceptions -fno-fast-math -ffp-contract=off)
endif()
add_executable(sa_diagnostic_actors_probe "${NATIVE_SOURCE_DIR}/app/platform/linux/NativeDiagnosticActorsProbe.cpp")
target_link_libraries(sa_diagnostic_actors_probe PRIVATE sa_diagnostic)
target_link_libraries(sa_legacy PRIVATE sa_diagnostic)
