import Foundation

private actor ValidationRequestRecorder {
    private(set) var requests: [URLRequest] = []

    func append(_ request: URLRequest) {
        requests.append(request)
    }
}

enum TranscriptionServiceTests {
    @MainActor
    static func run() async {
        let recorder = ValidationRequestRecorder()
        let savedCredential = "saved-old-credential"
        let draftCredential = "validated-draft-credential"
        var persistedCredential = savedCredential
        var persistedBaseURL = "https://saved-provider.invalid/v1"
        var applyCount = 0
        let valid = await APIConfigurationSaveFlow.validateAndApply(
            apiKey: draftCredential,
            baseURL: "https://draft-provider.invalid/v1",
            validator: { key, baseURL in
                await TranscriptionService.validateAPIKey(key, baseURL: baseURL) { request in
                    await recorder.append(request)
                    let response = HTTPURLResponse(
                        url: request.url!,
                        statusCode: 401,
                        httpVersion: nil,
                        headerFields: nil
                    )!
                    return (Data(), response)
                }
            }
        ) { configuration in
            applyCount += 1
            persistedCredential = configuration.apiKey
            persistedBaseURL = configuration.baseURL
        }
        let requests = await recorder.requests
        TestSupport.expect(!valid && requests.count == 1, "Failed draft API configuration performs one mocked validation request")
        TestSupport.expect(requests.first?.url?.absoluteString == "https://draft-provider.invalid/v1/models", "Draft endpoint is validated before it is saved")
        let authorization = requests.first?.value(forHTTPHeaderField: "Authorization")
        TestSupport.expect(authorization == "Bearer \(draftCredential)", "Draft endpoint receives only its validated credential")
        TestSupport.expect(authorization != "Bearer \(savedCredential)", "Saved credential never reaches the draft endpoint")
        TestSupport.expect(applyCount == 0, "Failed validation does not cross the shared draft-to-persisted boundary")
        TestSupport.expect(persistedCredential == savedCredential && persistedBaseURL == "https://saved-provider.invalid/v1", "Failed validation preserves the existing API configuration")
    }
}
