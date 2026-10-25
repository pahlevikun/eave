import Testing
@testable import EaveCore

@Suite("StarterPlugin")
struct StarterPluginTests {
    @Test func seedsEmptyFolder() {
        #expect(StarterPlugin.shouldSeed(existingFilenames: []))
    }

    @Test func doesNotSeedWhenAnyShellScriptPresent() {
        #expect(!StarterPlugin.shouldSeed(existingFilenames: ["clock.5s.sh"]))
        #expect(!StarterPlugin.shouldSeed(existingFilenames: ["notes.txt", "cpu.sh"]))
    }

    @Test func seedsWhenOnlyDisabledOrDotfiles() {
        #expect(StarterPlugin.shouldSeed(existingFilenames: [".hidden.sh", "readme.txt"]))
        #expect(StarterPlugin.shouldSeed(existingFilenames: ["clock.5s.sh.disabled"]))
    }

    @Test func contentsShape() {
        #expect(StarterPlugin.contents.hasPrefix("#!/bin/sh"))
        #expect(StarterPlugin.contents.hasSuffix("\n"))
    }
}
