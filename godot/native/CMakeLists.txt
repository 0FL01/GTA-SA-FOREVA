cmake_minimum_required(VERSION 3.20)

project(sa_legacy LANGUAGES C CXX)

find_package(PkgConfig REQUIRED)
pkg_check_modules(FFMPEG REQUIRED IMPORTED_TARGET
    libavformat libavcodec libavutil libswscale libswresample)

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
    "${NATIVE_SOURCE_DIR}/app/platform/linux/NativeWorldResidency.cpp"
    "${NATIVE_SOURCE_DIR}/app/platform/linux/NativeWorldVisibility.cpp"
)
add_library(sa_legacy SHARED
    register_types.cpp
    sa_legacy_bridge.cpp
    sa_input_bridge.cpp
    sa_camera_bridge.cpp
    sa_frontend_bridge.cpp
    sa_audio_bridge.cpp
    sa_pose_bridge.cpp
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
    "${NATIVE_SOURCE_DIR}/app/platform/linux/NativeScriptSchema.cpp"
    "${NATIVE_SOURCE_DIR}/app/platform/linux/NativeScriptCorpus.cpp"
    "${NATIVE_SOURCE_DIR}/app/platform/linux/NativeScriptContentLedger.cpp"
    "${NATIVE_SOURCE_DIR}/app/platform/linux/NativeStoryLifecycle.cpp"
    "${NATIVE_SOURCE_DIR}/app/platform/linux/NativeActivityLifecycle.cpp"
    "${NATIVE_SOURCE_DIR}/app/platform/linux/NativeProgressionRuntime.cpp"
    "${NATIVE_SOURCE_DIR}/app/platform/linux/NativeSpecialStateManifest.cpp"
    "${NATIVE_SOURCE_DIR}/app/platform/linux/NativePcSaveCodec.cpp"
    "${NATIVE_SOURCE_DIR}/app/platform/linux/NativePcSaveSemantics.cpp"
    "${NATIVE_SOURCE_DIR}/app/platform/linux/NativeEnvironmentLifecycle.cpp"
    "${NATIVE_SOURCE_DIR}/app/platform/linux/NativeEffectFamilies.cpp"
    "${NATIVE_SOURCE_DIR}/app/platform/linux/TimeCycle.cpp"
    "${NATIVE_SOURCE_DIR}/app/platform/linux/NativeScriptSession.cpp"
    "${NATIVE_SOURCE_DIR}/app/platform/linux/NativeScriptFrame.cpp"
    "${NATIVE_SOURCE_DIR}/app/platform/linux/NativeScriptServiceTransaction.cpp"
    "${NATIVE_SOURCE_DIR}/app/platform/linux/NativeScriptPortableSave.cpp"
    "${NATIVE_SOURCE_DIR}/app/platform/linux/NativeStuntJumps.cpp"
    "${NATIVE_SOURCE_DIR}/app/platform/linux/NativeSetPieces.cpp"
    "${NATIVE_SOURCE_DIR}/app/platform/linux/NativeZonePopulation.cpp"
    "${NATIVE_SOURCE_DIR}/app/platform/linux/NativePathPolicy.cpp"
    "${NATIVE_SOURCE_DIR}/app/platform/linux/NativeExternalScriptTriggers.cpp"
    "${NATIVE_SOURCE_DIR}/app/platform/linux/NativeScriptModelAnims.cpp"
    "${NATIVE_SOURCE_DIR}/app/platform/linux/NativeScriptIplRequests.cpp"
    "${NATIVE_SOURCE_DIR}/app/platform/linux/NativeWorldObjectOverrides.cpp"
    "${NATIVE_SOURCE_DIR}/app/platform/linux/NativeScriptWeather.cpp"
    "${NATIVE_SOURCE_DIR}/app/platform/linux/NativeScriptClothes.cpp"
    "${NATIVE_SOURCE_DIR}/app/platform/linux/NativeMissionText.cpp"
    "${NATIVE_SOURCE_DIR}/app/platform/linux/NativeCutscene.cpp"
    "${NATIVE_SOURCE_DIR}/app/platform/linux/NativeCarRecordings.cpp"
    "${NATIVE_SOURCE_DIR}/app/platform/linux/NativeBeatTrack.cpp"
    "${NATIVE_SOURCE_DIR}/app/platform/linux/NativeMissionAudio.cpp"
    "${NATIVE_SOURCE_DIR}/app/platform/linux/SfxDecode.cpp"
    "${NATIVE_SOURCE_DIR}/app/platform/linux/NativeAudioFamilies.cpp"
    "${NATIVE_SOURCE_DIR}/app/platform/linux/NativeRadioRuntime.cpp"
    "${NATIVE_SOURCE_DIR}/app/platform/linux/NativeScriptPeds.cpp"
    "${NATIVE_SOURCE_DIR}/app/platform/linux/NativeVehicleFamilies.cpp"
    "${NATIVE_SOURCE_DIR}/app/platform/linux/NativeVehicleFamilyControl.cpp"
    "${NATIVE_SOURCE_DIR}/app/platform/linux/NativeVehicleFamilyLifecycle.cpp"
    "${NATIVE_SOURCE_DIR}/app/platform/linux/NativePathGraph.cpp"
    "${NATIVE_SOURCE_DIR}/app/platform/linux/NativeSourceEventFlow.cpp"
    "${NATIVE_SOURCE_DIR}/app/platform/linux/NativePopulationRuntime.cpp"
    "${NATIVE_SOURCE_DIR}/app/platform/linux/NativeCombatRuntime.cpp"
    "${NATIVE_SOURCE_DIR}/app/platform/linux/NativeWantedRuntime.cpp"
    "${NATIVE_SOURCE_DIR}/app/platform/linux/NativeRestartLifecycle.cpp"
    "${NATIVE_SOURCE_DIR}/app/platform/linux/NativeInteractionRuntime.cpp"
    "${NATIVE_SOURCE_DIR}/app/platform/linux/NativeScriptTrains.cpp"
    "${NATIVE_SOURCE_DIR}/app/platform/linux/ZoneInfo.cpp"
    "${NATIVE_SOURCE_DIR}/app/platform/linux/NativeScriptObjects.cpp"
    "${NATIVE_SOURCE_DIR}/app/platform/linux/NativeSourceRng.cpp"
    "${NATIVE_SOURCE_DIR}/app/platform/linux/NativeSourceClock.cpp"
    "${NATIVE_SOURCE_DIR}/app/platform/linux/NativeSourcePad.cpp"
    "${NATIVE_SOURCE_DIR}/app/platform/linux/NativeSourcePedControl.cpp"
    "${NATIVE_SOURCE_DIR}/app/platform/linux/NativeSourceJump.cpp"
    "${NATIVE_SOURCE_DIR}/app/platform/linux/NativeSourceAnimClump.cpp"
    "${NATIVE_SOURCE_DIR}/app/platform/linux/NativeSourceTaskManager.cpp"
    "${NATIVE_SOURCE_DIR}/app/platform/linux/NativeSourceWalkRun.cpp"
    "${NATIVE_SOURCE_DIR}/app/platform/linux/NativeSourcePedTasks.cpp"
    "${NATIVE_SOURCE_DIR}/app/platform/linux/NativeSourcePhysical.cpp"
    "${NATIVE_SOURCE_DIR}/app/platform/linux/NativeSourceContact.cpp"
    "${NATIVE_SOURCE_DIR}/app/platform/linux/NativeSourceModelContact.cpp"
    "${NATIVE_SOURCE_DIR}/app/platform/linux/NativeSourcePedCollision.cpp"
    "${NATIVE_SOURCE_DIR}/app/platform/linux/NativeSourcePedModelContact.cpp"
    "${NATIVE_SOURCE_DIR}/app/platform/linux/NativeSourceSurfaces.cpp"
    "${NATIVE_SOURCE_DIR}/app/platform/linux/NativeSourcePedResponse.cpp"
    "${NATIVE_SOURCE_DIR}/app/platform/linux/NativeSourcePedWorld.cpp"
    "${NATIVE_SOURCE_DIR}/app/platform/linux/NativeSourceCamera.cpp"
    "${NATIVE_SOURCE_DIR}/app/platform/linux/NativeFrontendLifecycle.cpp"
    "${NATIVE_SOURCE_DIR}/app/platform/linux/GxtText.cpp"
    "${NATIVE_SOURCE_DIR}/app/platform/linux/NativeTextFamilies.cpp"
    "${NATIVE_SOURCE_DIR}/app/platform/linux/NativeInputLifecycle.cpp"
    "${NATIVE_SOURCE_DIR}/game_sa/SurfaceInfos_c.cpp"
    "${NATIVE_SOURCE_DIR}/app/platform/linux/NativeCollisionAssets.cpp"
    "${NATIVE_SOURCE_DIR}/app/platform/linux/NativeWorldEntityInfo.cpp"
    "${NATIVE_SOURCE_DIR}/app/platform/linux/NativeSourceGround.cpp"
    "${NATIVE_SOURCE_DIR}/app/platform/linux/NativeWorldGround.cpp"
    "${CMAKE_CURRENT_LIST_DIR}/os_file_posix.cpp"
)
add_library(sa_core STATIC ${SA_CORE_SOURCES})
# Compile only the existing canonical name lookup, without DLL globals/hooks.
set_source_files_properties("${NATIVE_SOURCE_DIR}/game_sa/SurfaceInfos_c.cpp"
    PROPERTIES COMPILE_DEFINITIONS GTA_SA_CORE_SURFACE_NAMES)
target_include_directories(sa_core PUBLIC
    "${CMAKE_CURRENT_LIST_DIR}"
    "${NATIVE_SOURCE_DIR}"
)
target_compile_features(sa_core PUBLIC cxx_std_20)
if(CMAKE_CXX_COMPILER_ID MATCHES "GNU|Clang")
    target_compile_options(sa_core PRIVATE -Wall -Wextra -Wpedantic)
    set_source_files_properties(
        "${NATIVE_SOURCE_DIR}/app/platform/linux/NativeScriptCorpus.cpp"
        "${NATIVE_SOURCE_DIR}/app/platform/linux/NativeScriptContentLedger.cpp"
        "${NATIVE_SOURCE_DIR}/app/platform/linux/NativeStoryLifecycle.cpp"
        "${NATIVE_SOURCE_DIR}/app/platform/linux/NativeActivityLifecycle.cpp"
        "${NATIVE_SOURCE_DIR}/app/platform/linux/NativeProgressionRuntime.cpp"
        "${NATIVE_SOURCE_DIR}/app/platform/linux/NativeSpecialStateManifest.cpp"
        "${NATIVE_SOURCE_DIR}/app/platform/linux/NativePcSaveCodec.cpp"
        "${NATIVE_SOURCE_DIR}/app/platform/linux/NativeEnvironmentLifecycle.cpp"
        "${NATIVE_SOURCE_DIR}/app/platform/linux/NativeScriptSession.cpp"
        "${NATIVE_SOURCE_DIR}/app/platform/linux/NativeScriptFrame.cpp"
        "${NATIVE_SOURCE_DIR}/app/platform/linux/NativeScriptServiceTransaction.cpp"
        "${NATIVE_SOURCE_DIR}/app/platform/linux/NativeScriptPortableSave.cpp"
        PROPERTIES COMPILE_OPTIONS "-fexceptions"
    )
    # Strict source float semantics for the clock, the reused RNG, and the
    # pad axis quantizer; no source-file edits, only build flags.
    set_source_files_properties(
        "${NATIVE_SOURCE_DIR}/app/platform/linux/NativeSourceClock.cpp"
        "${NATIVE_SOURCE_DIR}/app/platform/linux/NativeSourceRng.cpp"
        "${NATIVE_SOURCE_DIR}/app/platform/linux/NativeSourcePad.cpp"
        "${NATIVE_SOURCE_DIR}/app/platform/linux/NativeSourcePedControl.cpp"
        "${NATIVE_SOURCE_DIR}/app/platform/linux/NativeSourceJump.cpp"
        "${NATIVE_SOURCE_DIR}/app/platform/linux/NativeSourceAnimClump.cpp"
        "${NATIVE_SOURCE_DIR}/app/platform/linux/NativeSourceWalkRun.cpp"
        "${NATIVE_SOURCE_DIR}/app/platform/linux/NativeSourcePedTasks.cpp"
        "${NATIVE_SOURCE_DIR}/app/platform/linux/NativeSourcePhysical.cpp"
        "${NATIVE_SOURCE_DIR}/app/platform/linux/NativeSourceContact.cpp"
        "${NATIVE_SOURCE_DIR}/app/platform/linux/NativeSourceModelContact.cpp"
        "${NATIVE_SOURCE_DIR}/app/platform/linux/NativeSourcePedCollision.cpp"
        "${NATIVE_SOURCE_DIR}/app/platform/linux/NativeSourcePedModelContact.cpp"
        "${NATIVE_SOURCE_DIR}/app/platform/linux/NativeSourceCamera.cpp"
        "${NATIVE_SOURCE_DIR}/app/platform/linux/NativeFrontendLifecycle.cpp"
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
        "${NATIVE_SOURCE_DIR}/app/platform/linux/NativeSourceSurfaces.cpp"
        "${NATIVE_SOURCE_DIR}/app/platform/linux/NativeSourcePedResponse.cpp"
        "${NATIVE_SOURCE_DIR}/app/platform/linux/NativeSourcePedWorld.cpp"
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
add_executable(sa_core_script_content_probe
    "${NATIVE_SOURCE_DIR}/app/platform/linux/NativeScriptContentLedgerProbe.cpp")
target_link_libraries(sa_core_script_content_probe PRIVATE sa_core)
add_executable(sa_core_story_lifecycle_probe
    "${NATIVE_SOURCE_DIR}/app/platform/linux/NativeStoryLifecycleProbe.cpp")
target_link_libraries(sa_core_story_lifecycle_probe PRIVATE sa_core)
add_executable(sa_first_mission_save_probe
    "${NATIVE_SOURCE_DIR}/app/platform/linux/NativeFirstMissionSaveProbe.cpp")
target_link_libraries(sa_first_mission_save_probe PRIVATE sa_core)
add_executable(sa_movie_runtime_probe
    "${NATIVE_SOURCE_DIR}/app/platform/linux/NativeMovieRuntimeProbe.cpp"
    "${NATIVE_SOURCE_DIR}/app/platform/linux/NativeMovieRuntime.cpp")
target_link_libraries(sa_movie_runtime_probe PRIVATE PkgConfig::FFMPEG)
target_compile_features(sa_movie_runtime_probe PRIVATE cxx_std_20)
if(CMAKE_CXX_COMPILER_ID MATCHES "GNU|Clang")
    target_compile_options(sa_movie_runtime_probe PRIVATE -Wall -Wextra -Wpedantic)
endif()
add_executable(sa_core_activity_lifecycle_probe
    "${NATIVE_SOURCE_DIR}/app/platform/linux/NativeActivityLifecycleProbe.cpp")
target_link_libraries(sa_core_activity_lifecycle_probe PRIVATE sa_core)
add_executable(sa_core_progression_runtime_probe
    "${NATIVE_SOURCE_DIR}/app/platform/linux/NativeProgressionRuntimeProbe.cpp")
target_link_libraries(sa_core_progression_runtime_probe PRIVATE sa_core)
add_executable(sa_core_special_state_probe
    "${NATIVE_SOURCE_DIR}/app/platform/linux/NativeSpecialStateManifestProbe.cpp")
target_link_libraries(sa_core_special_state_probe PRIVATE sa_core)
add_executable(sa_core_pc_save_codec_probe
    "${NATIVE_SOURCE_DIR}/app/platform/linux/NativePcSaveCodecProbe.cpp")
target_link_libraries(sa_core_pc_save_codec_probe PRIVATE sa_core)
add_executable(sa_core_pc_save_semantics_probe
    "${NATIVE_SOURCE_DIR}/app/platform/linux/NativePcSaveSemanticsProbe.cpp")
target_link_libraries(sa_core_pc_save_semantics_probe PRIVATE sa_core)
add_executable(sa_environment_lifecycle_probe
    "${NATIVE_SOURCE_DIR}/app/platform/linux/NativeEnvironmentLifecycleProbe.cpp")
target_link_libraries(sa_environment_lifecycle_probe PRIVATE sa_core)
add_executable(sa_effect_families_probe
    "${NATIVE_SOURCE_DIR}/app/platform/linux/NativeEffectFamiliesProbe.cpp")
target_link_libraries(sa_effect_families_probe PRIVATE sa_core)
add_executable(sa_core_scheduling_probe
    "${NATIVE_SOURCE_DIR}/app/platform/linux/NativeScriptSchedulingProbe.cpp")
target_link_libraries(sa_core_scheduling_probe PRIVATE sa_core)
add_executable(sa_core_service_transactions_probe
    "${NATIVE_SOURCE_DIR}/app/platform/linux/NativeScriptServiceTransactionProbe.cpp")
target_link_libraries(sa_core_service_transactions_probe PRIVATE sa_core)
add_executable(sa_core_portable_save_probe
    "${NATIVE_SOURCE_DIR}/app/platform/linux/NativeScriptPortableSaveProbe.cpp")
target_link_libraries(sa_core_portable_save_probe PRIVATE sa_core)
add_executable(sa_core_stunt_jumps_probe
    "${NATIVE_SOURCE_DIR}/app/platform/linux/NativeStuntJumpsProbe.cpp")
target_link_libraries(sa_core_stunt_jumps_probe PRIVATE sa_core)
add_executable(sa_core_set_pieces_probe
    "${NATIVE_SOURCE_DIR}/app/platform/linux/NativeSetPiecesProbe.cpp")
target_link_libraries(sa_core_set_pieces_probe PRIVATE sa_core)
add_executable(sa_core_zone_population_probe
    "${NATIVE_SOURCE_DIR}/app/platform/linux/NativeZonePopulationProbe.cpp")
target_link_libraries(sa_core_zone_population_probe PRIVATE sa_core)
add_executable(sa_core_path_policy_probe "${NATIVE_SOURCE_DIR}/app/platform/linux/NativePathPolicyProbe.cpp")
target_link_libraries(sa_core_path_policy_probe PRIVATE sa_core)
add_executable(sa_core_external_triggers_probe "${NATIVE_SOURCE_DIR}/app/platform/linux/NativeExternalScriptTriggersProbe.cpp")
target_link_libraries(sa_core_external_triggers_probe PRIVATE sa_core)
add_executable(sa_core_model_anims_probe "${NATIVE_SOURCE_DIR}/app/platform/linux/NativeScriptModelAnimsProbe.cpp")
target_link_libraries(sa_core_model_anims_probe PRIVATE sa_core)
add_executable(sa_core_ipl_requests_probe "${NATIVE_SOURCE_DIR}/app/platform/linux/NativeScriptIplRequestsProbe.cpp")
target_link_libraries(sa_core_ipl_requests_probe PRIVATE sa_core)
add_executable(sa_core_world_object_overrides_probe "${NATIVE_SOURCE_DIR}/app/platform/linux/NativeWorldObjectOverridesProbe.cpp")
target_link_libraries(sa_core_world_object_overrides_probe PRIVATE sa_core)
add_executable(sa_core_weather_probe "${NATIVE_SOURCE_DIR}/app/platform/linux/NativeScriptWeatherProbe.cpp")
target_link_libraries(sa_core_weather_probe PRIVATE sa_core)
add_executable(sa_core_clothes_probe "${NATIVE_SOURCE_DIR}/app/platform/linux/NativeScriptClothesProbe.cpp")
target_link_libraries(sa_core_clothes_probe PRIVATE sa_core)
add_executable(sa_core_mission_text_probe "${NATIVE_SOURCE_DIR}/app/platform/linux/NativeMissionTextProbe.cpp")
target_link_libraries(sa_core_mission_text_probe PRIVATE sa_core)
add_executable(sa_core_car_recordings_probe "${NATIVE_SOURCE_DIR}/app/platform/linux/NativeCarRecordingsProbe.cpp")
target_link_libraries(sa_core_car_recordings_probe PRIVATE sa_core)
add_executable(sa_core_beat_track_probe "${NATIVE_SOURCE_DIR}/app/platform/linux/NativeBeatTrackProbe.cpp")
target_link_libraries(sa_core_beat_track_probe PRIVATE sa_core)
add_executable(sa_core_mission_audio_probe "${NATIVE_SOURCE_DIR}/app/platform/linux/NativeMissionAudioProbe.cpp")
target_link_libraries(sa_core_mission_audio_probe PRIVATE sa_core)
add_executable(sa_core_script_peds_probe "${NATIVE_SOURCE_DIR}/app/platform/linux/NativeScriptPedsProbe.cpp")
target_link_libraries(sa_core_script_peds_probe PRIVATE sa_core)
add_executable(sa_core_script_trains_probe "${NATIVE_SOURCE_DIR}/app/platform/linux/NativeScriptTrainsProbe.cpp")
target_link_libraries(sa_core_script_trains_probe PRIVATE sa_core)
add_executable(sa_core_objects_probe
    "${NATIVE_SOURCE_DIR}/app/platform/linux/NativeScriptObjectsProbe.cpp")
target_link_libraries(sa_core_objects_probe PRIVATE sa_core)
add_executable(sa_object_lifecycle_probe
    "${NATIVE_SOURCE_DIR}/app/platform/linux/NativeObjectLifecycleProbe.cpp")
target_link_libraries(sa_object_lifecycle_probe PRIVATE sa_core)
add_executable(sa_core_ped_control_probe "${NATIVE_SOURCE_DIR}/app/platform/linux/NativeSourcePedControlProbe.cpp")
target_link_libraries(sa_core_ped_control_probe PRIVATE sa_core)
add_executable(sa_core_jump_probe "${NATIVE_SOURCE_DIR}/app/platform/linux/NativeSourceJumpProbe.cpp")
target_link_libraries(sa_core_jump_probe PRIVATE sa_core)
add_executable(sa_core_clump_probe "${NATIVE_SOURCE_DIR}/app/platform/linux/NativeSourceAnimClumpProbe.cpp")
target_link_libraries(sa_core_clump_probe PRIVATE sa_core)
add_executable(sa_core_tasks_probe "${NATIVE_SOURCE_DIR}/app/platform/linux/NativeSourceTaskManagerProbe.cpp")
target_link_libraries(sa_core_tasks_probe PRIVATE sa_core)
add_executable(sa_core_walk_run_probe "${NATIVE_SOURCE_DIR}/app/platform/linux/NativeSourceWalkRunProbe.cpp")
target_link_libraries(sa_core_walk_run_probe PRIVATE sa_core)
add_executable(sa_core_ped_tasks_probe "${NATIVE_SOURCE_DIR}/app/platform/linux/NativeSourcePedTasksProbe.cpp")
target_link_libraries(sa_core_ped_tasks_probe PRIVATE sa_core)
add_executable(sa_core_physical_probe "${NATIVE_SOURCE_DIR}/app/platform/linux/NativeSourcePhysicalProbe.cpp")
target_link_libraries(sa_core_physical_probe PRIVATE sa_core)
add_executable(sa_core_contact_probe "${NATIVE_SOURCE_DIR}/app/platform/linux/NativeSourceContactProbe.cpp")
target_link_libraries(sa_core_contact_probe PRIVATE sa_core)
add_executable(sa_core_model_contact_probe "${NATIVE_SOURCE_DIR}/app/platform/linux/NativeSourceModelContactProbe.cpp")
target_link_libraries(sa_core_model_contact_probe PRIVATE sa_core)
add_executable(sa_core_ped_collision_probe "${NATIVE_SOURCE_DIR}/app/platform/linux/NativeSourcePedCollisionProbe.cpp")
target_link_libraries(sa_core_ped_collision_probe PRIVATE sa_core)
add_executable(sa_core_ped_model_probe "${NATIVE_SOURCE_DIR}/app/platform/linux/NativeSourcePedModelContactProbe.cpp")
target_link_libraries(sa_core_ped_model_probe PRIVATE sa_core)
add_executable(sa_core_surfaces_probe "${NATIVE_SOURCE_DIR}/app/platform/linux/NativeSourceSurfacesProbe.cpp")
target_link_libraries(sa_core_surfaces_probe PRIVATE sa_core)
add_executable(sa_core_ped_response_probe "${NATIVE_SOURCE_DIR}/app/platform/linux/NativeSourcePedResponseProbe.cpp")
target_link_libraries(sa_core_ped_response_probe PRIVATE sa_core)
add_executable(sa_core_ped_world_probe "${NATIVE_SOURCE_DIR}/app/platform/linux/NativeSourcePedWorldProbe.cpp")
target_link_libraries(sa_core_ped_world_probe PRIVATE sa_core)
add_executable(sa_core_camera_probe "${NATIVE_SOURCE_DIR}/app/platform/linux/NativeSourceCameraProbe.cpp")
target_link_libraries(sa_core_camera_probe PRIVATE sa_core)
add_executable(sa_core_frontend_probe "${NATIVE_SOURCE_DIR}/app/platform/linux/NativeFrontendLifecycleProbe.cpp")
target_link_libraries(sa_core_frontend_probe PRIVATE sa_core)
add_executable(sa_core_text_families_probe
    "${NATIVE_SOURCE_DIR}/app/platform/linux/NativeTextFamiliesProbe.cpp"
    "${NATIVE_SOURCE_DIR}/app/platform/linux/MenuShot.cpp")
target_link_libraries(sa_core_text_families_probe PRIVATE sa_diagnostic sa_core)
add_executable(sa_core_input_lifecycle_probe
    "${NATIVE_SOURCE_DIR}/app/platform/linux/NativeInputLifecycleProbe.cpp")
target_link_libraries(sa_core_input_lifecycle_probe PRIVATE sa_core)
add_executable(sa_core_audio_families_probe
    "${NATIVE_SOURCE_DIR}/app/platform/linux/NativeAudioFamiliesProbe.cpp")
target_link_libraries(sa_core_audio_families_probe PRIVATE sa_core)
add_executable(sa_core_radio_runtime_probe
    "${NATIVE_SOURCE_DIR}/app/platform/linux/NativeRadioRuntimeProbe.cpp")
target_link_libraries(sa_core_radio_runtime_probe PRIVATE sa_core)
if(CMAKE_CXX_COMPILER_ID MATCHES "GNU|Clang")
    target_compile_options(sa_core_frame_probe PRIVATE -Wall -Wextra -Wpedantic)
    target_compile_options(sa_core_session_probe PRIVATE -Wall -Wextra -Wpedantic)
    target_compile_options(sa_core_script_content_probe PRIVATE -Wall -Wextra -Wpedantic)
    target_compile_options(sa_core_story_lifecycle_probe PRIVATE -Wall -Wextra -Wpedantic)
    target_compile_options(sa_core_activity_lifecycle_probe PRIVATE -Wall -Wextra -Wpedantic)
    target_compile_options(sa_core_progression_runtime_probe PRIVATE -Wall -Wextra -Wpedantic)
    target_compile_options(sa_core_special_state_probe PRIVATE -Wall -Wextra -Wpedantic)
    target_compile_options(sa_core_scheduling_probe PRIVATE -Wall -Wextra -Wpedantic)
    target_compile_options(sa_core_service_transactions_probe PRIVATE -Wall -Wextra -Wpedantic)
    target_compile_options(sa_core_portable_save_probe PRIVATE -Wall -Wextra -Wpedantic)
    target_compile_options(sa_core_stunt_jumps_probe PRIVATE -Wall -Wextra -Wpedantic)
    target_compile_options(sa_core_set_pieces_probe PRIVATE -Wall -Wextra -Wpedantic)
    target_compile_options(sa_core_zone_population_probe PRIVATE -Wall -Wextra -Wpedantic)
    target_compile_options(sa_core_path_policy_probe PRIVATE -Wall -Wextra -Wpedantic)
    target_compile_options(sa_core_external_triggers_probe PRIVATE -Wall -Wextra -Wpedantic)
    target_compile_options(sa_core_model_anims_probe PRIVATE -Wall -Wextra -Wpedantic)
    target_compile_options(sa_core_ipl_requests_probe PRIVATE -Wall -Wextra -Wpedantic)
    target_compile_options(sa_core_world_object_overrides_probe PRIVATE -Wall -Wextra -Wpedantic)
    target_compile_options(sa_core_objects_probe PRIVATE -Wall -Wextra -Wpedantic)
    target_compile_options(sa_core_ped_control_probe PRIVATE -Wall -Wextra -Wpedantic -fno-fast-math -ffp-contract=off)
    target_compile_options(sa_core_jump_probe PRIVATE -Wall -Wextra -Wpedantic -fno-fast-math -ffp-contract=off)
    target_compile_options(sa_core_clump_probe PRIVATE -Wall -Wextra -Wpedantic -fno-fast-math -ffp-contract=off)
    target_compile_options(sa_core_tasks_probe PRIVATE -Wall -Wextra -Wpedantic -fno-fast-math -ffp-contract=off)
    target_compile_options(sa_core_walk_run_probe PRIVATE -Wall -Wextra -Wpedantic -fno-fast-math -ffp-contract=off)
    target_compile_options(sa_core_ped_tasks_probe PRIVATE -Wall -Wextra -Wpedantic -fno-fast-math -ffp-contract=off)
    target_compile_options(sa_core_physical_probe PRIVATE -Wall -Wextra -Wpedantic -fno-fast-math -ffp-contract=off)
    target_compile_options(sa_core_contact_probe PRIVATE -Wall -Wextra -Wpedantic -fno-fast-math -ffp-contract=off)
    target_compile_options(sa_core_model_contact_probe PRIVATE -Wall -Wextra -Wpedantic -fno-fast-math -ffp-contract=off)
    target_compile_options(sa_core_ped_collision_probe PRIVATE -Wall -Wextra -Wpedantic -fno-fast-math -ffp-contract=off)
    target_compile_options(sa_core_ped_model_probe PRIVATE -Wall -Wextra -Wpedantic -fno-fast-math -ffp-contract=off)
    target_compile_options(sa_core_surfaces_probe PRIVATE -Wall -Wextra -Wpedantic -fno-fast-math -ffp-contract=off)
    target_compile_options(sa_core_ped_response_probe PRIVATE -Wall -Wextra -Wpedantic -fno-fast-math -ffp-contract=off)
    target_compile_options(sa_core_ped_world_probe PRIVATE -Wall -Wextra -Wpedantic -fno-fast-math -ffp-contract=off)
    target_compile_options(sa_core_camera_probe PRIVATE -Wall -Wextra -Wpedantic -fno-fast-math -ffp-contract=off)
    target_compile_options(sa_core_frontend_probe PRIVATE -Wall -Wextra -Wpedantic -fno-fast-math -ffp-contract=off)
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
add_executable(sa_world_residency_probe
    "${NATIVE_SOURCE_DIR}/app/platform/linux/NativeWorldResidencyProbe.cpp"
    "${NATIVE_SOURCE_DIR}/app/platform/linux/NativeWorldResidency.cpp"
    "${NATIVE_SOURCE_DIR}/app/platform/linux/NativeLodCatalog.cpp")
target_link_libraries(sa_world_residency_probe PRIVATE sa_diagnostic)
if(CMAKE_CXX_COMPILER_ID MATCHES "GNU|Clang")
    target_compile_options(sa_world_residency_probe PRIVATE
        -Wall -Wextra -Wpedantic -fexceptions -fno-fast-math -ffp-contract=off)
endif()
add_executable(sa_world_visibility_probe
    "${NATIVE_SOURCE_DIR}/app/platform/linux/NativeWorldVisibilityProbe.cpp"
    "${NATIVE_SOURCE_DIR}/app/platform/linux/NativeWorldVisibility.cpp"
    "${NATIVE_SOURCE_DIR}/app/platform/linux/NativeLodCatalog.cpp")
target_link_libraries(sa_world_visibility_probe PRIVATE sa_diagnostic)
if(CMAKE_CXX_COMPILER_ID MATCHES "GNU|Clang")
    target_compile_options(sa_world_visibility_probe PRIVATE
        -Wall -Wextra -Wpedantic -fexceptions -fno-fast-math -ffp-contract=off)
endif()

# P2-A03 extension seam: static sa_core link AFTER both targets are defined.
# The archive pulls ONLY the Pad object (SubmitSample/QuantizeAxis/FormatFrame/
# StatusName); Session/Clock/IO objects stay unreferenced. exports.map keeps
# its single sa_legacy_library_init entry; bind/data/worker/.so APIs unchanged.
target_link_libraries(sa_legacy PRIVATE sa_core)

# P2-A06 diagnostic native controller reuse; kept OUT of pure sa_core.
set(SA_DIAGNOSTIC_SOURCES)
foreach(name NativeDiagnosticActors RealtimeGameplay NativePlayerActivity NativePlayerAssets
    IfpAnim SkinPed CsAnim NativePoseFamilies CarPose Handling Collide ColLoad StreamPager TexSample)
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
add_executable(sa_script_appearance_probe "${NATIVE_SOURCE_DIR}/app/platform/linux/NativeScriptAppearanceProbe.cpp")
target_link_libraries(sa_script_appearance_probe PRIVATE sa_diagnostic)
if(CMAKE_CXX_COMPILER_ID MATCHES "GNU|Clang")
    target_compile_options(sa_script_appearance_probe PRIVATE
        -Wall -Wextra -Wpedantic -fexceptions -fno-fast-math -ffp-contract=off)
endif()
add_executable(sa_pose_families_probe
    "${NATIVE_SOURCE_DIR}/app/platform/linux/NativePoseFamiliesProbe.cpp")
target_link_libraries(sa_pose_families_probe PRIVATE sa_diagnostic)
if(CMAKE_CXX_COMPILER_ID MATCHES "GNU|Clang")
    target_compile_options(sa_pose_families_probe PRIVATE
        -Wall -Wextra -Wpedantic -fexceptions -fno-fast-math -ffp-contract=off)
endif()
add_executable(sa_script_texture_probe
    "${NATIVE_SOURCE_DIR}/app/platform/linux/NativeScriptTextureProbe.cpp"
    "${NATIVE_SOURCE_DIR}/app/platform/linux/NativeScriptEntities.cpp"
    "${NATIVE_SOURCE_DIR}/app/platform/linux/MenuShot.cpp")
target_link_libraries(sa_script_texture_probe PRIVATE sa_diagnostic)
if(CMAKE_CXX_COMPILER_ID MATCHES "GNU|Clang")
    target_compile_options(sa_script_texture_probe PRIVATE
        -Wall -Wextra -Wpedantic -fexceptions -fno-fast-math -ffp-contract=off)
endif()
add_executable(sa_vehicle_families_probe
    "${NATIVE_SOURCE_DIR}/app/platform/linux/NativeVehicleFamiliesProbe.cpp"
    "${NATIVE_SOURCE_DIR}/app/platform/linux/NativeCarGenerators.cpp"
    "${NATIVE_SOURCE_DIR}/app/platform/linux/NativeVehiclePool.cpp")
target_link_libraries(sa_vehicle_families_probe PRIVATE sa_diagnostic)
add_executable(sa_vehicle_family_control_probe
    "${NATIVE_SOURCE_DIR}/app/platform/linux/NativeVehicleFamilyControlProbe.cpp")
target_link_libraries(sa_vehicle_family_control_probe PRIVATE sa_core)
add_executable(sa_vehicle_family_lifecycle_probe
    "${NATIVE_SOURCE_DIR}/app/platform/linux/NativeVehicleFamilyLifecycleProbe.cpp"
    "${NATIVE_SOURCE_DIR}/app/platform/linux/NativeCarGenerators.cpp"
    "${NATIVE_SOURCE_DIR}/app/platform/linux/NativeVehiclePool.cpp")
target_link_libraries(sa_vehicle_family_lifecycle_probe PRIVATE sa_core)
add_executable(sa_path_graph_probe
    "${NATIVE_SOURCE_DIR}/app/platform/linux/NativePathGraphProbe.cpp")
target_link_libraries(sa_path_graph_probe PRIVATE sa_core)
add_executable(sa_source_event_flow_probe
    "${NATIVE_SOURCE_DIR}/app/platform/linux/NativeSourceEventFlowProbe.cpp")
target_link_libraries(sa_source_event_flow_probe PRIVATE sa_core)
add_executable(sa_population_runtime_probe
    "${NATIVE_SOURCE_DIR}/app/platform/linux/NativePopulationRuntimeProbe.cpp")
target_link_libraries(sa_population_runtime_probe PRIVATE sa_core)
add_executable(sa_combat_runtime_probe
    "${NATIVE_SOURCE_DIR}/app/platform/linux/NativeCombatRuntimeProbe.cpp")
target_link_libraries(sa_combat_runtime_probe PRIVATE sa_core)
add_executable(sa_wanted_runtime_probe
    "${NATIVE_SOURCE_DIR}/app/platform/linux/NativeWantedRuntimeProbe.cpp")
target_link_libraries(sa_wanted_runtime_probe PRIVATE sa_core)
add_executable(sa_restart_lifecycle_probe
    "${NATIVE_SOURCE_DIR}/app/platform/linux/NativeRestartLifecycleProbe.cpp"
    "${NATIVE_SOURCE_DIR}/app/platform/linux/NativeRestarts.cpp"
    "${NATIVE_SOURCE_DIR}/app/platform/linux/ZoneInfo.cpp")
target_link_libraries(sa_restart_lifecycle_probe PRIVATE sa_core)
add_executable(sa_interaction_runtime_probe
    "${NATIVE_SOURCE_DIR}/app/platform/linux/NativeInteractionRuntimeProbe.cpp")
target_link_libraries(sa_interaction_runtime_probe PRIVATE sa_core)
if(CMAKE_CXX_COMPILER_ID MATCHES "GNU|Clang")
    target_compile_options(sa_vehicle_families_probe PRIVATE
        -Wall -Wextra -Wpedantic -fexceptions -fno-fast-math -ffp-contract=off)
    target_compile_options(sa_vehicle_family_control_probe PRIVATE
        -Wall -Wextra -Wpedantic -fno-fast-math -ffp-contract=off)
    target_compile_options(sa_vehicle_family_lifecycle_probe PRIVATE
        -Wall -Wextra -Wpedantic -fexceptions -fno-fast-math -ffp-contract=off)
    target_compile_options(sa_path_graph_probe PRIVATE
        -Wall -Wextra -Wpedantic -fexceptions -fno-fast-math -ffp-contract=off)
    target_compile_options(sa_source_event_flow_probe PRIVATE
        -Wall -Wextra -Wpedantic -fexceptions -fno-fast-math -ffp-contract=off)
    target_compile_options(sa_population_runtime_probe PRIVATE
        -Wall -Wextra -Wpedantic -fexceptions -fno-fast-math -ffp-contract=off)
    target_compile_options(sa_combat_runtime_probe PRIVATE
        -Wall -Wextra -Wpedantic -fexceptions -fno-fast-math -ffp-contract=off)
    target_compile_options(sa_wanted_runtime_probe PRIVATE
        -Wall -Wextra -Wpedantic -fexceptions -fno-fast-math -ffp-contract=off)
    target_compile_options(sa_restart_lifecycle_probe PRIVATE
        -Wall -Wextra -Wpedantic -fexceptions -fno-fast-math -ffp-contract=off)
    target_compile_options(sa_interaction_runtime_probe PRIVATE
        -Wall -Wextra -Wpedantic -fexceptions -fno-fast-math -ffp-contract=off)
endif()
add_executable(sa_source_clump_assets_probe "${NATIVE_SOURCE_DIR}/app/platform/linux/NativeSourceClumpAssetsProbe.cpp")
target_link_libraries(sa_source_clump_assets_probe PRIVATE sa_diagnostic)
add_executable(sa_source_automobile_probe
    "${NATIVE_SOURCE_DIR}/app/platform/linux/NativeSourceAutomobileProbe.cpp"
    "${NATIVE_SOURCE_DIR}/app/platform/linux/NativeSourceAutomobile.cpp"
    "${NATIVE_SOURCE_DIR}/app/platform/linux/NativeGeneratedVehicleAssets.cpp"
    "${NATIVE_SOURCE_DIR}/app/platform/linux/NativeCarGenerators.cpp"
    "${NATIVE_SOURCE_DIR}/app/platform/linux/NativeVehiclePool.cpp"
    "${NATIVE_SOURCE_DIR}/app/platform/linux/Handling.cpp")
target_link_libraries(sa_source_automobile_probe PRIVATE sa_diagnostic)
if(CMAKE_CXX_COMPILER_ID MATCHES "GNU|Clang")
    target_compile_options(sa_source_automobile_probe PRIVATE
        -Wall -Wextra -Wpedantic -fexceptions -fno-fast-math -ffp-contract=off)
endif()
add_executable(sa_source_vehicle_lifecycle_probe
    "${NATIVE_SOURCE_DIR}/app/platform/linux/NativeSourceVehicleLifecycleProbe.cpp"
    "${NATIVE_SOURCE_DIR}/app/platform/linux/NativeSourceVehicleLifecycle.cpp"
    "${NATIVE_SOURCE_DIR}/app/platform/linux/NativeSourceSliceFeedback.cpp"
    "${NATIVE_SOURCE_DIR}/app/platform/linux/SfxDecode.cpp"
    "${NATIVE_SOURCE_DIR}/app/platform/linux/NativeSourceAutomobile.cpp"
    "${NATIVE_SOURCE_DIR}/app/platform/linux/NativeGeneratedVehicleAssets.cpp"
    "${NATIVE_SOURCE_DIR}/app/platform/linux/NativeVehicleAssetQueue.cpp"
    "${NATIVE_SOURCE_DIR}/app/platform/linux/NativeCarGenerators.cpp"
    "${NATIVE_SOURCE_DIR}/app/platform/linux/NativeVehiclePool.cpp"
    "${NATIVE_SOURCE_DIR}/app/platform/linux/Handling.cpp")
target_link_libraries(sa_source_vehicle_lifecycle_probe PRIVATE sa_diagnostic)
if(CMAKE_CXX_COMPILER_ID MATCHES "GNU|Clang")
    target_compile_options(sa_source_vehicle_lifecycle_probe PRIVATE
        -Wall -Wextra -Wpedantic -fexceptions -fno-fast-math -ffp-contract=off)
endif()
target_link_libraries(sa_legacy PRIVATE sa_diagnostic)
