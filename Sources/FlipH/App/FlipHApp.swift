import SwiftUI

@main
struct FlipHApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var delegate
    @StateObject private var controller = FlipController.shared
    @AppStorage("appLanguage") private var language = AppLanguage.system

    var body: some Scene {
        Window("Flip H", id: "controls") {
            ContentView(controller: controller, language: language)
        }
        .windowResizability(.contentSize)
        .defaultPosition(.center)
        MenuBarExtra("Flip H", systemImage: "arrow.left.and.right") {
            StatusMenu(controller: controller, language: $language)
        }
    }
}

private struct StatusMenu: View {
    @Environment(\.openWindow) private var openWindow
    @ObservedObject var controller: FlipController
    @Binding var language: AppLanguage

    var body: some View {
        Text(verbatim: controller.active ? language.localized("Mirroring is on") : "Flip H")
        Button(language.localized("Open Controls")) {
            openWindow(id: "controls")
            NSApp.activate(ignoringOtherApps: true)
        }
        Button(language.localized("Turn Off Mirroring")) { controller.stop() }
            .disabled(!controller.active && !controller.busy)
        Divider()
        Picker(language.localized("Language"), selection: $language) {
            ForEach(AppLanguage.allCases, id: \.self) { option in
                Text(verbatim: option.title(in: language)).tag(option)
            }
        }
        .pickerStyle(.menu)
        Divider()
        Button(language.localized("Quit Flip H")) { NSApp.terminate(nil) }.keyboardShortcut("q")
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    func applicationWillTerminate(_ notification: Notification) {
        FlipController.shared.stop(showControls: false)
    }
}
