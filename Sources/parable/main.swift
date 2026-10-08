import Foundation
import ParableCore

let usage = """
    parable: run Windows games on your Mac

    USAGE
      parable doctor                          check this Mac is ready
      parable engine presets                  list engines available to download
      parable engine install <preset>         download and install a preset engine
      parable d3dmetal import <folder>        add Apple's D3DMetal from a Game Porting Toolkit folder
      parable d3dmetal status                 show whether D3DMetal is imported and installed
      parable engine install <name> <url>     install any Wine build (.tar.xz, URL or file path)
      parable engine list                     list installed engines
      parable bottle create <name> [engine]   create a Windows environment
      parable bottle list                     list bottles
      parable bottle env <name> KEY=VALUE     set a launch variable on a bottle
      parable bottle retina <name> on|off     native Retina resolution (sharper)
      parable bottle engine <name> <engine>   switch a bottle to another engine
      parable run <bottle> <program> [args]   run a .exe (or a Wine builtin such as winecfg)
      parable open <bottle>                   show a bottle's C: drive in Finder

    Data lives in ~/Library/Application Support/Parable (override with PARABLE_HOME).
    """

func fail(_ message: String) -> Never {
    FileHandle.standardError.write(Data("error: \(message)\n".utf8))
    exit(1)
}

// Keep our messages in order with Wine's output when stdout is a pipe.
setvbuf(stdout, nil, _IOLBF, 0)

let paths = Paths()
let engines = EngineStore(paths: paths)
let bottles = BottleStore(paths: paths)
let runner = Runner(paths: paths)

func doctor() {
    func line(_ ok: Bool, _ text: String) { print("  \(ok ? "✓" : "✗") \(text)") }
    print("System")
    line(SystemCheck.isAppleSilicon, "Apple Silicon")
    line(true, "macOS \(SystemCheck.macOSVersion)")
    line(SystemCheck.rosettaInstalled,
         SystemCheck.rosettaInstalled
            ? "Rosetta 2 installed"
            : "Rosetta 2 missing: softwareupdate --install-rosetta --agree-to-license")

    let installed = engines.list()
    print("Engines")
    if installed.isEmpty { line(false, "none installed: parable engine install parable") }
    for engine in installed {
        let archs = SystemCheck.architectures(of: engine.wineBinary).sorted().joined(separator: "+")
        line(true, "\(engine.name) [\(archs)]\(engine.hasD3DMetal ? " +D3DMetal" : "")")
    }

    print("Bottles")
    let all = bottles.list()
    if all.isEmpty { print("  (none)") }
    for bottle in all { print("  \(bottle.name) → \(bottle.engine)") }
}

func engineCommand(_ args: [String]) throws {
    switch args.first {
    case "presets":
        for preset in EnginePreset.all {
            print("\(preset.name)\n  \(preset.summary)\n  \(preset.url.absoluteString)")
        }
    case "list":
        let installed = engines.list()
        if installed.isEmpty { print("no engines installed") }
        for engine in installed {
            print("\(engine.name)\(engine.hasD3DMetal ? " (D3DMetal)" : "")\n  \(engine.wineBinary.path)")
        }
    case "install":
        let name: String, source: URL
        switch args.count {
        case 2:
            guard let preset = EnginePreset.named(args[1]) else {
                fail("unknown preset '\(args[1])' (see `parable engine presets`)")
            }
            (name, source) = (preset.name, preset.url)
        case 3:
            name = args[1]
            if let url = URL(string: args[2]), url.scheme?.hasPrefix("http") == true {
                source = url
            } else {
                source = URL(fileURLWithPath: args[2])
            }
        default:
            fail("usage: parable engine install <preset> | <name> <url-or-file>")
        }
        print("Installing engine '\(name)' from \(source.isFileURL ? source.path : source.absoluteString)")
        let engine = try engines.install(name: name, from: source)
        print("Installed: \(engine.wineBinary.path)")
    default:
        fail("usage: parable engine presets | list | install")
    }
}

func d3dmetalCommand(_ args: [String]) throws {
    let store = D3DMetalStore(paths: paths)
    switch args.first {
    case "import":
        guard args.count == 2 else { fail("usage: parable d3dmetal import <Game Porting Toolkit folder>") }
        try store.importToolkit(from: URL(fileURLWithPath: args[1]))
        for engine in engines.list() {
            try store.install(into: engine)
            print("added D3DMetal to engine '\(engine.name)'")
        }
    case "status":
        print(store.isImported ? "D3DMetal is imported" : "D3DMetal is not imported")
        for engine in engines.list() { print("  \(engine.name): \(engine.hasD3DMetal ? "installed" : "not installed")") }
    default:
        fail("usage: parable d3dmetal import <folder> | status")
    }
}

func bottleCommand(_ args: [String]) throws {
    switch args.first {
    case "list":
        let all = bottles.list()
        if all.isEmpty { print("no bottles yet") }
        for bottle in all {
            print("\(bottle.name) → \(bottle.engine)")
            for (key, value) in bottle.environment.sorted(by: { $0.key < $1.key }) {
                print("  \(key)=\(value)")
            }
        }
    case "create":
        guard args.count >= 2 else { fail("usage: parable bottle create <name> [engine]") }
        let engineName: String
        if args.count >= 3 {
            engineName = args[2]
        } else {
            let installed = engines.list()
            guard installed.count == 1 else {
                fail(installed.isEmpty
                     ? "install an engine first: parable engine install parable"
                     : "several engines installed; pick one: parable bottle create \(args[1]) <engine>")
            }
            engineName = installed[0].name
        }
        _ = try engines.load(engineName)
        let bottle = try bottles.create(name: args[1], engine: engineName)
        print("Setting up Windows environment (this takes a minute the first time)...")
        try runner.initialize(bottle.name)
        print("Bottle '\(bottle.name)' ready: \(bottles.prefix(for: bottle.name).path)")
    case "env":
        guard args.count == 3, let split = args[2].firstIndex(of: "=") else {
            fail("usage: parable bottle env <name> KEY=VALUE")
        }
        var bottle = try bottles.load(args[1])
        let key = String(args[2][..<split])
        let value = String(args[2][args[2].index(after: split)...])
        bottle.environment[key] = value.isEmpty ? nil : value
        try bottles.save(bottle)
        print(value.isEmpty ? "unset \(key)" : "set \(key)=\(value)")
    case "engine":
        guard args.count == 3 else { fail("usage: parable bottle engine <name> <engine>") }
        var bottle = try bottles.load(args[1])
        bottle.engine = try engines.load(args[2]).name
        try bottles.save(bottle)
        print("'\(bottle.name)' now uses engine '\(bottle.engine)'")
    case "retina":
        guard args.count == 3, ["on", "off"].contains(args[2]) else {
            fail("usage: parable bottle retina <name> on|off")
        }
        try runner.setRetina(args[2] == "on", in: args[1])
        print("retina \(args[2]) for '\(args[1])' (applies to programs started from now on)")
    default:
        fail("usage: parable bottle list | create | env | retina | engine")
    }
}

do {
    let args = Array(CommandLine.arguments.dropFirst())
    switch args.first {
    case "doctor":
        doctor()
    case "engine":
        try engineCommand(Array(args.dropFirst()))
    case "bottle":
        try bottleCommand(Array(args.dropFirst()))
    case "d3dmetal":
        try d3dmetalCommand(Array(args.dropFirst()))
    case "run":
        guard args.count >= 3 else { fail("usage: parable run <bottle> <program> [args]") }
        exit(try runner.wine(Array(args.dropFirst(2)), in: args[1]))
    case "open":
        guard args.count == 2 else { fail("usage: parable open <bottle>") }
        _ = try bottles.load(args[1])
        let drive = bottles.prefix(for: args[1]).appendingPathComponent("drive_c")
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/open")
        process.arguments = [drive.path]
        try process.run()
        process.waitUntilExit()
    case nil, "help", "-h", "--help":
        print(usage)
    default:
        fail("unknown command '\(args[0])'\n\n\(usage)")
    }
} catch let error as ParableError {
    fail(error.description)
} catch {
    fail(error.localizedDescription)
}
