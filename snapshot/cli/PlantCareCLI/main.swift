import Foundation
import PlantCareCore

enum CLIError: LocalizedError {
    case usage

    var errorDescription: String? {
        switch self {
        case .usage:
            return "Usage: plantcare-cli identify <image-path> --api-key <key>"
        }
    }
}

func run() async throws {
    let arguments = CommandLine.arguments

    guard arguments.count == 5,
          arguments[1] == "identify",
          arguments[3] == "--api-key" else {
        throw CLIError.usage
    }

    let imageData = try Data(contentsOf: URL(fileURLWithPath: arguments[2]))
    let answer = try await OpenAIService().identifyPlant(
        from: imageData,
        apiKey: arguments[4]
    )
    print(answer)
}

do {
    try await run()
} catch {
    FileHandle.standardError.write(Data("Error: \(error.localizedDescription)\n".utf8))
    exit(EXIT_FAILURE)
}
