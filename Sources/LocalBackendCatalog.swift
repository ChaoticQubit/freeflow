import Foundation

/// Static identifiers for the built-in local backends. External model
/// files under `models/` become entries whose IDs are prefixed with
/// `"whisper:"` (see `LocalBackendCatalog.load`).
enum LocalBackendKind {
    /// Apple's on-device speech recognizer. Always available on macOS
    /// 13+ (though downloading the on-device model may be gated by
    /// system settings). No model file — the OS provides the model.
    case appleSpeech
    /// A whisper.cpp `ggml-*.bin` model file discovered on disk. The
    /// associated URL points to the model file.
    case whisperGGML(modelURL: URL)
}

struct LocalBackend: Identifiable, Hashable {
    /// Stable identifier used for persistence and picker `tag(_:)`.
    /// Format: `"apple-speech"` or `"whisper:<filename>"`.
    let id: String
    /// User-facing name shown in the dropdown.
    let displayName: String
    /// Reason this backend can't be used right now, or nil if it can.
    /// Rendered as a subtitle in the picker.
    let unavailableReason: String?
    let kind: LocalBackendKind

    var isAvailable: Bool { unavailableReason == nil }

    static func == (lhs: LocalBackend, rhs: LocalBackend) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}

enum LocalBackendCatalog {
    static let appleSpeechID = "apple-speech"
    static let whisperIDPrefix = "whisper:"

    /// Root directory that holds user-provided local model files.
    ///
    /// Created on first read if missing. Layout:
    ///
    /// ```
    /// ~/Library/Application Support/FreeFlow/models/
    /// └── whisper/
    ///     ├── ggml-base.en.bin
    ///     ├── ggml-small.bin
    ///     └── …
    /// ```
    static func modelsRoot() -> URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let root = appSupport
            .appendingPathComponent(AppName.displayName, isDirectory: true)
            .appendingPathComponent("models", isDirectory: true)
        try? FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        // Create the whisper subfolder eagerly so users have a clear
        // place to drop files without needing to mkdir themselves.
        try? FileManager.default.createDirectory(
            at: root.appendingPathComponent("whisper", isDirectory: true),
            withIntermediateDirectories: true
        )
        return root
    }

    /// Discover every local backend the user could pick right now.
    ///
    /// Apple Speech is always listed first (falls back gracefully if
    /// the on-device model isn't downloaded). Whisper entries are one
    /// per `.bin` file in `models/whisper/`, sorted alphabetically.
    /// Entries that can't run (missing binary, unreadable file) still
    /// appear in the list but carry an `unavailableReason` so the UI
    /// can show them grayed out.
    static func load() -> [LocalBackend] {
        var results: [LocalBackend] = []

        // Apple Speech — always present. Availability is deferred to
        // recognition time; here we optimistically list it.
        results.append(
            LocalBackend(
                id: appleSpeechID,
                displayName: "Apple Speech (built-in)",
                unavailableReason: nil,
                kind: .appleSpeech
            )
        )

        // Whisper — scan `models/whisper/` for `.bin` files.
        let whisperDir = modelsRoot().appendingPathComponent("whisper", isDirectory: true)
        let contents = (try? FileManager.default.contentsOfDirectory(
            at: whisperDir,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        )) ?? []

        let binFiles = contents
            .filter { $0.pathExtension.lowercased() == "bin" }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }

        let whisperBinaryReason = WhisperCppTranscriber.locateBinary() == nil
            ? "whisper-cli not found. Install with: brew install whisper-cpp"
            : nil

        for url in binFiles {
            let name = url.deletingPathExtension().lastPathComponent
            results.append(
                LocalBackend(
                    id: whisperIDPrefix + url.lastPathComponent,
                    displayName: "Whisper — \(name)",
                    unavailableReason: whisperBinaryReason,
                    kind: .whisperGGML(modelURL: url)
                )
            )
        }

        return results
    }

    /// Resolve a persisted backend ID against the current on-disk
    /// state. Returns nil if the ID no longer maps to any backend
    /// (e.g. the user deleted the model file).
    static func backend(forID id: String) -> LocalBackend? {
        load().first { $0.id == id }
    }

    /// Build a live transcriber for a chosen backend, ready to accept
    /// a WAV file. Throws `LocalTranscriptionError` if the backend
    /// isn't currently runnable.
    static func makeTranscriber(for backend: LocalBackend) throws -> Transcriber {
        if let reason = backend.unavailableReason {
            throw LocalTranscriptionError.backendUnavailable(reason)
        }
        switch backend.kind {
        case .appleSpeech:
            return AppleSpeechTranscriber()
        case .whisperGGML(let modelURL):
            return WhisperCppTranscriber(modelURL: modelURL)
        }
    }
}
