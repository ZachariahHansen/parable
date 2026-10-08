import Foundation

enum Shell {
    /// Runs a tool with inherited stdio and returns its exit status.
    @discardableResult
    static func status(_ executable: String, _ arguments: [String],
                       environment: [String: String]? = nil) throws -> Int32 {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments
        if let environment { process.environment = environment }
        try process.run()
        process.waitUntilExit()
        return process.terminationStatus
    }

    /// Like `status`, but a non-zero exit is an error.
    static func run(_ executable: String, _ arguments: [String],
                    environment: [String: String]? = nil) throws {
        let code = try status(executable, arguments, environment: environment)
        guard code == 0 else {
            let tool = URL(fileURLWithPath: executable).lastPathComponent
            throw ParableError("\(tool) exited with status \(code)")
        }
    }
}
