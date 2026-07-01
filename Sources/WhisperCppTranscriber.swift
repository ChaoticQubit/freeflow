import Foundation
import os.log

private let whisperLog = OSLog(subsystem: "com.zachlatta.freeflow", category: "WhisperCpp")

/// Local transcription via the `whisper-cli` binary from the
/// `whisper-cpp` Homebrew package (or a user-supplied path).
///
/// The design deliberately shells out rather than linking whisper.cpp
/// into the app. That keeps the Makefile-based build free of C++
/// dependencies and lets users upgrade whisper.cpp independently via
/// `brew upgrade whisper-cpp`. The tradeoff is one Process spawn per
/// dictation, which adds ~20 ms — negligible next to model inference
/// time.
final class WhisperCppTranscriber: Transcriber, @unchecked Sendable {

    private let modelURL: URL

    init(modelURL: URL) {
        self.modelURL = modelURL
    }

    /// Locate the `whisper-cli` binary on this system. Checks known
    /// Homebrew locations plus `PATH`. Returns nil if not installed.
    static func locateBinary() -> URL? {
        let candidates = [
            "/opt/homebrew/bin/whisper-cli",     // Apple Silicon Homebrew
            "/usr/local/bin/whisper-cli",        // Intel Homebrew
            "/opt/homebrew/bin/whisper-cpp",     // legacy package name
            "/usr/local/bin/whisper-cpp",
        ]
        for path in candidates {
            if FileManager.default.isExecutableFile(atPath: path) {
                return URL(fileURLWithPath: path)
            }
        }
        // Fallback: honor $PATH via /usr/bin/env.
        if let envBin = findViaEnv(name: "whisper-cli") ?? findViaEnv(name: "whisper-cpp") {
            return envBin
        }
        return nil
    }

    private static func findViaEnv(name: String) -> URL? {
        let proc = Process()
        proc.launchPath = "/usr/bin/which"
        proc.arguments = [name]
        let pipe = Pipe()
        proc.standardOutput = pipe
        proc.standardError = Pipe()
        do {
            try proc.run()
            proc.waitUntilExit()
        } catch {
            return nil
        }
        guard proc.terminationStatus == 0 else { return nil }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let path = String(data: data, encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return path.isEmpty ? nil : URL(fileURLWithPath: path)
    }

    func transcribe(fileURL: URL) async throws -> String {
        guard let binary = Self.locateBinary() else {
            throw LocalTranscriptionError.binaryMissing(
                "whisper-cli not found. Install with: brew install whisper-cpp"
            )
        }
        guard FileManager.default.fileExists(atPath: modelURL.path) else {
            throw LocalTranscriptionError.modelMissing(
                "Whisper model file missing: \(modelURL.lastPathComponent)"
            )
        }

        os_log(.info, log: whisperLog,
               "Transcribing %{public}@ with model %{public}@",
               fileURL.lastPathComponent, modelURL.lastPathComponent)

        // Run the process on a background task so we don't block the
        // MainActor while whisper churns. Task cancellation is honored
        // by terminating the process.
        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<String, Error>) in
                DispatchQueue.global(qos: .userInitiated).async {
                    let proc = Process()
                    proc.executableURL = binary
                    proc.arguments = [
                        "-m", self.modelURL.path,
                        "-f", fileURL.path,
                        "--no-timestamps",  // plain text output, no [00:00.000] prefixes
                        "--output-txt",
                        "-of", fileURL.deletingPathExtension().path,  // whisper appends .txt
                    ]

                    let stdout = Pipe()
                    let stderr = Pipe()
                    proc.standardOutput = stdout
                    proc.standardError = stderr

                    do {
                        try proc.run()
                    } catch {
                        continuation.resume(throwing: LocalTranscriptionError.recognitionFailed(
                            "Failed to launch whisper-cli: \(error.localizedDescription)"
                        ))
                        return
                    }
                    Self.activeProcess = proc
                    proc.waitUntilExit()
                    Self.activeProcess = nil

                    guard proc.terminationStatus == 0 else {
                        let errData = stderr.fileHandleForReading.readDataToEndOfFile()
                        let errMsg = String(data: errData, encoding: .utf8)?
                            .trimmingCharacters(in: .whitespacesAndNewlines) ?? "unknown error"
                        continuation.resume(throwing: LocalTranscriptionError.recognitionFailed(
                            "whisper-cli failed (\(proc.terminationStatus)): \(errMsg)"
                        ))
                        return
                    }

                    // whisper-cli writes the transcript to <input>.txt.
                    // Prefer that over stdout since stdout also contains
                    // progress logs that would need parsing.
                    let txtURL = fileURL.deletingPathExtension().appendingPathExtension("txt")
                    if let text = try? String(contentsOf: txtURL, encoding: .utf8) {
                        try? FileManager.default.removeItem(at: txtURL)
                        continuation.resume(returning: text.trimmingCharacters(in: .whitespacesAndNewlines))
                    } else {
                        // Fallback to stdout as best-effort.
                        let outData = stdout.fileHandleForReading.readDataToEndOfFile()
                        let text = String(data: outData, encoding: .utf8) ?? ""
                        continuation.resume(returning: text.trimmingCharacters(in: .whitespacesAndNewlines))
                    }
                }
            }
        } onCancel: {
            Self.activeProcess?.terminate()
        }
    }

    nonisolated(unsafe) private static var activeProcess: Process?
}
