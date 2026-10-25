import Foundation

public enum StarterPlugin {
    public static let filename = "clock.5s.sh"
    public static let contents = """
#!/bin/sh
date +%H:%M

"""

    /// True only when the folder holds no plugin file at all. A folder with a
    /// rejected plugin still counts as used, because the person put it there.
    public static func shouldSeed(existingFilenames: [String]) -> Bool {
        for name in existingFilenames {
            if name.hasPrefix(".") { continue }
            if name.hasSuffix(".sh") { return false }
        }
        return true
    }
}
