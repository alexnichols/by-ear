import Foundation

public struct MLXStemSpec: Equatable, Identifiable, Sendable {
    public let stem: PracticeStem
    public let modelFilename: String
    public let targetStem: String
    public let outputBaseName: String

    public var id: PracticeStem {
        stem
    }

    public var expectedFileName: String {
        "\(outputBaseName).wav"
    }

    public var customOutputNamesJSON: String {
        #"{"\#(targetStem)":"\#(outputBaseName)"}"#
    }

    public static let piano = MLXStemSpec(
        stem: .piano,
        modelFilename: "BS-Roformer-SW.ckpt",
        targetStem: "Piano",
        outputBaseName: "piano"
    )

    public static let vocals = MLXStemSpec(
        stem: .vocals,
        modelFilename: "vocals_mel_band_roformer.ckpt",
        targetStem: "vocals",
        outputBaseName: "vocals"
    )

    public static let bass = MLXStemSpec(
        stem: .bass,
        modelFilename: "kuielab_a_bass.onnx",
        targetStem: "bass",
        outputBaseName: "bass"
    )

    public static let drums = MLXStemSpec(
        stem: .drums,
        modelFilename: "kuielab_b_drums.onnx",
        targetStem: "drums",
        outputBaseName: "drums"
    )

    public static let practiceSpecs: [MLXStemSpec] = [
        .piano,
        .vocals,
        .bass,
        .drums
    ]
}
