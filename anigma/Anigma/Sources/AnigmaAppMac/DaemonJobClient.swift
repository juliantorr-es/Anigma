//
//  DaemonJobClient.swift
//  AnigmaAppMac
//
//  Client for submitting develop jobs to the daemon.
//

import Foundation

struct DaemonJob: Identifiable, Codable, Hashable {
    let id: String
    let action: String
    let status: String
    let createdAt: Date
    let detail: String?
    let correlationID: String?
}

struct DaemonJobRequest: Codable {
    let action: String
    let repoPath: String
    let filePath: String
    let instruction: String
}

actor DaemonJobClient {
    private let baseURL: URL

    init(baseURL: URL = URL(string: "http://127.0.0.1:8080")!) {
        self.baseURL = baseURL
    }

    func submitRefactorJob(repoURL: URL, fileURL: URL, instruction: String) async throws -> DaemonJob {
        let requestPayload = DaemonJobRequest(
            action: "agent_refactor",
            repoPath: repoURL.path,
            filePath: fileURL.path,
            instruction: instruction
        )
        return try await submitJob(payload: requestPayload)
    }

    func fetchJobs() async throws -> [DaemonJob] {
        let url = baseURL.appendingPathComponent("jobs")
        var request = URLRequest(url: url)
        request.httpMethod = "GET"

        let (data, response) = try await URLSession.shared.data(for: request)
        try validateResponse(response)
        return try JSONDecoder().decode([DaemonJob].self, from: data)
    }

    private func submitJob(payload: DaemonJobRequest) async throws -> DaemonJob {
        let url = baseURL.appendingPathComponent("jobs")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(payload)

        let (data, response) = try await URLSession.shared.data(for: request)
        try validateResponse(response)
        return try JSONDecoder().decode(DaemonJob.self, from: data)
    }

    private func validateResponse(_ response: URLResponse) throws {
        guard let httpResponse = response as? HTTPURLResponse else { return }
        guard (200..<300).contains(httpResponse.statusCode) else {
            throw URLError(.badServerResponse)
        }
    }
}
