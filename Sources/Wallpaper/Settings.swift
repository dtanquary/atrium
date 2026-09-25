import SwiftUI

/// One live setting: a slider in the Settings window, stored in UserDefaults under `key`. Scenes read `value` and
/// listen for `UserDefaults.didChangeNotification` to pick up changes while the slider moves.
struct Knob {
    let key: String, label: String, range: ClosedRange<Double>, standard: Double

    var value: Double { UserDefaults.standard.object(forKey: key) as? Double ?? standard }
}

/// Sliders for the scenes that have settings.
struct SettingsView: View {
    @AppStorage("gradient.previewTime") private var previewTime = false

    var body: some View {
        Form {
            Section("Flowing Gradient") {
                ForEach(FlowingGradient.knobs, id: \.key) { KnobSlider(knob: $0) }
                Toggle("Preview a time of day", isOn: $previewTime)
                if previewTime {
                    KnobSlider(knob: FlowingGradient.previewHour) { String(format: "%d:%02d", Int($0) % 24, Int($0 * 60) % 60) }
                }
                Button("Reset Flowing Gradient") {
                    for knob in FlowingGradient.knobs + [FlowingGradient.previewHour] {
                        UserDefaults.standard.removeObject(forKey: knob.key)
                    }
                    previewTime = false
                }
            }
        }
        .formStyle(.grouped)
        .frame(width: 460)
    }
}

struct KnobSlider: View {
    let knob: Knob
    let format: (Double) -> String
    @AppStorage private var value: Double

    init(knob: Knob, format: @escaping (Double) -> String = { String(format: "%.2f", $0) }) {
        self.knob = knob
        self.format = format
        _value = AppStorage(wrappedValue: knob.standard, knob.key)
    }

    var body: some View {
        LabeledContent(knob.label) {
            HStack {
                Slider(value: $value, in: knob.range)
                Text(format(value)).monospacedDigit().frame(width: 44, alignment: .trailing)
            }
        }
    }
}
