// P2-A03 Godot input seam implementation. See sa_input_bridge.h for the
// frozen mapping, callback, and failure-atomicity contract. No keyboard,
// focus, hotplug, remap, pause, clock, auto-latch, inference, CJ, or camera
// coupling. No SourceSession boot. No exceptions (inherits -fno-exceptions).
#include "sa_input_bridge.h"

#include <godot_cpp/classes/global_constants.hpp>
#include <godot_cpp/classes/input_event_joypad_button.hpp>
#include <godot_cpp/classes/input_event_joypad_motion.hpp>
#include <godot_cpp/core/class_db.hpp>

#include <array>
#include <cstdint>
#include <limits>

namespace godot {
namespace {

// Button masks as values (spec "bit1/bit2/bit4" means masks 0x01/0x02/0x04):
//   X(2)->0x01 Jump/Square, A(0)->0x02 Sprint/Cross, Y(3)->0x04 Enter/Triangle.
constexpr std::uint8_t kMaskX = 0x01;
constexpr std::uint8_t kMaskA = 0x02;
constexpr std::uint8_t kMaskY = 0x04;

void BumpCounter(std::int64_t& counter) {
    if (counter < std::numeric_limits<std::int64_t>::max()) {
        ++counter;
    }
}

String Utf8Literal(const char* text) {
    return String::utf8(text ? text : "");
}

} // namespace

SALegacyInput::SALegacyInput() = default;
SALegacyInput::~SALegacyInput() = default;

void SALegacyInput::_ready() {
    set_process_input(true);
}

void SALegacyInput::_input(const Ref<InputEvent>& p_event) {
    BumpCounter(m_ReceivedEvents);
    if (p_event.is_null()) {
        BumpCounter(m_IgnoredEvents);
        m_LastEventStatus = "ignored";
        return;
    }
    const InputEvent* base = *p_event;
    if (base == nullptr) {
        BumpCounter(m_IgnoredEvents);
        m_LastEventStatus = "ignored";
        return;
    }
    if (base->get_device() != 0) {
        BumpCounter(m_IgnoredEvents);
        m_LastEventStatus = "ignored";
        return;
    }
    if (const auto* button = Object::cast_to<const InputEventJoypadButton>(base)) {
        const JoyButton index = button->get_button_index();
        std::uint8_t mask = 0;
        if (index == JOY_BUTTON_X) {
            mask = kMaskX;
        } else if (index == JOY_BUTTON_A) {
            mask = kMaskA;
        } else if (index == JOY_BUTTON_Y) {
            mask = kMaskY;
        } else {
            BumpCounter(m_IgnoredEvents);
            m_LastEventStatus = "ignored";
            return;
        }
        // Base is_pressed() carries the JoypadButton pressed flag (the
        // generated JoypadButton header exposes only set_pressed()).
        if (base->is_pressed()) {
            m_Buttons = static_cast<std::uint8_t>(m_Buttons | mask);
        } else {
            m_Buttons = static_cast<std::uint8_t>(m_Buttons & static_cast<std::uint8_t>(~mask));
        }
        m_LastEventStatus = NativeSourcePad::StatusName(NativeSourcePadStatus::Ok);
        return;
    }
    if (const auto* motion = Object::cast_to<const InputEventJoypadMotion>(base)) {
        const JoyAxis axis = motion->get_axis();
        if (axis != JOY_AXIS_LEFT_X && axis != JOY_AXIS_LEFT_Y) {
            BumpCounter(m_IgnoredEvents);
            m_LastEventStatus = "ignored";
            return;
        }
        const float value = motion->get_axis_value();
        // Validate through the frozen core helper so finite/[-1,1] rejects
        // (never clamps) exactly as sample-time quantization does. Invalid
        // preserves the physical value.
        std::int16_t quantized = 0;
        const NativeSourcePadStatus qstatus = NativeSourcePad::QuantizeAxis(value, quantized);
        if (qstatus != NativeSourcePadStatus::Ok) {
            BumpCounter(m_RejectedEvents);
            m_LastEventStatus = NativeSourcePad::StatusName(qstatus);
            return;
        }
        if (axis == JOY_AXIS_LEFT_X) {
            m_AxisX = value;
        } else {
            m_AxisY = value;
        }
        m_LastEventStatus = NativeSourcePad::StatusName(NativeSourcePadStatus::Ok);
        return;
    }
    BumpCounter(m_IgnoredEvents);
    m_LastEventStatus = "ignored";
}

Dictionary SALegacyInput::BuildFrameDictionary(bool ok, const char* status, bool valid,
                                              const NativeSourcePadFrame& frame,
                                              const char* canonical) const {
    Dictionary out;
    out["ok"] = ok;
    out["status"] = Utf8Literal(status);
    out["valid"] = valid;
    out["sequence"] = valid ? static_cast<std::int64_t>(frame.Sample.Seq) : std::int64_t{0};
    out["tick"] = valid ? static_cast<std::int64_t>(frame.Sample.Tick) : std::int64_t{0};
    out["move_x"] = valid ? static_cast<std::int64_t>(frame.Sample.MoveX) : std::int64_t{0};
    out["move_y"] = valid ? static_cast<std::int64_t>(frame.Sample.MoveY) : std::int64_t{0};
    out["down"] = valid ? static_cast<std::int64_t>(frame.Down) : std::int64_t{0};
    out["pressed"] = valid ? static_cast<std::int64_t>(frame.Pressed) : std::int64_t{0};
    out["released"] = valid ? static_cast<std::int64_t>(frame.Released) : std::int64_t{0};
    out["canonical"] = valid ? Utf8Literal(canonical) : String();
    out["received_events"] = m_ReceivedEvents;
    out["ignored_events"] = m_IgnoredEvents;
    out["rejected_events"] = m_RejectedEvents;
    out["last_event_status"] = Utf8Literal(m_LastEventStatus);
    return out;
}

Dictionary SALegacyInput::BuildErrorDictionary(const char* status) const {
    // Failed sample exposes the last COMMITTED frame, never the candidate.
    // No partial mutation: the core is failure-atomic and this adapter keeps
    // no staged candidate outside the core.
    if (!m_Pad.HasFrame()) {
        const NativeSourcePadFrame empty{};
        return BuildFrameDictionary(false, status, false, empty, "");
    }
    const NativeSourcePadFrame& committed = m_Pad.LastFrame();
    const std::array<char, 128> text = NativeSourcePad::FormatFrame(committed);
    return BuildFrameDictionary(false, status, true, committed, text.data());
}

Dictionary SALegacyInput::Sample(int64_t sequence, int64_t tick) {
    // Bounded host validation: negative int64 rejects as invalid_sequence
    // before any uint64 cast (a negative wrap would look forward in the core
    // uint64 domain).
    if (sequence < 0 || tick < 0) {
        return BuildErrorDictionary(NativeSourcePad::StatusName(NativeSourcePadStatus::InvalidSequence));
    }
    // Sequence 0 is forwarded to the core (core invalid_sequence), not
    // rejected here, so the core oracle owns the zero rule.
    std::int16_t moveX = 0;
    std::int16_t moveY = 0;
    NativeSourcePadStatus qx = NativeSourcePad::QuantizeAxis(m_AxisX, moveX);
    if (qx != NativeSourcePadStatus::Ok) {
        return BuildErrorDictionary(NativeSourcePad::StatusName(qx));
    }
    NativeSourcePadStatus qy = NativeSourcePad::QuantizeAxis(m_AxisY, moveY);
    if (qy != NativeSourcePadStatus::Ok) {
        return BuildErrorDictionary(NativeSourcePad::StatusName(qy));
    }
    NativeSourcePadSample sample{};
    sample.Seq = static_cast<std::uint64_t>(sequence);
    sample.Tick = static_cast<std::uint64_t>(tick);
    sample.MoveX = moveX;
    sample.MoveY = moveY;
    sample.Buttons = m_Buttons;
    NativeSourcePadFrame out{};
    const NativeSourcePadStatus status = m_Pad.SubmitSample(sample, out);
    if (status == NativeSourcePadStatus::Ok ||
        status == NativeSourcePadStatus::DuplicateIdempotent) {
        const std::array<char, 128> text = NativeSourcePad::FormatFrame(out);
        return BuildFrameDictionary(true, NativeSourcePad::StatusName(status), true, out,
                                    text.data());
    }
    return BuildErrorDictionary(NativeSourcePad::StatusName(status));
}

Dictionary SALegacyInput::Snapshot() {
    // Non-consuming: reports the committed frame plus callback counters
    // without clearing pressed/released edges. Success status is core
    // StatusName Ok ("ok").
    if (!m_Pad.HasFrame()) {
        const NativeSourcePadFrame empty{};
        return BuildFrameDictionary(true, NativeSourcePad::StatusName(NativeSourcePadStatus::Ok), false,
                                    empty, "");
    }
    const NativeSourcePadFrame& committed = m_Pad.LastFrame();
    const std::array<char, 128> text = NativeSourcePad::FormatFrame(committed);
    return BuildFrameDictionary(true, NativeSourcePad::StatusName(NativeSourcePadStatus::Ok), true,
                                committed, text.data());
}

void SALegacyInput::_bind_methods() {
    ClassDB::bind_method(D_METHOD("sample", "sequence", "tick"), &SALegacyInput::Sample);
    ClassDB::bind_method(D_METHOD("snapshot"), &SALegacyInput::Snapshot);
}

} // namespace godot
