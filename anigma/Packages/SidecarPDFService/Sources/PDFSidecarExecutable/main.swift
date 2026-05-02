import Darwin
import Foundation
import PDFSidecarClient
import SidecarPDFService

private let maxRequestBytes = 64 * 1024 * 1024
private let maxMemoryBytes: UInt64 = 512 * 1024 * 1024
private let timeoutSeconds: Double = 30
private let startedAt = Date()

private func socketPath(from arguments: [String]) -> String {
    if let index = arguments.firstIndex(of: "--socket"), arguments.indices.contains(index + 1) {
        return arguments[index + 1]
    }
    return NSTemporaryDirectory().appending("anigma-pdf-sidecar.sock")
}

private func installBudgets() {
    var memoryLimit = rlimit(rlim_cur: rlim_t(maxMemoryBytes), rlim_max: rlim_t(maxMemoryBytes))
    setrlimit(RLIMIT_AS, &memoryLimit)
    var cpuLimit = rlimit(rlim_cur: rlim_t(UInt64(timeoutSeconds)), rlim_max: rlim_t(UInt64(timeoutSeconds + 5)))
    setrlimit(RLIMIT_CPU, &cpuLimit)
}

private func stableHash(_ data: Data) -> String {
    var hash: UInt64 = 0xcbf29ce484222325
    for byte in data {
        hash ^= UInt64(byte)
        hash &*= 0x100000001b3
    }
    return String(format: "fnv1a64:%016llx", hash)
}

private func operationName(_ operation: PDFSidecarOperation) -> String {
    switch operation {
    case .rasterize: return "rasterize"
    case .extract: return "extract"
    case .split: return "split"
    case .merge: return "merge"
    case .health: return "health"
    }
}

private func receipt(
    for request: PDFSidecarRequest,
    started: Date,
    outputHash: String?
) -> ToolchainReceipt {
    ToolchainReceipt(
        processID: getpid(),
        requestID: request.requestID,
        operation: operationName(request.operation),
        inputHash: request.inputHash,
        outputHash: outputHash,
        startedAt: started,
        finishedAt: Date(),
        maxMemoryBytes: maxMemoryBytes,
        timeoutSeconds: timeoutSeconds
    )
}

private func decodePDF(_ encoded: String?) throws -> Data {
    guard let encoded, let data = Data(base64Encoded: encoded) else {
        throw PDFServiceError.invalidInput("PDF payload missing from IPC request")
    }
    return data
}

private func handle(_ request: PDFSidecarRequest, service: NativePDFService) -> PDFSidecarResponse {
    let requestStart = Date()
    do {
        switch request.operation {
        case .health:
            let payload = PDFSidecarPayload.healthResult(
                HealthResult(
                    processID: getpid(),
                    uptimeSeconds: Date().timeIntervalSince(startedAt),
                    isReady: true
                )
            )
            return PDFSidecarResponse(
                requestID: request.requestID,
                status: .success,
                payload: payload,
                receipt: receipt(for: request, started: requestStart, outputHash: nil)
            )
        case .rasterize(let rasterize):
            let pdf = try decodePDF(rasterize.pdfDataBase64)
            let page = try service.rasterize(pdf: pdf, page: rasterize.pageIndex, dpi: rasterize.dpi)
            let outputHash = stableHash(page.pixelData)
            let payload = PDFSidecarPayload.rasterizeResult(
                RasterizeResult(
                    width: page.width,
                    height: page.height,
                    stride: page.stride,
                    pixelDataBase64: page.pixelData.base64EncodedString(),
                    resultHash: outputHash
                )
            )
            return PDFSidecarResponse(
                requestID: request.requestID,
                status: .success,
                payload: payload,
                receipt: receipt(for: request, started: requestStart, outputHash: outputHash)
            )
        case .extract(let extract):
            let pdf = try decodePDF(extract.pdfDataBase64)
            let output = try service.extract(pdf: pdf, pages: extract.pages)
            let outputHash = stableHash(output)
            return PDFSidecarResponse(
                requestID: request.requestID,
                status: .success,
                payload: .extractResult(
                    ExtractResult(pdfDataBase64: output.base64EncodedString(), resultHash: outputHash)
                ),
                receipt: receipt(for: request, started: requestStart, outputHash: outputHash)
            )
        case .split(let split):
            let pdf = try decodePDF(split.pdfDataBase64)
            let output = try service.split(pdf: pdf, at: split.pageIndex)
            return PDFSidecarResponse(
                requestID: request.requestID,
                status: .success,
                payload: .splitResult(
                    SplitResult(
                        beforeBase64: output.0.base64EncodedString(),
                        afterBase64: output.1.base64EncodedString(),
                        beforeHash: stableHash(output.0),
                        afterHash: stableHash(output.1)
                    )
                ),
                receipt: receipt(for: request, started: requestStart, outputHash: nil)
            )
        case .merge(let merge):
            let pdfs = try merge.pdfDataBase64?.map { try decodePDF($0) } ?? []
            let output = try service.merge(pdfs: pdfs)
            let outputHash = stableHash(output)
            return PDFSidecarResponse(
                requestID: request.requestID,
                status: .success,
                payload: .mergeResult(
                    MergeResult(pdfDataBase64: output.base64EncodedString(), resultHash: outputHash)
                ),
                receipt: receipt(for: request, started: requestStart, outputHash: outputHash)
            )
        }
    } catch let error as PDFServiceError {
        let status: ResponseStatus
        switch error {
        case .documentCorrupted:
            status = .documentCorrupted
        case .pageNotFound:
            status = .pageNotFound
        case .outOfMemory:
            status = .outOfMemory
        default:
            status = .internalError
        }
        return PDFSidecarResponse(
            requestID: request.requestID,
            status: status,
            receipt: receipt(for: request, started: requestStart, outputHash: nil)
        )
    } catch {
        return PDFSidecarResponse(
            requestID: request.requestID,
            status: .internalError,
            receipt: receipt(for: request, started: requestStart, outputHash: nil)
        )
    }
}

private func readExact(_ fd: Int32, count: Int) -> Data? {
    var data = Data(count: count)
    let readCount = data.withUnsafeMutableBytes { buffer in
        Darwin.read(fd, buffer.baseAddress!, count)
    }
    guard readCount == count else { return nil }
    return data
}

private func writeAll(_ fd: Int32, data: Data) {
    data.withUnsafeBytes { buffer in
        _ = Darwin.write(fd, buffer.baseAddress!, buffer.count)
    }
}

private func serve(socketPath: String) throws -> Never {
    try? FileManager.default.removeItem(atPath: socketPath)
    let server = socket(AF_UNIX, SOCK_STREAM, 0)
    guard server >= 0 else { fatalError("socket failed: \(errno)") }

    var addr = sockaddr_un()
    addr.sun_family = sa_family_t(AF_UNIX)
    let pathBytes = socketPath.utf8CString
    _ = withUnsafeMutableBytes(of: &addr.sun_path) { buffer in
        pathBytes.withUnsafeBytes { path in
            memcpy(buffer.baseAddress!, path.baseAddress!, min(path.count, buffer.count))
        }
    }

    let bindResult = withUnsafeBytes(of: &addr) { raw in
        Darwin.bind(
            server,
            raw.baseAddress!.assumingMemoryBound(to: sockaddr.self),
            socklen_t(MemoryLayout<sockaddr_un>.size)
        )
    }
    guard bindResult == 0 else { fatalError("bind failed: \(errno)") }
    guard listen(server, 16) == 0 else { fatalError("listen failed: \(errno)") }

    let service = NativePDFService()
    while true {
        let client = accept(server, nil, nil)
        guard client >= 0 else { continue }
        defer { Darwin.close(client) }

        guard let lengthData = readExact(client, count: 4) else { continue }
        let length = lengthData.withUnsafeBytes { raw -> UInt32 in
            raw.load(as: UInt32.self).bigEndian
        }
        guard length > 0, length <= maxRequestBytes else { continue }
        guard let requestData = readExact(client, count: Int(length)) else { continue }

        let response: PDFSidecarResponse
        do {
            response = handle(try PDFSidecarRequest.fromJSON(requestData), service: service)
        } catch {
            response = PDFSidecarResponse(requestID: "unknown", status: .invalidRequest)
        }

        guard let responseData = try? response.toJSON() else { continue }
        var responseLength = UInt32(responseData.count).bigEndian
        writeAll(client, data: Data(bytes: &responseLength, count: 4))
        writeAll(client, data: responseData)
    }
}

installBudgets()
try serve(socketPath: socketPath(from: CommandLine.arguments))
