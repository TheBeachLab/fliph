import SwiftUI

struct ContentView: View {
    @ObservedObject var controller: FlipController

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "arrow.left.and.right")
                .font(.system(size: 32, weight: .medium)).foregroundStyle(.tint)
            VStack(spacing: 6) {
                Text("Flip H").font(.title.bold())
                Text("Espejo horizontal para tu monitor externo.")
                    .foregroundStyle(.secondary)
            }
            if controller.displays.isEmpty {
                Text("Conecta un monitor externo y elige «Pantalla ampliada» en los ajustes de macOS.")
                    .multilineTextAlignment(.center).foregroundStyle(.secondary)
                Button("Actualizar pantallas") { controller.refreshDisplays() }
            } else {
                Picker("Monitor", selection: $controller.selectedID) {
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
                        Text(controller.active ? "Desactivar espejo" : controller.busy ? "Preparando…" : "Activar espejo horizontal")
                    }.frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent).controlSize(.large)
                .disabled(controller.busy).keyboardShortcut(.defaultAction)
            }
            if let message = controller.message {
                Text(message).font(.callout).multilineTextAlignment(.center).textSelection(.enabled)
            }
            if controller.needsPermission {
                Button("Abrir permisos de pantalla") { controller.openPermissions() }
            }
            Text(controller.active ? "Espejo activo · Esc para desactivar" : "Esc desactiva el espejo en cualquier momento.")
                .font(.caption).foregroundStyle(.secondary)
        }
        .padding(28).frame(width: 390)
    }
}
