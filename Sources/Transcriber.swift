import Foundation

/// Adopted by everything that can turn an audio file on disk into a
/// transcript string. Both the remote HTTP service and the local
/// backends (Apple Speech, whisper.cpp) implement this so
/// `resolveRawTranscript` in AppState can treat them uniformly.
protocol Transcriber {
    func transcribe(fileURL: URL) async throws -> String
}

/// Errors surfaced by the local (non-HTTP) transcribers. Mirrors the
/// shape of `TranscriptionError` so the UI can present them the same
/// way.
enum LocalTranscriptionError: LocalizedError {
    case backendUnavailable(String)
    case recognitionFailed(String)
    case modelMissing(String)
    case binaryMissing(String)

    var errorDescription: String? {
        switch self {
        case .backendUnavailable(let msg): return msg
        case .recognitionFailed(let msg):  return msg
        case .modelMissing(let msg):        return msg
        case .binaryMissing(let msg):       return msg
        }
    }
}

// MARK: - TranscriptionService adoption

extension TranscriptionService: Transcriber {}
