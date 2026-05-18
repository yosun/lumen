import XCTest

@testable import Napkinmatic_Offline

#if canImport(LiteRTLM)
import LiteRTLM
#endif

final class LiteRTLMIntegrationTests: XCTestCase {
    func testBundledGemmaModelIsPresent() async throws {
        let manager = ModelManager()
        let url = try await manager.validateModelAvailable()

        XCTAssertEqual(url.lastPathComponent, "gemma-4-E2B-it.litertlm")
        XCTAssertTrue(FileManager.default.fileExists(atPath: url.path))
    }

    func testLiteRTLMCanOpenBundledModelCapabilities() async throws {
        #if canImport(LiteRTLM)
        let manager = ModelManager()
        let url = try await manager.validateModelAvailable()

        let capabilities = Capabilities(modelPath: url.path)
        XCTAssertNotNil(capabilities, "LiteRT-LM could not open the bundled .litertlm model file.")
        _ = capabilities?.hasSpeculativeDecodingSupport()
        #else
        XCTFail("LiteRTLM package is not linked.")
        #endif
    }
}
