import Foundation

enum CredentialRecipeTests {
    static func run() {
        do {
            try createsPrivateSettings()
            try createsPrivateDevelopmentSettings()
            try preservesExistingCredentials()
            try refusesMalformedSettings()
        } catch {
            fatalError("Credential recipe fixture failed: \(error)")
        }
    }

    private static func createsPrivateSettings() throws {
        try withFixture { directory, settings in
            let status = try runRecipe(home: directory)
            TestSupport.expectEqual(status, 0)
            let values = try JSONDecoder().decode([String: String].self, from: Data(contentsOf: settings))
            TestSupport.expectEqual(values["groq_api_key"], "gsk_...")
            TestSupport.expectEqual(values["api_base_url"], "https://api.groq.com/openai/v1")
            let mode = try permissions(at: settings)
            TestSupport.expectEqual(mode, 0o600)
        }
    }

    private static func preservesExistingCredentials() throws {
        try withFixture { directory, settings in
            try Data("{\"transcription_api_key\":\"synthetic-existing-key\"}".utf8).write(to: settings)
            try FileManager.default.setAttributes([.posixPermissions: 0o644], ofItemAtPath: settings.path)
            let status = try runRecipe(home: directory)
            TestSupport.expectEqual(status, 0)
            let values = try JSONDecoder().decode([String: String].self, from: Data(contentsOf: settings))
            TestSupport.expectEqual(values["transcription_api_key"], "synthetic-existing-key")
            TestSupport.expectEqual(values["groq_api_key"], "gsk_...")
            let mode = try permissions(at: settings)
            TestSupport.expectEqual(mode, 0o600)
        }
    }

    private static func createsPrivateDevelopmentSettings() throws {
        try withFixture(appName: "FreeFlow Dev") { directory, settings in
            let status = try runRecipe(home: directory, appName: "FreeFlow Dev")
            TestSupport.expectEqual(status, 0)
            let values = try JSONDecoder().decode([String: String].self, from: Data(contentsOf: settings))
            TestSupport.expectEqual(values["groq_api_key"], "gsk_...")
            TestSupport.expectEqual(values["api_base_url"], "https://api.groq.com/openai/v1")
            let mode = try permissions(at: settings)
            TestSupport.expectEqual(mode, 0o600)
            let releaseSettings = directory.appendingPathComponent("Library/Application Support/FreeFlow/.settings")
            TestSupport.expect(
                !FileManager.default.fileExists(atPath: releaseSettings.path),
                "The development recipe must leave release settings untouched"
            )
        }
    }

    private static func refusesMalformedSettings() throws {
        try withFixture { directory, settings in
            let original = Data("{invalid".utf8)
            try original.write(to: settings)
            let status = try runRecipe(home: directory)
            let result = try Data(contentsOf: settings)
            TestSupport.expect(status != 0, "Malformed settings must stop the recipe")
            TestSupport.expectEqual(result, original)
        }
    }

    private static func withFixture(appName: String = "FreeFlow", _ body: (URL, URL) throws -> Void) throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let settings = directory.appendingPathComponent("Library/Application Support/\(appName)/.settings")
        try FileManager.default.createDirectory(
            at: settings.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        defer { try? FileManager.default.removeItem(at: directory) }
        try body(directory, settings)
    }

    private static func permissions(at url: URL) throws -> Int {
        let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
        return (attributes[.posixPermissions] as? NSNumber)?.intValue ?? -1
    }

    private static func runRecipe(home: URL, appName: String = "FreeFlow") throws -> Int32 {
        let readme = try String(contentsOfFile: "README.md", encoding: .utf8)
        let section = readme.components(separatedBy: "### API credentials")[1]
        let recipe = section.components(separatedBy: "```bash\n")[1]
            .components(separatedBy: "```")[0]
            .replacingOccurrences(of: "Application Support/FreeFlow/", with: "Application Support/\(appName)/")
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/bash")
        process.arguments = ["-c", recipe]
        process.environment = ["HOME": home.path, "PATH": "/usr/bin:/bin"]
        let output = Pipe()
        process.standardOutput = output
        process.standardError = output
        try process.run()
        process.waitUntilExit()
        return process.terminationStatus
    }
}
