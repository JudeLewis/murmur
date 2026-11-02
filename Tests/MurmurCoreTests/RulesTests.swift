import Foundation
import Testing

/// Project rules a compiler can't check, read straight from the files.
@Suite("Project rules")
struct RulesTests {
    /// The project folder, found from this file's own path.
    private static let root = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()  // MurmurCoreTests
        .deletingLastPathComponent()  // Tests
        .deletingLastPathComponent()

    private static func files(in folder: String, ending: String) -> [URL] {
        let start = root.appending(path: folder)
        let found = FileManager.default.enumerator(at: start, includingPropertiesForKeys: nil)?
            .compactMap { $0 as? URL } ?? []
        return found.filter { $0.lastPathComponent.hasSuffix(ending) }
    }

    private static func read(_ url: URL) -> String {
        (try? String(contentsOf: url, encoding: .utf8)) ?? ""
    }

    @Test func everySuiteNamesASectionThatIsInTheSpec() throws {
        let spec = Self.read(Self.root.appending(path: "SPEC.md"))
        let headings = Set(spec.split(separator: "\n").compactMap { line -> String? in
            guard line.hasPrefix("### ") else { return nil }
            return line.dropFirst(4).split(separator: " ").first.map(String.init)
        })
        #expect(!headings.isEmpty, "SPEC.md has no ### section headings")

        let suite = try Regex(#"@Suite\("(\d+\.\d+)"#)
        for file in Self.files(in: "Tests", ending: ".swift") {
            for match in Self.read(file).matches(of: suite) {
                let section = String(match.output[1].substring ?? "")
                #expect(headings.contains(section), "\(file.lastPathComponent) names section \(section), which isn't in SPEC.md")
            }
        }
    }

    @Test func noEmDashesAnywhere() {
        let emDash = "\u{2014}"
        let files = Self.files(in: "Sources", ending: ".swift")
            + Self.files(in: "Tests", ending: ".swift")
            + Self.files(in: "docs", ending: ".md")
            + Self.files(in: "scripts", ending: ".sh")
            + ["CLAUDE.md", "SPEC.md", "TODO.md", "FUTURE_TEST.md"].map { Self.root.appending(path: $0) }
        for file in files {
            #expect(!Self.read(file).contains(emDash), "\(file.lastPathComponent) has an em dash")
        }
    }
}
