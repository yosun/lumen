import Foundation

/// Temporarily redirects the process-wide stderr file descriptor into a pipe
/// while the supplied async closure runs, then restores stderr and returns
/// whatever was written.
///
/// This is the only way to surface the C++ LiteRT-LM diagnostics that the
/// runtime prints to stderr from `litert_lm_engine_create` failures: the C
/// API does not return an error string, only NULL.
enum StderrCapture {
    /// Captures everything written to stderr during the execution of `body`.
    ///
    /// - Parameter body: Async closure to execute. Any thrown errors are
    ///   propagated to the caller.
    /// - Returns: The captured stderr text. May be empty.
    static func capture(_ body: () async -> Void) async -> String {
        let originalFD = dup(fileno(stderr))
        guard originalFD != -1 else {
            await body()
            return ""
        }

        var pipeFDs: [Int32] = [-1, -1]
        let pipeResult = pipeFDs.withUnsafeMutableBufferPointer { buffer in
            pipe(buffer.baseAddress!)
        }
        if pipeResult != 0 {
            close(originalFD)
            await body()
            return ""
        }
        let readEnd = pipeFDs[0]
        let writeEnd = pipeFDs[1]

        // Make the read end non-blocking so we can drain it without hanging.
        let flags = fcntl(readEnd, F_GETFL, 0)
        _ = fcntl(readEnd, F_SETFL, flags | O_NONBLOCK)

        // Redirect stderr (fd 2) to the pipe write end.
        setvbuf(stderr, nil, _IONBF, 0)
        _ = dup2(writeEnd, fileno(stderr))
        close(writeEnd)

        await body()

        // Restore stderr.
        fflush(stderr)
        _ = dup2(originalFD, fileno(stderr))
        close(originalFD)

        // Drain the pipe.
        var captured = Data()
        var buffer = [UInt8](repeating: 0, count: 4096)
        while true {
            let n = read(readEnd, &buffer, buffer.count)
            if n > 0 {
                captured.append(buffer, count: n)
            } else {
                break
            }
        }
        close(readEnd)

        return String(data: captured, encoding: .utf8) ?? ""
    }
}
