// Main screen: reaction time and stats at the top, the tree and history in
// the middle, the pedal pads and the Start/Stop/Reset/Clear buttons at the
// bottom.

import SwiftUI

struct ContentView: View {
    @ObservedObject var model: TreeModel
    #if os(macOS)
    @StateObject private var keys = KeyMonitor()
    #endif

    var body: some View {
        VStack(spacing: 8) {
            VStack(spacing: 2) {
                Text(model.reactionText)
                    .font(.system(size: 48, weight: .bold, design: .monospaced))
                    .foregroundColor(model.reactionColor.color)
                Text(model.verdict)
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(model.verdictColor.color)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                Text(model.statsText)
                    .font(.system(size: 14))
                    .foregroundColor(Palette.subtle.color)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
            }

            HStack(spacing: 8) {
                Button("Settings") { model.openSettings() }
                    .buttonStyle(PanelButtonStyle())
                    .frame(width: 100)
                    .disabled(model.running)
                Text(model.summary)
                    .font(.system(size: 12))
                    .foregroundColor(Palette.subtle.color)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(height: 40)

            HStack(spacing: 8) {
                TreeCanvas(state: model.drawState())
                VStack(spacing: 4) {
                    Text("History")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(Palette.subtle.color)
                    Text(model.historyText)
                        .font(.system(size: 14, design: .monospaced))
                        .foregroundColor(Palette.text.color)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Spacer(minLength: 0)
                }
                .padding(8)
                .frame(width: 120)
                .frame(maxHeight: .infinity)
                .background(RoundedRectangle(cornerRadius: 8).fill(Palette.panel.color))
            }
            .frame(maxHeight: .infinity)

            Text(model.hint)
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(Palette.subtle.color)
                .frame(height: 22)

            PedalPads(model: model)
                .frame(height: 130)

            HStack(spacing: 8) {
                Button("Start") { model.startRun() }
                Button("Stop") { model.stopPressed() }
                Button("Reset") { model.resetTree() }
                Button("Clear") { model.clearHistory() }
            }
            .buttonStyle(PanelButtonStyle())
            .frame(height: 56)
        }
        .padding(8)
        .background(Palette.background.color.ignoresSafeArea())
        .preferredColorScheme(.dark)
        .sheet(isPresented: $model.showingSettings, onDismiss: model.settingsClosed) {
            SettingsView(model: model)
        }
        #if os(macOS)
        .frame(minWidth: 380, minHeight: 720)
        .onAppear { keys.install(model) }
        .onDisappear { keys.remove() }
        #endif
    }
}

/// Same look on iPhone and Mac: a dark rounded button filling its space.
struct PanelButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        PanelButtonLabel(label: configuration.label, pressed: configuration.isPressed)
    }
}

private struct PanelButtonLabel<Label: View>: View {
    let label: Label
    let pressed: Bool
    @Environment(\.isEnabled) private var enabled

    var body: some View {
        label
            .font(.system(size: 17, weight: .semibold))
            .foregroundColor(enabled ? Palette.text.color : Palette.subtle.color.opacity(0.5))
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(RoundedRectangle(cornerRadius: 10)
                            .fill(pressed ? Palette.track.color : Palette.padIdle.color))
            .contentShape(Rectangle())
    }
}
