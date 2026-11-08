import SwiftUI

@main
struct FlipHApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var delegate
    @StateObject private var controller = FlipController.shared

    var body: some Scene {
        WindowGroup("Flip H") {
            ContentView(controller: controller)
        }
        .windowResizability(.contentSize)
        .defaultPosition(.center)
        .commands {
            CommandGroup(replacing: .newItem) {}
            CommandMenu("Espejo") {
                Button("Desactivar espejo") { controller.stop() }.disabled(!controller.active && !controller.busy)
            }
        }
        MenuBarExtra("Flip H", systemImage: "arrow.left.and.right") {
            Text(controller.active ? "Espejo activo" : "Flip H")
            Button("Desactivar espejo") { controller.stop() }.disabled(!controller.active && !controller.busy)
            Divider()
            Button("Salir de Flip H") { NSApp.terminate(nil) }.keyboardShortcut("q")
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
    }

    func applicationWillTerminate(_ notification: Notification) {
        FlipController.shared.stop(showControls: false)
    }
}
