import CoreGraphics
import Foundation

enum ModelStorageMode: String, CaseIterable, Identifiable {
    case bundled
    case downloadedLocalAsset

    var id: String { rawValue }
}

enum InferenceBackend: String {
    case cpu
    case gpu
}

struct ModelConfiguration {
    var modelDisplayName = "Gemma 4 E2B"
    var modelRepository = "litert-community/gemma-4-E2B-it-litert-lm"
    var modelFilename = "gemma-4-E2B-it"
    var modelFileExtension = "litertlm"
    var storageMode: ModelStorageMode = .bundled
    var preferredBackend: InferenceBackend = .gpu
    var visionBackend: InferenceBackend = .gpu
    var maxNumTokens = 4096
    var topK = 64
    var topP: Float = 0.95
    var temperature: Float = 1.0
    var maxImageDimension: CGFloat = 1024
    var minimumMemoryGB: UInt64 = 8
    var enableSpeculativeDecoding = false
    var visualTokenBudget: Int32? = 280

    var modelFileNameWithExtension: String {
        "\(modelFilename).\(modelFileExtension)"
    }
}

enum ModelManagerError: LocalizedError, Equatable {
    case modelMissing(expectedFileName: String, searchedPath: String)
    case applicationSupportUnavailable

    var errorDescription: String? {
        switch self {
        case .modelMissing(let expectedFileName, let searchedPath):
            return "Missing local model asset: \(expectedFileName). Looked in \(searchedPath)."
        case .applicationSupportUnavailable:
            return "Could not resolve the app's Application Support directory."
        }
    }
}

actor ModelManager {
    let configuration: ModelConfiguration

    init(configuration: ModelConfiguration = ModelConfiguration()) {
        self.configuration = configuration
    }

    func localModelURL() throws -> URL {
        switch configuration.storageMode {
        case .bundled:
            return try bundledModelURL()
        case .downloadedLocalAsset:
            return try downloadedModelURL()
        }
    }

    func validateModelAvailable() throws -> URL {
        let url = try localModelURL()
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw ModelManagerError.modelMissing(
                expectedFileName: configuration.modelFileNameWithExtension,
                searchedPath: url.path
            )
        }
        return url
    }

    func validateDeviceBudget() throws {
        // RAM check is now informational only; see `deviceMemoryWarning()`.
        // Kept as a no-op so older call sites continue to compile.
    }

    /// Returns a human-readable warning if the device has less RAM than the
    /// configured recommendation. Returns `nil` if the device meets the
    /// recommended threshold. This is intentionally non-throwing so the UI can
    /// surface it as a banner rather than block model loading.
    func deviceMemoryWarning() -> String? {
        let detectedGB = ProcessInfo.processInfo.physicalMemory / 1_073_741_824
        guard detectedGB < configuration.minimumMemoryGB else {
            return nil
        }
        return "This device reports \(detectedGB) GB of RAM. \(configuration.modelDisplayName) is recommended for devices with at least \(configuration.minimumMemoryGB) GB. The model may still load but could run out of memory."
    }

    func detectedMemoryGB() -> UInt64 {
        ProcessInfo.processInfo.physicalMemory / 1_073_741_824
    }

    func downloadedModelsDirectory() throws -> URL {
        guard let supportURL = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first else {
            throw ModelManagerError.applicationSupportUnavailable
        }

        return supportURL
            .appendingPathComponent("NapkinmaticOffline", isDirectory: true)
            .appendingPathComponent("Models", isDirectory: true)
    }

    private func bundledModelURL() throws -> URL {
        if let url = Bundle.main.url(
            forResource: configuration.modelFilename,
            withExtension: configuration.modelFileExtension
        ) {
            return url
        }

        for subdirectory in ["ModelPlaceholder", "Resources", "Resources/ModelPlaceholder"] {
            if let url = Bundle.main.url(
                forResource: configuration.modelFilename,
                withExtension: configuration.modelFileExtension,
                subdirectory: subdirectory
            ) {
                return url
            }
        }

        throw ModelManagerError.modelMissing(
            expectedFileName: configuration.modelFileNameWithExtension,
            searchedPath: "main app bundle and bundled resource subdirectories"
        )
    }

    private func downloadedModelURL() throws -> URL {
        try downloadedModelsDirectory()
            .appendingPathComponent(configuration.modelFileNameWithExtension)
    }
}
