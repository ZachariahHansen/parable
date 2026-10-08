import Foundation

/// A Wine build Parable can launch programs with.
public struct Engine: Sendable, Identifiable {
    public let name: String
    public let directory: URL
    /// The `wine` launcher inside the unpacked build.
    public let wineBinary: URL

    public var id: String { name }

    /// Directory holding wine, wineserver, wineboot...
    public var binDirectory: URL { wineBinary.deletingLastPathComponent() }

    /// Directory holding Wine's own modules plus the native libraries it loads
    /// by name at runtime (FreeType, GnuTLS, SDL...).
    public var libDirectory: URL {
        binDirectory.deletingLastPathComponent().appendingPathComponent("lib")
    }

    /// True when Apple's D3DMetal (DirectX 11/12 on Metal) has been added to this build.
    public var hasD3DMetal: Bool {
        FileManager.default.fileExists(
            atPath: libDirectory.appendingPathComponent("external/D3DMetal.framework").path)
    }
}

/// A prebuilt engine that `parable engine install <preset>` can fetch.
public struct EnginePreset: Sendable, Identifiable {
    public let name: String
    public let summary: String
    public let url: URL

    public var id: String { name }

    public static let all: [EnginePreset] = [
        EnginePreset(
            name: "parable",
            summary: "Parable's own engine: CrossOver 26.3 source (Wine 11.0) with fixes for Steam, online play and controllers.",
            url: URL(string: "https://github.com/ZachariahHansen/parable/releases/download/engine-11.0-1/parable-engine-11.0-1.tar.xz")!),
    ]

    public static func named(_ name: String) -> EnginePreset? {
        all.first { $0.name == name }
    }
}

public struct EngineStore: Sendable {
    public let paths: Paths
    public init(paths: Paths = Paths()) { self.paths = paths }

    public func list() -> [Engine] {
        let fm = FileManager.default
        let names = (try? fm.contentsOfDirectory(atPath: paths.engines.path)) ?? []
        return names.sorted().compactMap { try? load($0) }
    }

    public func load(_ name: String) throws -> Engine {
        let dir = paths.engines.appendingPathComponent(name, isDirectory: true)
        guard FileManager.default.fileExists(atPath: dir.path) else {
            throw ParableError("no engine named '\(name)' (try `parable engine list`)")
        }
        guard let wine = Self.findWine(in: dir) else {
            throw ParableError("engine '\(name)' has no bin/wine inside \(dir.path)")
        }
        return Engine(name: name, directory: dir, wineBinary: wine)
    }

    /// Downloads a `.tar.xz`/`.tar.gz` Wine build and unpacks it as engine `name`.
    public func install(name: String, from url: URL) throws -> Engine {
        try validateName(name, kind: "engine")
        let fm = FileManager.default
        let dest = paths.engines.appendingPathComponent(name, isDirectory: true)
        guard !fm.fileExists(atPath: dest.path) else {
            throw ParableError("engine '\(name)' is already installed at \(dest.path)")
        }

        let archive: URL
        if url.isFileURL {
            archive = url
        } else {
            try fm.createDirectory(at: paths.downloads, withIntermediateDirectories: true)
            archive = paths.downloads.appendingPathComponent(url.lastPathComponent)
            // -C - resumes a partial download instead of starting over.
            try Shell.run("/usr/bin/curl",
                          ["-fL", "--progress-bar", "-C", "-", "-o", archive.path, url.absoluteString])
        }

        // Unpack next to the destination, then move into place, so a failed
        // extraction never leaves a half-installed engine behind.
        let staging = paths.engines.appendingPathComponent(".staging-\(name)", isDirectory: true)
        try? fm.removeItem(at: staging)
        try fm.createDirectory(at: staging, withIntermediateDirectories: true)
        do {
            try Shell.run("/usr/bin/tar", ["-xf", archive.path, "-C", staging.path])
            guard Self.findWine(in: staging) != nil else {
                throw ParableError("archive did not contain a bin/wine; is it a Wine build?")
            }
            try fm.moveItem(at: staging, to: dest)
        } catch {
            try? fm.removeItem(at: staging)
            throw error
        }
        let engine = try load(name)
        // Engines ship without Apple's D3DMetal; add the user's imported copy if there is one.
        let d3dmetal = D3DMetalStore(paths: paths)
        if d3dmetal.isImported { try d3dmetal.install(into: engine) }
        return engine
    }

    /// Wine builds nest the real tree at different depths
    /// (e.g. `Wine Devel.app/Contents/Resources/wine/bin/wine`), so search for it.
    static func findWine(in directory: URL) -> URL? {
        let fm = FileManager.default
        guard let walker = fm.enumerator(at: directory, includingPropertiesForKeys: nil) else {
            return nil
        }
        var best: URL?
        for case let url as URL in walker {
            guard url.deletingLastPathComponent().lastPathComponent == "bin",
                  ["wine", "wine64"].contains(url.lastPathComponent),
                  fm.isExecutableFile(atPath: url.path) else { continue }
            // Prefer the shallowest match, and `wine` over `wine64`.
            if let current = best {
                let shallower = url.pathComponents.count < current.pathComponents.count
                let sameDirPreferred = url.pathComponents.count == current.pathComponents.count
                    && url.lastPathComponent == "wine"
                if shallower || sameDirPreferred { best = url }
            } else {
                best = url
            }
        }
        return best
    }
}
