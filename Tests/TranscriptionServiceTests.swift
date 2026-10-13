import Foundation

private actor ValidationRequestRecorder {
    private(set) var requests: [URLRequest] = []

    func append(_ request: URLRequest) {
        requests.append(request)
    }
}

enum TranscriptionServiceTests {
    static func run() async {
        let recorder = ValidationRequestRecorder()
        let savedCredential = "saved-old-credential"
        let draftCredential = "validated-draft-credential"
        let valid = await TranscriptionService.validateAPIKey(
            draftCredential,
            baseURL: "https://draft-provider.invalid/v1"
        ) { request in
            await recorder.append(request)
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: nil
            )!
            return (Data(), response)
        }
        let requests = await recorder.requests
        TestSupport.expect(valid && requests.count == 1, "Draft API configuration performs one mocked validation request")
        TestSupport.expect(requests.first?.url?.absoluteString == "https://draft-provider.invalid/v1/models", "Draft endpoint is validated before it is saved")
        let authorization = requests.first?.value(forHTTPHeaderField: "Authorization")
        TestSupport.expect(authorization == "Bearer \(draftCredential)", "Draft endpoint receives only its validated credential")
        TestSupport.expect(authorization != "Bearer \(savedCredential)", "Saved credential never reaches the draft endpoint")
    }
}
