import SwiftUI

struct ContentView: View {
    @ObservedObject var controller: FlipController
    let language: AppLanguage

    private var mirrorButtonTitle: LocalizedStringResource {
        if controller.active { return "Turn Off Mirroring" }
        if controller.busy { return "Preparing…" }
        return "Flip Horizontally"
    }

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "arrow.left.and.right")
                .font(.system(size: 32, weight: .medium)).foregroundStyle(.tint)
            VStack(spacing: 6) {
                Text("Flip H").font(.title.bold())
                Text(language.localized("Flip your external display horizontally."))
                    .multilineTextAlignment(.center).foregroundStyle(.secondary)
            }
            if controller.displays.isEmpty {
                Text(language.localized("Connect an external display and set it to extend your desktop in System Settings."))
                    .multilineTextAlignment(.center).foregroundStyle(.secondary)
                Button(language.localized("Refresh Displays")) { controller.refreshDisplays() }
            } else {
                Picker(language.localized("Display"), selection: $controller.selectedID) {
                    ForEach(controller.displays) { display in
                        Text("\(display.name) · \(Int(display.size.width)) × \(Int(display.size.height))")
                            .tag(display.id)
                    }
                }
                .disabled(controller.active || controller.busy)
                Button {
                    if controller.active { controller.stop() }
                    else { Task { await controller.start() } }
                } label: {
                    HStack {
                        if controller.busy { ProgressView().controlSize(.small) }
                        Text(language.localized(mirrorButtonTitle))
                    }.frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent).controlSize(.large)
                .disabled(controller.busy).keyboardShortcut(.defaultAction)
            }
            if let message = controller.message {
                Text(language.localized(message))
                    .font(.callout).multilineTextAlignment(.center).textSelection(.enabled)
            }
            if controller.needsPermission {
                Button(language.localized("Open Screen Recording Settings")) { controller.openPermissions() }
            }
            if controller.active {
                Text(language.localized("Mirroring is on"))
                    .multilineTextAlignment(.center).font(.caption).foregroundStyle(.secondary)
            }
        }
        .padding(28).frame(width: 390)
    }
}
