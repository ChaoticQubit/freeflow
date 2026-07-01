import Foundation
import Speech
import AVFoundation
import os.log

private let appleSpeechLog = OSLog(subsystem: "com.zachlatta.freeflow", category: "AppleSpeech")

/// On-device transcription using Apple's `SFSpeechRecognizer`. Runs
/// entirely offline once the OS has downloaded the requested locale's
/// on-device model (System Settings → General → Keyboard → Dictation).
///
/// This class is designed to be created fresh per transcription — it
/// does not hold long-lived recognizer state, so cancellation happens
/// naturally when the enclosing `Task` is cancelled.
final class AppleSpeechTranscriber: Transcriber {

    /// Locale used for recognition. Uses the current process locale so
    /// the user's system language is honored automatically.
    private let locale: Locale

    init(locale: Locale = .current) {
        self.locale = locale
    }

    /// Request user authorization for speech recognition. Presents the
    /// system prompt the first time it's called; subsequent calls
    /// return the cached decision immediately.
    static func requestAuthorization() async -> SFSpeechRecognizerAuthorizationStatus {
        await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status)
            }
        }
    }

    func transcribe(fileURL: URL) async throws -> String {
        // Authorization gate. If the user hasn't granted permission we
        // ask now and, on denial, surface a friendly error rather than
        // a silent empty transcript.
        let status = await Self.requestAuthorization()
        guard status == .authorized else {
            throw LocalTranscriptionError.backendUnavailable(
                "Speech recognition permission not granted. Enable it in System Settings → Privacy & Security → Speech Recognition."
            )
        }

        guard let recognizer = SFSpeechRecognizer(locale: locale) else {
            throw LocalTranscriptionError.backendUnavailable(
                "Apple Speech does not support locale \(locale.identifier)."
            )
        }
        guard recognizer.isAvailable else {
            throw LocalTranscriptionError.backendUnavailable(
                "Apple Speech is temporarily unavailable. Try again in a moment."
            )
        }
        guard recognizer.supportsOnDeviceRecognition else {
            throw LocalTranscriptionError.backendUnavailable(
                "On-device speech recognition is not supported for locale \(locale.identifier). Download the language model in System Settings → General → Keyboard → Dictation."
            )
        }

        let request = SFSpeechURLRecognitionRequest(url: fileURL)
        request.requiresOnDeviceRecognition = true
        request.shouldReportPartialResults = false
        // Punctuation is off by default on some macOS versions; turn it
        // on so the raw transcript matches user expectations before the
        // LLM cleanup step.
        if #available(macOS 13.0, *) {
            request.addsPunctuation = true
        }

        os_log(.info, log: appleSpeechLog, "Starting Apple Speech recognition on %{public}@", fileURL.lastPathComponent)

        // Bridge the callback-based API to async/await. We only care
        // about the final result — `shouldReportPartialResults` is off
        // above, but we still guard on `isFinal` to be safe.
        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<String, Error>) in
                var didResume = false
                let lock = NSLock()

                func resumeOnce(_ result: Result<String, Error>) {
                    lock.lock(); defer { lock.unlock() }
                    guard !didResume else { return }
                    didResume = true
                    switch result {
                    case .success(let text): continuation.resume(returning: text)
                    case .failure(let error): continuation.resume(throwing: error)
                    }
                }

                let task = recognizer.recognitionTask(with: request) { recognition, error in
                    if let error = error {
                        // No-speech errors are common on ambient audio;
                        // report them as empty transcripts instead of
                        // propagating so the UI stays quiet.
                        let ns = error as NSError
                        if ns.domain == "kAFAssistantErrorDomain" && (ns.code == 1110 || ns.code == 203) {
                            resumeOnce(.success(""))
                            return
                        }
                        resumeOnce(.failure(LocalTranscriptionError.recognitionFailed(
                            "Apple Speech error: \(error.localizedDescription)"
                        )))
                        return
                    }
                    if let recognition = recognition, recognition.isFinal {
                        let text = recognition.bestTranscription.formattedString
                        resumeOnce(.success(text))
                    }
                }

                // Store the task so cancellation from outside can reach it.
                Self.storedTask = task
            }
        } onCancel: {
            Self.storedTask?.cancel()
        }
    }

    /// Weak reference to the in-flight recognition task so
    /// `onCancel` can reach it. There's only ever one Apple Speech
    /// recognition in flight per user gesture, so a single static
    /// slot is safe.
    nonisolated(unsafe) private static var storedTask: SFSpeechRecognitionTask?
}
