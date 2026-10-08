import Foundation

/// Facts about the host Mac that decide whether Windows games can run.
public enum SystemCheck {
    public static var isAppleSilicon: Bool {
        var value: Int32 = 0
        var size = MemoryLayout<Int32>.size
        return sysctlbyname("hw.optional.arm64", &value, &size, nil, 0) == 0 && value == 1
    }

    /// Rosetta 2 translates the x86 code in Wine and in the games themselves.
    public static var rosettaInstalled: Bool {
        FileManager.default.fileExists(atPath: "/Library/Apple/usr/libexec/oah/libRosettaRuntime")
    }

    public static var macOSVersion: String {
        let v = ProcessInfo.processInfo.operatingSystemVersion
        return "\(v.majorVersion).\(v.minorVersion).\(v.patchVersion)"
    }

    /// CPU architectures in a Mach-O file, read from its header.
    public static func architectures(of binary: URL) -> Set<String> {
        guard let handle = try? FileHandle(forReadingFrom: binary),
              let data = try? handle.read(upToCount: 4096), data.count >= 8 else { return [] }

        func name(_ cpuType: UInt32) -> String? {
            switch cpuType {
            case 0x0100_0007: "x86_64"
            case 0x0100_000C: "arm64"
            case 0x0000_0007: "i386"
            default: nil
            }
        }
        func u32(_ offset: Int, bigEndian: Bool) -> UInt32 {
            let raw = data.subdata(in: offset..<offset + 4).withUnsafeBytes {
                $0.loadUnaligned(as: UInt32.self)
            }
            return bigEndian ? UInt32(bigEndian: raw) : UInt32(littleEndian: raw)
        }

        switch u32(0, bigEndian: true) {
        case 0xCAFE_BABE:  // universal binary: a table of (cputype, ...) entries
            let count = Int(u32(4, bigEndian: true))
            var found = Set<String>()
            for index in 0..<min(count, 16) {
                let offset = 8 + index * 20
                guard offset + 4 <= data.count else { break }
                if let arch = name(u32(offset, bigEndian: true)) { found.insert(arch) }
            }
            return found
        case 0xCFFA_EDFE, 0xCEFA_EDFE:  // thin little-endian Mach-O
            return name(u32(4, bigEndian: false)).map { [$0] } ?? []
        default:
            return []
        }
    }
}
