import Foundation

/// Builds argv for `/bin/sh -c` so plugin arguments land in `$1`, not `$0`.
enum ShShellInvocation {
    static func argv(command: String, arguments: [String]) -> [String] {
        ["-c", command, "eave"] + arguments
    }
}
