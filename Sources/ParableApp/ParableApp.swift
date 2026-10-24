import SwiftUI

@main
struct ParableApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate
    @State private var model = AppModel()

    var body: some Scene {
        // A window group, not a single Window scene: clicking the Dock icon brings
        // the window back if it has been closed while the app kept running.
        WindowGroup("Parable", id: "main") {
            ContentView()
                .environment(model)
                .frame(minWidth: 720, minHeight: 460)
        }
        .commands { CommandGroup(replacing: .newItem) {} }  // one window is enough
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Needed when launched as a bare executable (`swift run ParableApp`)
        // rather than from the .app bundle; harmless otherwise.
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }
}
