import Foundation

/// An isolated Windows environment: its own C: drive, registry and settings.
public struct Bottle: Codable, Sendable, Identifiable, Hashable {
    public var name: String
    /// Name of the engine this bottle runs with.
    public var engine: String
    public var created: Date
    /// Extra environment variables applied on every launch (e.g. `MTL_HUD_ENABLED=1`).
    public var environment: [String: String]
    /// Paths of programs the user has added to this bottle, in display order.
    public var programs: [String]
    /// Render at the display's native Retina resolution instead of pixel-doubled.
    public var retina: Bool

    public var id: String { name }

    public init(name: String, engine: String, created: Date = Date(),
                environment: [String: String] = [:], programs: [String] = [],
                retina: Bool = false) {
        self.name = name
        self.engine = engine
        self.created = created
        self.environment = environment
        self.programs = programs
        self.retina = retina
    }

    public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        name = try values.decode(String.self, forKey: .name)
        engine = try values.decode(String.self, forKey: .engine)
        created = try values.decode(Date.self, forKey: .created)
        environment = try values.decodeIfPresent([String: String].self, forKey: .environment) ?? [:]
        // Absent in bottles created before programs were tracked.
        programs = try values.decodeIfPresent([String].self, forKey: .programs) ?? []
        retina = try values.decodeIfPresent(Bool.self, forKey: .retina) ?? false
    }
}

public struct BottleStore: Sendable {
    public let paths: Paths
    public init(paths: Paths = Paths()) { self.paths = paths }

    public func directory(for name: String) -> URL {
        paths.bottles.appendingPathComponent(name, isDirectory: true)
    }

    /// The WINEPREFIX for a bottle.
    public func prefix(for name: String) -> URL {
        directory(for: name).appendingPathComponent("prefix", isDirectory: true)
    }

    /// Output of the most recent program launched without a terminal attached.
    public func logFile(for name: String) -> URL {
        directory(for: name).appendingPathComponent("last-run.log")
    }

    private func metadataURL(for name: String) -> URL {
        directory(for: name).appendingPathComponent("bottle.json")
    }

    public func list() -> [Bottle] {
        let names = (try? FileManager.default.contentsOfDirectory(atPath: paths.bottles.path)) ?? []
        return names.sorted().compactMap { try? load($0) }
    }

    public func load(_ name: String) throws -> Bottle {
        guard let data = try? Data(contentsOf: metadataURL(for: name)) else {
            throw ParableError("no bottle named '\(name)' (try `parable bottle list`)")
        }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(Bottle.self, from: data)
    }

    public func save(_ bottle: Bottle) throws {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(bottle).write(to: metadataURL(for: bottle.name), options: .atomic)
    }

    /// Records a new bottle on disk. The prefix itself is filled in by Wine
    /// the first time something runs in it (see `Runner.initialize`).
    public func create(name: String, engine: String) throws -> Bottle {
        try validateName(name, kind: "bottle")
        let dir = directory(for: name)
        guard !FileManager.default.fileExists(atPath: dir.path) else {
            throw ParableError("bottle '\(name)' already exists")
        }
        try FileManager.default.createDirectory(at: prefix(for: name),
                                                withIntermediateDirectories: true)
        let bottle = Bottle(name: name, engine: engine)
        try save(bottle)
        return bottle
    }

    /// True while anything is running in the bottle, however it was started and
    /// whether or not it has a window.
    public func hasRunningPrograms(_ name: String) -> Bool {
        !WineProcesses.pids(prefix: prefix(for: name), engines: paths.engines).isEmpty
    }

    /// The DPI Windows programs in the bottle are told to draw at, as last saved to
    /// disk by Wine, or nil if it was never set. Only current while nothing runs.
    public func logPixels(_ name: String) -> Int? {
        let registry = prefix(for: name).appendingPathComponent("user.reg")
        guard let text = try? String(contentsOf: registry, encoding: .utf8) else { return nil }
        var inDesktop = false
        for line in text.split(separator: "\n") {
            if line.hasPrefix("[") {
                inDesktop = line.hasPrefix("[Control Panel\\\\Desktop]")
            } else if inDesktop, line.hasPrefix("\"LogPixels\"=dword:") {
                return Int(line.dropFirst("\"LogPixels\"=dword:".count), radix: 16)
            }
        }
        return nil
    }

    /// Gives the bottle its own Documents, Downloads, Music, Pictures and Videos.
    ///
    /// Wine links these to the Mac's own folders. macOS guards those, so every
    /// time a game or Steam touched one (games keep saves in Documents), macOS
    /// asked for permission on Parable's behalf, and Windows programs could see
    /// the user's files. Each folder gets a desktop.ini, as on Windows, because
    /// Wine replaces empty folders with links again when it updates the bottle.
    /// Replacing a link hides whatever programs saved through it, so this is
    /// meant for new bottles. It never touches the Mac folders themselves.
    public func keepUserFoldersInBottle(_ name: String) throws {
        let fm = FileManager.default
        let users = prefix(for: name).appendingPathComponent("drive_c/users", isDirectory: true)
        let accounts = (try? fm.contentsOfDirectory(at: users, includingPropertiesForKeys: nil)) ?? []
        for account in accounts where account.lastPathComponent != "Public" {
            for folder in ["Documents", "Downloads", "Music", "Pictures", "Videos"] {
                let url = account.appendingPathComponent(folder, isDirectory: true)
                if (try? fm.destinationOfSymbolicLink(atPath: url.path)) != nil {
                    try fm.removeItem(at: url)  // removes the link, not what it points to
                }
                try fm.createDirectory(at: url, withIntermediateDirectories: true)
                let marker = url.appendingPathComponent("desktop.ini")
                if !fm.fileExists(atPath: marker.path) {
                    try Data("[.ShellClassInfo]\r\n".utf8).write(to: marker)
                }
            }
        }
    }

    /// Moves a bottle, including everything installed in it, to the Trash.
    public func trash(_ name: String) throws {
        _ = try load(name)
        try FileManager.default.trashItem(at: directory(for: name), resultingItemURL: nil)
    }
}
