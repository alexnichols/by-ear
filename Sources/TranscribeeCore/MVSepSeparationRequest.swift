import Foundation

public struct MVSepSeparationRequest: Equatable, Sendable {
    public static let createEndpoint = URL(string: "https://mvsep.com/api/separation/create")!

    public let endpoint: URL
    public let formFields: [String: String]

    public static func digitalPiano(apiToken: String) -> MVSepSeparationRequest {
        MVSepSeparationRequest(
            endpoint: createEndpoint,
            formFields: [
                "api_token": apiToken,
                "sep_type": "79",
                "add_opt2": "0",
                "output_format": "1",
                "is_demo": "0"
            ]
        )
    }
}
