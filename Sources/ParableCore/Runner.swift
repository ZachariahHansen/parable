import Foundation

/// Launches Windows programs inside a bottle.
public struct Runner: Sendable {
    public let engines: EngineStore
    public let bottles: BottleStore

    public init(paths: Paths = Paths()) {
        self.engines = EngineStore(paths: paths)
        self.bottles = BottleStore(paths: paths)
    }

    /// The environment Wine sees for a bottle: the caller's environment,
    /// then Parable's defaults, then the bottle's own overrides.
    public func environment(for bottle: Bottle, engine: Engine) -> [String: String] {
        var env = ProcessInfo.processInfo.environment
        env["WINEPREFIX"] = bottles.prefix(for: bottle.name).path
        env["PATH"] = engine.binDirectory.path + ":" + (env["PATH"] ?? "/usr/bin:/bin")
        // Wine dlopens its helper libraries by bare name; point dyld at the engine's copies.
        let lib = engine.libDirectory.path
        env["DYLD_FALLBACK_LIBRARY_PATH"] = "\(lib):\(lib)/external:/usr/lib"
        // Wine is extremely chatty by default; keep it quiet unless asked.
        if env["WINEDEBUG"] == nil { env["WINEDEBUG"] = "-all" }
        // Faster synchronization primitives; a large win for most games.
        if env["WINEMSYNC"] == nil { env["WINEMSYNC"] = "1" }
        if env["WINEESYNC"] == nil { env["WINEESYNC"] = "1" }
        for (key, value) in bottle.environment { env[key] = value }
        return env
    }

    /// The Wine arguments that open a file from the Mac's disk:
    /// installers and scripts need a host program, executables run directly.
    public static func arguments(forFile file: URL) -> [String] {
        switch file.pathExtension.lowercased() {
        case "msi": ["msiexec", "/i", file.path]
        case "bat", "cmd": ["cmd", "/c", file.path]
        default: [file.path]
        }
    }

    /// Runs `wine <arguments>` in the bottle, waits, and returns Wine's exit status.
    /// Output goes to this process's own stdout/stderr.
    @discardableResult
    public func wine(_ arguments: [String], in bottleName: String,
                     extraEnvironment: [String: String] = [:]) throws -> Int32 {
        let process = try makeProcess(arguments, bottleName: bottleName)
        process.environment?.merge(extraEnvironment) { _, new in new }
        try process.run()
        process.waitUntilExit()
        return process.terminationStatus
    }

    /// Starts `wine <arguments>` in the bottle without waiting. Output is written
    /// to the bottle's log file; `onExit` is called from a background thread.
    @discardableResult
    public func launch(_ arguments: [String], in bottleName: String,
                       onExit: @escaping @Sendable (Int32) -> Void) throws -> Process {
        let process = try makeProcess(arguments, bottleName: bottleName)
        let log = bottles.logFile(for: bottleName)
        FileManager.default.createFile(atPath: log.path, contents: nil)
        let handle = try FileHandle(forWritingTo: log)
        process.standardOutput = handle
        process.standardError = handle
        process.terminationHandler = { finished in
            try? handle.close()
            onExit(finished.terminationStatus)
        }
        try process.run()
        return process
    }

    /// Has Wine build the fake C: drive and registry for a fresh bottle.
    public func initialize(_ bottleName: String) throws {
        // Without these overrides a stock Wine build stops to offer downloading Mono
        // and Gecko, in a dialog nobody is watching for.
        let code = try wine(["wineboot", "--init"], in: bottleName,
                            extraEnvironment: ["WINEDLLOVERRIDES": "mscoree,mshtml="])
        guard code == 0 else { throw ParableError("wineboot exited with status \(code)") }
    }

    /// Switches the bottle between native Retina rendering and pixel-doubled output.
    /// Takes effect for programs started afterwards.
    public func setRetina(_ enabled: Bool, in bottleName: String) throws {
        // Windows apps must be told to draw at 2x (192 DPI), or they come out tiny.
        let settings = [
            ["HKCU\\Software\\Wine\\Mac Driver", "/v", "RetinaMode", "/t", "REG_SZ", "/d", enabled ? "y" : "n"],
            ["HKCU\\Control Panel\\Desktop", "/v", "LogPixels", "/t", "REG_DWORD", "/d", enabled ? "192" : "96"],
        ]
        for setting in settings {
            let code = try wine(["reg", "add"] + setting + ["/f"], in: bottleName)
            guard code == 0 else { throw ParableError("reg add exited with status \(code)") }
        }
        var bottle = try bottles.load(bottleName)
        bottle.retina = enabled
        try bottles.save(bottle)
    }

    private func makeProcess(_ arguments: [String], bottleName: String) throws -> Process {
        let bottle = try bottles.load(bottleName)
        let engine = try engines.load(bottle.engine)
        try Self.requireRosettaIfNeeded(for: engine)

        let process = Process()
        process.executableURL = engine.wineBinary
        process.arguments = arguments
        process.environment = environment(for: bottle, engine: engine)
        // Games routinely load data relative to their own folder.
        if let file = arguments.last(where: { $0.hasPrefix("/") }),
           FileManager.default.fileExists(atPath: file) {
            process.currentDirectoryURL = URL(fileURLWithPath: file).deletingLastPathComponent()
        }
        return process
    }

    static func requireRosettaIfNeeded(for engine: Engine) throws {
        // An empty set means a launcher script rather than a Mach-O; let it try.
        let archs = SystemCheck.architectures(of: engine.wineBinary)
        guard SystemCheck.isAppleSilicon, !archs.isEmpty, !archs.contains("arm64"),
              !SystemCheck.rosettaInstalled else { return }
        throw ParableError("""
            engine '\(engine.name)' is an Intel build and Rosetta 2 is not installed.
            Install it with: softwareupdate --install-rosetta --agree-to-license
            """)
    }
}
