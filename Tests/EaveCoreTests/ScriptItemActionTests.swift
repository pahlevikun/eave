import Foundation
import Testing
@testable import EaveCore

@Suite("ScriptItemAction")
struct ScriptItemActionTests {
    @Test func httpsHrefOpensURL() throws {
        let item = ScriptItem(
            title: "Link",
            namespace: "clock",
            parameters: ["href": "https://example.com/path"]
        )
        let action = item.action
        guard case .openURL(let url) = action else {
            Issue.record("Expected openURL, got \(action)")
            return
        }
        #expect(url.absoluteString == "https://example.com/path")
    }

    @Test func mailtoHrefOpensURL() throws {
        let item = ScriptItem(
            title: "Mail",
            namespace: "clock",
            parameters: ["href": "mailto:hello@example.com"]
        )
        guard case .openURL(let url) = item.action else {
            Issue.record("Expected openURL")
            return
        }
        #expect(url.scheme == "mailto")
    }

    @Test func relativeHrefIsUnsupported() {
        let item = ScriptItem(
            title: "Bad",
            namespace: "clock",
            parameters: ["href": "relative/path"]
        )
        #expect(item.action == .unsupported(parameter: "href"))
    }

    @Test func emptyHrefIsUnsupported() {
        let item = ScriptItem(
            title: "Empty",
            namespace: "clock",
            parameters: ["href": ""]
        )
        #expect(item.action == .unsupported(parameter: "href"))
    }

    @Test func bashWinsOverHref() {
        let item = ScriptItem(
            title: "Shell",
            namespace: "clock",
            parameters: ["href": "https://example.com", "bash": "echo hi"]
        )
        #expect(item.action == .unsupported(parameter: "bash"))
    }

    @Test func noParametersIsNone() {
        let item = ScriptItem(title: "Plain", namespace: "clock")
        #expect(item.action == .none)
    }
}
