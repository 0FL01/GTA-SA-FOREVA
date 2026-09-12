// P2-A03 Godot input seam: registered SCENE Node receiving actual Godot
// joypad callbacks for physical device 0, then sampling the sibling-owned
// pure NativeSourcePad at explicit caller timestamps.
//
// Device mapping (persistent physical device 0 only):
//   JOY_BUTTON_X (2) -> mask 0x01 (Jump/Square, bit value 1)
//   JOY_BUTTON_A (0) -> mask 0x02 (Sprint/Cross, bit value 2)
//   JOY_BUTTON_Y (3) -> mask 0x04 (Enter/Triangle, bit value 4)
//   JOY_AXIS_LEFT_X (0), JOY_AXIS_LEFT_Y (1) -> stored float, quantized at
//     sample time via NativeSourcePad::QuantizeAxis (default source profile:
//     abs <= 0.3 => 0 else trunc(v * 128); finite [-1,1] rejects, never clamps).
// Other devices, event types, buttons, and axes are ignored (counted, never
// stored). No keyboard, focus, hotplug, remap, pause mapping, clock calls,
// frame auto-latch, sequence inference, CJ, or freecamera coupling. This Node
// is an available input seam, not a playable-input claim.
//
// _ready() enables input via set_process_input(true). _input() is the actual
// Godot virtual callback (no direct-call test path). sample()/snapshot()
// expose the last COMMITTED core frame; failed samples leave state unchanged
// and report the prior frame, never a partial candidate. Counters
// received/ignored/rejected plus last_event_status diagnose the callback path
// (snapshot never consumes pressed/released edges).
//
// Frozen core API (owned by sibling NativeSourcePad.h, never stubbed here):
//   namespace GLOBAL: enum NativeSourcePadStatus{Ok,DuplicateIdempotent,
//     InvalidSequence,DuplicateConflict,BackwardTick,InvalidButtons,
//     NonFiniteAxis,AxisOutOfRange};
//   struct NativeSourcePadSample{uint64 Seq,Tick; int16 MoveX,MoveY;
//     uint8 Buttons};
//   struct NativeSourcePadFrame{Sample Sample; uint8 Down,Pressed,Released};
//   class NativeSourcePad{SubmitSample/LastFrame/HasFrame/static
//     QuantizeAxis/FormatFrame/StatusName}. All state value-owned.
// Adapter inherits -fno-exceptions; core FormatFrame returns a fixed array so
// no std allocation exception path exists on the sample/snapshot path.
#pragma once

#include <godot_cpp/classes/input_event.hpp>
#include <godot_cpp/classes/node.hpp>
#include <godot_cpp/variant/dictionary.hpp>

#include <cstdint>

#include "app/platform/linux/NativeSourcePad.h"

namespace godot {

class SALegacyInput : public Node {
    GDCLASS(SALegacyInput, Node)

public:
    SALegacyInput();
    ~SALegacyInput() override;

    void _ready() override;
    void _input(const Ref<InputEvent>& p_event) override;

    // GDScript: sample(sequence, tick) -> Dictionary; snapshot() -> Dictionary.
    // Bounded host validation: GDScript int64 sequence/tick are rejected as
    // invalid_sequence before any uint64 cast (a negative wrap would look
    // forward in the core uint64 domain); sequence 0 is forwarded to the core
    // (core invalid_sequence). duplicate_idempotent returns ok true with the
    // committed frame.
    Dictionary Sample(int64_t sequence, int64_t tick);
    Dictionary Snapshot();

protected:
    static void _bind_methods();

private:
    Dictionary BuildFrameDictionary(bool ok, const char* status, bool valid,
                                    const NativeSourcePadFrame& frame,
                                    const char* canonical) const;
    Dictionary BuildErrorDictionary(const char* status) const;

    NativeSourcePad m_Pad;
    // Persistent physical device 0 state (float axes + button mask).
    float m_AxisX = 0.0f;
    float m_AxisY = 0.0f;
    std::uint8_t m_Buttons = 0;
    // Callback diagnostics: total _input calls, ignored subset (other
    // device/type/button/axis), rejected subset (invalid supported axis).
    // Accepted supported events increment received only.
    std::int64_t m_ReceivedEvents = 0;
    std::int64_t m_IgnoredEvents = 0;
    std::int64_t m_RejectedEvents = 0;
    // Points at a static literal: "ok" (core StatusName Ok), "ignored", or core
    // StatusName() for rejected axes (non_finite_axis/axis_out_of_range).
    // Never owns allocation, so no std exception path.
    const char* m_LastEventStatus = "ok";
};

} // namespace godot
