import Foundation

/// Where Parable keeps its data on disk.
///
///     ~/Library/Application Support/Parable/
///         Engines/<name>/          an unpacked Wine build
///         Bottles/<name>/
///             bottle.json          metadata
///             prefix/              the WINEPREFIX (fake C: drive, registry)
public struct Paths: Sendable {
    public let root: URL

    public init(root: URL? = nil) {
        if let root {
            self.root = root
        } else if let override = ProcessInfo.processInfo.environment["PARABLE_HOME"] {
            self.root = URL(fileURLWithPath: override, isDirectory: true)
        } else {
            self.root = FileManager.default
                .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
                .appendingPathComponent("Parable", isDirectory: true)
        }
    }

    public var engines: URL { root.appendingPathComponent("Engines", isDirectory: true) }
    public var bottles: URL { root.appendingPathComponent("Bottles", isDirectory: true) }
    public var downloads: URL { root.appendingPathComponent("Downloads", isDirectory: true) }
}

public struct ParableError: Error, CustomStringConvertible {
    public let description: String
    public init(_ description: String) { self.description = description }
}

/// Names become directory names, so keep them boring.
func validateName(_ name: String, kind: String) throws {
    let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_."))
    guard !name.isEmpty, !name.hasPrefix("."),
          name.unicodeScalars.allSatisfy(allowed.contains) else {
        throw ParableError("\(kind) name '\(name)' must use only letters, digits, '-', '_' and '.'")
    }
}
