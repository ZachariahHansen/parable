import Foundation

/// Apple's D3DMetal: the DirectX 11/12 to Metal layer from the Game Porting Toolkit.
///
/// Parable doesn't ship it. Each user downloads the toolkit from Apple and imports
/// it here; Parable keeps a copy in its data folder and adds it to engines.
public struct D3DMetalStore: Sendable {
    public let paths: Paths
    public init(paths: Paths = Paths()) { self.paths = paths }

    /// The Windows-side libraries D3DMetal replaces in an engine.
    static let modules = ["atidxx64", "d3d10", "d3d11", "d3d12", "dxgi", "nvapi64", "nvngx"]
    static let required = ["d3d11", "d3d12", "dxgi"]

    var directory: URL { paths.root.appendingPathComponent("D3DMetal", isDirectory: true) }
    private var external: URL { directory.appendingPathComponent("external", isDirectory: true) }
    private var windows: URL { directory.appendingPathComponent("x86_64-windows", isDirectory: true) }

    /// True once a toolkit has been imported.
    public var isImported: Bool {
        FileManager.default.fileExists(atPath: external.appendingPathComponent("D3DMetal.framework").path)
    }

    /// Copies D3DMetal out of a Game Porting Toolkit folder, typically the mounted
    /// disk image (`/Volumes/Game Porting Toolkit-…`) or anything containing it.
    public func importToolkit(from folder: URL) throws {
        let fm = FileManager.default
        guard let framework = Self.findFramework(in: folder) else {
            throw ParableError("no D3DMetal.framework found in \(folder.path); choose the Game Porting Toolkit disk image or folder")
        }
        let sourceExternal = framework.deletingLastPathComponent()
        let library = sourceExternal.appendingPathComponent("libd3dshared.dylib")
        // Apple's layout is lib/external next to lib/wine/x86_64-windows.
        let sourceWindows = [
            sourceExternal.deletingLastPathComponent().appendingPathComponent("wine/x86_64-windows"),
            sourceExternal.deletingLastPathComponent().appendingPathComponent("x86_64-windows"),
        ].first { fm.fileExists(atPath: $0.appendingPathComponent("d3d11.dll").path) }
        guard fm.fileExists(atPath: library.path), let sourceWindows else {
            throw ParableError("\(sourceExternal.path) has D3DMetal.framework but not the rest of the toolkit's redist folder")
        }
        for module in Self.required where !fm.fileExists(atPath: sourceWindows.appendingPathComponent("\(module).dll").path) {
            throw ParableError("the toolkit is missing \(module).dll")
        }

        // Build the new copy beside the old one, so a failed import changes nothing.
        let staging = paths.root.appendingPathComponent(".D3DMetal-import", isDirectory: true)
        try? fm.removeItem(at: staging)
        try fm.createDirectory(at: staging.appendingPathComponent("x86_64-windows"), withIntermediateDirectories: true)
        do {
            try fm.createDirectory(at: staging.appendingPathComponent("external"), withIntermediateDirectories: true)
            try fm.copyItem(at: framework, to: staging.appendingPathComponent("external/D3DMetal.framework"))
            try fm.copyItem(at: library, to: staging.appendingPathComponent("external/libd3dshared.dylib"))
            for module in Self.modules {
                let dll = sourceWindows.appendingPathComponent("\(module).dll")
                guard fm.fileExists(atPath: dll.path) else { continue }
                try fm.copyItem(at: dll, to: staging.appendingPathComponent("x86_64-windows/\(module).dll"))
            }
            try? fm.removeItem(at: directory)
            try fm.moveItem(at: staging, to: directory)
        } catch {
            try? fm.removeItem(at: staging)
            throw error
        }
    }

    /// Adds the imported D3DMetal to an engine, keeping the engine's own DirectX
    /// libraries in `wined3d-originals` so the change can be undone.
    public func install(into engine: Engine) throws {
        guard isImported else { throw ParableError("D3DMetal has not been imported yet") }
        let fm = FileManager.default
        let lib = engine.libDirectory
        let engineWindows = lib.appendingPathComponent("wine/x86_64-windows")
        let engineUnix = lib.appendingPathComponent("wine/x86_64-unix")
        let originals = lib.deletingLastPathComponent().appendingPathComponent("wined3d-originals")
        try fm.createDirectory(at: originals, withIntermediateDirectories: true)

        let engineExternal = lib.appendingPathComponent("external")
        try? fm.removeItem(at: engineExternal)
        try fm.copyItem(at: external, to: engineExternal)

        for module in Self.modules {
            let source = windows.appendingPathComponent("\(module).dll")
            guard fm.fileExists(atPath: source.path) else { continue }
            let target = engineWindows.appendingPathComponent("\(module).dll")
            let saved = originals.appendingPathComponent("\(module).dll")
            if fm.fileExists(atPath: target.path) {
                // Only the first install finds the engine's own library here.
                if fm.fileExists(atPath: saved.path) { try fm.removeItem(at: target) }
                else { try fm.moveItem(at: target, to: saved) }
            }
            try fm.copyItem(at: source, to: target)

            // A symlink, not a copy: libd3dshared finds the framework relative to
            // its real location, and fails silently when moved away from it.
            let link = engineUnix.appendingPathComponent("\(module).so")
            try? fm.removeItem(at: link)
            try fm.createSymbolicLink(atPath: link.path, withDestinationPath: "../../external/libd3dshared.dylib")
        }
    }

    private static func findFramework(in folder: URL) -> URL? {
        if folder.lastPathComponent == "D3DMetal.framework" { return folder }
        let fm = FileManager.default
        guard let walker = fm.enumerator(at: folder, includingPropertiesForKeys: nil,
                                         options: [.skipsHiddenFiles]) else { return nil }
        for case let url as URL in walker {
            if url.lastPathComponent == "D3DMetal.framework" { return url }
            // The toolkit keeps it a few folders down; don't wander through a whole disk.
            if walker.level >= 6 { walker.skipDescendants() }
        }
        return nil
    }
}
