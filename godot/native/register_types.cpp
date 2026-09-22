#include "sa_input_bridge.h"
#include "sa_camera_bridge.h"
#include "sa_legacy_bridge.h"
#include "sa_pose_bridge.h"

#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/godot.hpp>

using namespace godot;

static void InitialiseSALegacy(ModuleInitializationLevel level) {
    if (level == MODULE_INITIALIZATION_LEVEL_SCENE) {
        ClassDB::register_class<SALegacyBridge>();
        ClassDB::register_class<SALegacyInput>();
        ClassDB::register_class<SALegacyCamera>();
        ClassDB::register_class<SALegacyPose>();
    }
}

static void UninitialiseSALegacy(ModuleInitializationLevel level) {
    (void)level;
}

extern "C" GDExtensionBool GDE_EXPORT sa_legacy_library_init(
    GDExtensionInterfaceGetProcAddress getProcAddress,
    GDExtensionClassLibraryPtr library,
    GDExtensionInitialization* initialization) {
    GDExtensionBinding::InitObject init(getProcAddress, library, initialization);
    init.register_initializer(InitialiseSALegacy);
    init.register_terminator(UninitialiseSALegacy);
    init.set_minimum_library_initialization_level(MODULE_INITIALIZATION_LEVEL_SCENE);
    return init.init();
}
