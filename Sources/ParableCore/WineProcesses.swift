import Darwin
import Foundation

/// Finds the processes belonging to a bottle by looking at what is running.
///
/// Wine's own bookkeeping isn't reliable for this on macOS: it keeps a lock file
/// under /tmp, and macOS deletes files there that haven't been touched for three
/// days. A Steam left running for longer than that loses its lock, and from then
/// on neither Parable nor Wine can see the session or stop it the normal way.
enum WineProcesses {
    /// Every process running in the bottle whose Windows environment is `prefix`.
    static func pids(prefix: URL, engines: URL) -> [pid_t] {
        let marker = "WINEPREFIX=" + prefix.path
        let me = getpid()
        return allPids().filter { pid in
            guard pid != me, let path = executablePath(of: pid) else { return false }
            // Wine processes run from an engine, or from the per-program links the
            // engine makes in the temporary folder.
            guard path.hasPrefix(engines.path) || path.contains("/winetemp-") else { return false }
            return commandLine(of: pid).environment.contains(marker)
        }
    }

    /// The Windows programs running in the bottle, as the files on the Mac's disk
    /// they were started from. Wine's own background processes, which aren't
    /// started from a file inside the bottle, are left out.
    static func programs(prefix: URL, engines: URL) -> [(pid: pid_t, file: URL)] {
        pids(prefix: prefix, engines: engines).compactMap { pid in
            guard let first = commandLine(of: pid).arguments.first,
                  let file = macFile(forProgram: first, prefix: prefix) else { return nil }
            return (pid, file)
        }
    }

    /// Where a program's path, as Wine sees it, is on the Mac's disk. Wine starts
    /// some programs by their Mac path and others by their Windows one.
    static func macFile(forProgram path: String, prefix: URL) -> URL? {
        let drive = prefix.appendingPathComponent("drive_c").resolvingSymlinksInPath().path
        var file: URL
        if path.hasPrefix("/") {
            file = URL(fileURLWithPath: path)
        } else if path.count > 2, path.dropFirst().hasPrefix(":\\") {
            // C:\Program Files\... -> <prefix>/dosdevices/c:/Program Files/...
            let letter = path.prefix(2).lowercased()
            let rest = path.dropFirst(3).replacingOccurrences(of: "\\", with: "/")
            file = prefix.appendingPathComponent("dosdevices/\(letter)/\(rest)")
        } else {
            return nil
        }
        file = file.standardizedFileURL.resolvingSymlinksInPath()
        return file.path.hasPrefix(drive + "/") ? file : nil
    }

    /// Asks the processes to quit, then insists.
    static func terminate(_ pids: [pid_t], prefix: URL, engines: URL) {
        func remaining() -> [pid_t] { self.pids(prefix: prefix, engines: engines).filter(pids.contains) }
        for signal in [SIGTERM, SIGKILL] {
            for pid in remaining() { kill(pid, signal) }
            for _ in 0..<20 where !remaining().isEmpty { usleep(100_000) }
        }
    }

    private static func allPids() -> [pid_t] {
        let count = proc_listallpids(nil, 0)
        guard count > 0 else { return [] }
        var pids = [pid_t](repeating: 0, count: Int(count) + 64)
        let filled = pids.withUnsafeMutableBytes {
            proc_listallpids($0.baseAddress, Int32($0.count))
        }
        return Array(pids.prefix(Int(max(filled, 0))))
    }

    private static func executablePath(of pid: pid_t) -> String? {
        var buffer = [CChar](repeating: 0, count: 4096)  // PROC_PIDPATHINFO_MAXSIZE
        let length = proc_pidpath(pid, &buffer, UInt32(buffer.count))
        guard length > 0 else { return nil }
        return String(decoding: buffer.prefix(Int(length)).map { UInt8(bitPattern: $0) }, as: UTF8.self)
    }

    /// A process's arguments and environment variables, which macOS lets a user
    /// read for their own processes. Wine rewrites its processes' names, but not these.
    private static func commandLine(of pid: pid_t) -> (arguments: [String], environment: [String]) {
        var mib: [Int32] = [CTL_KERN, KERN_PROCARGS2, pid]
        var size = 0
        guard sysctl(&mib, 3, nil, &size, nil, 0) == 0, size > MemoryLayout<Int32>.size else { return ([], []) }
        var buffer = [UInt8](repeating: 0, count: size)
        guard sysctl(&mib, 3, &buffer, &size, nil, 0) == 0 else { return ([], []) }

        // Layout: argc, the executable path, padding, argc arguments, then the environment.
        var argc = buffer.withUnsafeBytes { $0.load(as: Int32.self) }
        var index = MemoryLayout<Int32>.size
        while index < size, buffer[index] != 0 { index += 1 }  // executable path
        while index < size, buffer[index] == 0 { index += 1 }  // padding

        var arguments: [String] = [], environment: [String] = []
        var start = index
        while index < size {
            if buffer[index] == 0 {
                if index > start {
                    let string = String(decoding: buffer[start..<index], as: UTF8.self)
                    if argc > 0 { argc -= 1; arguments.append(string) } else { environment.append(string) }
                } else if argc == 0 {
                    break  // an empty string after the arguments ends the environment
                }
                start = index + 1
            }
            index += 1
        }
        return (arguments, environment)
    }
}
