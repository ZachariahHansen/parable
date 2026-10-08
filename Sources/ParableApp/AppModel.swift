import AppKit
import Observation
import ParableCore

/// The app's state: what's installed, what's selected, what's running.
@MainActor @Observable
final class AppModel {
    private let paths = Paths()
    private var engineStore: EngineStore { EngineStore(paths: paths) }
    private var bottleStore: BottleStore { BottleStore(paths: paths) }
    private var runner: Runner { Runner(paths: paths) }

    private(set) var bottles: [Bottle] = []
    private(set) var engines: [Engine] = []
    var selection: Bottle.ID?
    /// Description of the long-running job in progress, if any.
    private(set) var activity: String?
    var errorMessage: String?
    /// Programs currently running, per bottle name.
    private(set) var runningCounts: [String: Int] = [:]

    init() { refresh() }

    var selectedBottle: Bottle? { bottles.first { $0.id == selection } }

    func engine(for bottle: Bottle) -> Engine? { engines.first { $0.name == bottle.engine } }

    func refresh() {
        engines = engineStore.list()
        bottles = bottleStore.list()
        if selectedBottle == nil { selection = bottles.first?.id }
    }

    // MARK: Engines and bottles

    func install(_ preset: EnginePreset) async {
        let store = engineStore
        await background("Downloading \(preset.name)…") {
            _ = try store.install(name: preset.name, from: preset.url)
        }
    }

    /// Asks for a Game Porting Toolkit folder and adds its D3DMetal to every engine.
    func chooseD3DMetalToolkit() {
        let panel = NSOpenPanel()
        panel.message = "Choose the Game Porting Toolkit disk image (or folder) downloaded from Apple"
        panel.prompt = "Import"
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.directoryURL = URL(fileURLWithPath: "/Volumes")
        guard panel.runModal() == .OK, let folder = panel.url else { return }
        let (store, engineStore) = (D3DMetalStore(paths: paths), engineStore)
        Task {
            await background("Importing D3DMetal…") {
                try store.importToolkit(from: folder)
                for engine in engineStore.list() { try store.install(into: engine) }
            }
        }
    }

    func createBottle(named name: String, engine: String) async {
        let (store, runner) = (bottleStore, runner)
        await background("Setting up “\(name)”…") {
            let bottle = try store.create(name: name, engine: engine)
            try runner.initialize(bottle.name)
        }
        if bottles.contains(where: { $0.name == name }) { selection = name }
    }

    func trash(_ bottle: Bottle) {
        attempt { try bottleStore.trash(bottle.name) }
        refresh()
    }

    func setEnvironment(_ key: String, to value: String?, in bottle: Bottle) {
        var updated = bottle
        updated.environment[key] = value
        save(updated)
    }

    func setEngine(_ engine: String, for bottle: Bottle) {
        var updated = bottle
        updated.engine = engine
        save(updated)
    }

    func setRetina(_ enabled: Bool, in bottle: Bottle) async {
        let (runner, name) = (runner, bottle.name)
        await background(enabled ? "Turning on Retina mode…" : "Turning off Retina mode…") {
            try runner.setRetina(enabled, in: name)
        }
    }

    // MARK: Programs

    /// Remembers a program in the bottle and starts it.
    func addProgram(_ file: URL, to bottle: Bottle) {
        var updated = bottle
        if !updated.programs.contains(file.path) {
            updated.programs.append(file.path)
            save(updated)
        }
        run(file, in: updated)
    }

    func removeProgram(_ path: String, from bottle: Bottle) {
        var updated = bottle
        updated.programs.removeAll { $0 == path }
        save(updated)
    }

    func run(_ file: URL, in bottle: Bottle) {
        run(Runner.arguments(forFile: file), in: bottle)
    }

    /// Starts `wine <arguments>` in the bottle and tracks it until it exits.
    func run(_ arguments: [String], in bottle: Bottle) {
        let name = bottle.name
        attempt {
            try runner.launch(arguments, in: name) { [weak self] _ in
                Task { @MainActor in self?.runningCounts[name, default: 1] -= 1 }
            }
            runningCounts[name, default: 0] += 1
        }
    }

    func isRunning(_ bottle: Bottle) -> Bool { runningCounts[bottle.name, default: 0] > 0 }

    func chooseProgram(for bottle: Bottle) {
        let panel = NSOpenPanel()
        panel.message = "Choose a Windows program or installer"
        panel.prompt = "Run"
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        // Start inside the bottle, where installed games end up.
        panel.directoryURL = bottleStore.prefix(for: bottle.name).appendingPathComponent("drive_c")
        if panel.runModal() == .OK, let file = panel.url { addProgram(file, to: bottle) }
    }

    // MARK: Finder

    func openDrive(of bottle: Bottle) {
        NSWorkspace.shared.open(bottleStore.prefix(for: bottle.name).appendingPathComponent("drive_c"))
    }

    func openLog(of bottle: Bottle) {
        let log = bottleStore.logFile(for: bottle.name)
        guard FileManager.default.fileExists(atPath: log.path) else {
            errorMessage = "Nothing has been run in “\(bottle.name)” yet."
            return
        }
        NSWorkspace.shared.open(log)
    }

    // MARK: Helpers

    private func save(_ bottle: Bottle) {
        attempt { try bottleStore.save(bottle) }
        refresh()
    }

    private func attempt(_ work: () throws -> Void) {
        do { try work() } catch { report(error) }
    }

    /// Runs blocking work off the main thread while showing `label` as the activity.
    private func background(_ label: String, _ work: @escaping @Sendable () throws -> Void) async {
        activity = label
        do { try await Task.detached(operation: work).value } catch { report(error) }
        activity = nil
        refresh()
    }

    private func report(_ error: Error) {
        errorMessage = (error as? ParableError)?.description ?? error.localizedDescription
    }
}
