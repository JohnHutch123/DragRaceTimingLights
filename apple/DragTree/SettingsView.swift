// Settings screen: tree, lane, staging, transmission and throttle.
// Settings are saved as soon as they change.

import SwiftUI

struct SettingsView: View {
    @ObservedObject var model: TreeModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Settings")
                .font(.system(size: 24, weight: .bold))
                .frame(maxWidth: .infinity)

            row("Tree") {
                Picker("Tree", selection: $model.treeMode) {
                    ForEach(TreeMode.allCases, id: \.self) { Text($0.name).tag($0) }
                }
            }
            row("Lane") {
                Picker("Lane", selection: $model.userLane) {
                    Text(laneNames[0]).tag(0)
                    Text(laneNames[1]).tag(1)
                }
            }
            row("Staging") {
                Picker("Staging", selection: $model.stageMode) {
                    ForEach(AutoManual.allCases, id: \.self) { Text($0.name).tag($0) }
                }
            }
            row("Transmission") {
                Picker("Transmission", selection: $model.transMode) {
                    ForEach(AutoManual.allCases, id: \.self) { Text($0.name).tag($0) }
                }
            }
            .disabled(!model.multiTouch)
            row("Throttle") {
                Picker("Throttle", selection: $model.throttleMode) {
                    ForEach(AutoManual.allCases, id: \.self) { Text($0.name).tag($0) }
                }
            }
            .disabled(!model.multiTouch)

            if !model.multiTouch {
                Text("Transmission and throttle need multi-touch. On the Mac only the brake is used: hold the BRAKE pad with the mouse or hold the space bar. Return starts a run.")
                    .font(.system(size: 12))
                    .foregroundColor(Palette.subtle.color)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Button("Done") { dismiss() }
                .buttonStyle(PanelButtonStyle())
                .frame(height: 44)
                .keyboardShortcut(.defaultAction)
        }
        .padding(24)
        .frame(minWidth: 320, maxWidth: 420)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Palette.background.color.ignoresSafeArea())
        .preferredColorScheme(.dark)
    }

    private func row<Content: View>(_ title: String, @ViewBuilder _ content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(Palette.subtle.color)
            content()
                .pickerStyle(.segmented)
                .labelsHidden()
        }
    }
}
