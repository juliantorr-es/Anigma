// Copyright (c) 2025 Anigma
// Licensed under the MIT License

import XCTest
import Foundation

/// Integration tests for Anigma CLI tool workflows
/// Tests end-to-end CLI command execution and output parsing
final class CLIWorkflowIntegrationTests: XCTestCase {
    
    let cliExecutablePath = "AnigmaCLIExecutable"
    let timeout: TimeInterval = 10.0
    
    // MARK: - Helper Methods
    
    private func runCLICommand(_ args: [String]) -> (exitCode: Int32, stdout: String, stderr: String) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: cliExecutablePath)
        process.arguments = args
        
        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe
        
        var exitCode: Int32 = 0
        
        do {
            try process.run()
            
            // Set timeout
            let deadline = Date().addingTimeInterval(timeout)
            while process.isRunning && Date() < deadline {
                usleep(100_000)  // 100ms
            }
            
            if process.isRunning {
                process.terminate()
            }
            
            process.waitUntilExit()
            exitCode = process.terminationStatus
        } catch {
            XCTFail("Failed to run CLI command: \(error)")
            return (1, "", "Failed to run process")
        }
        
        let stdoutData = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
        let stderrData = stderrPipe.fileHandleForReading.readDataToEndOfFile()
        
        let stdout = String(data: stdoutData, encoding: .utf8) ?? ""
        let stderr = String(data: stderrData, encoding: .utf8) ?? ""
        
        return (exitCode, stdout, stderr)
    }
    
    // MARK: - Basic Command Tests
    
    func testCLIHelpCommand() {
        let result = runCLICommand(["--help"])
        
        XCTAssertEqual(result.exitCode, 0)
        XCTAssertTrue(result.stdout.contains("usage") || result.stdout.contains("Usage"))
    }
    
    func testCLIVersionCommand() {
        let result = runCLICommand(["--version"])
        
        XCTAssertEqual(result.exitCode, 0)
        XCTAssertTrue(result.stdout.contains("1.0") || result.stdout.contains("version"))
    }
    
    func testCLIInvalidCommand() {
        let result = runCLICommand(["invalid-command"])
        
        XCTAssertNotEqual(result.exitCode, 0)
        XCTAssertTrue(result.stderr.contains("unknown") || result.stderr.contains("not found") || result.stdout.contains("unknown"))
    }
    
    // MARK: - Job Submission Tests
    
    func testSubmitRefactoringJob() {
        let swiftCode = """
        func calculateSum(_ numbers: [Int]) -> Int {
            var result = 0
            for number in numbers {
                result = result + number
            }
            return result
        }
        """
        
        // Create temporary file
        let tempFile = NSTemporaryDirectory() + "test_code.swift"
        
        do {
            try swiftCode.write(toFile: tempFile, atomically: true, encoding: .utf8)
            defer { try? FileManager.default.removeItem(atPath: tempFile) }
            
            let result = runCLICommand(["refactor", tempFile])
            
            XCTAssertEqual(result.exitCode, 0, "Refactoring failed: \(result.stderr)")
            XCTAssertTrue(result.stdout.contains("refactored") || result.stdout.contains("job") || !result.stdout.isEmpty)
        } catch {
            XCTFail("Failed to create test file: \(error)")
        }
    }
    
    func testAnalyzeCodeFile() {
        let swiftCode = """
        func add(_ a: Int, _ b: Int) -> Int {
            return a + b
        }
        """
        
        let tempFile = NSTemporaryDirectory() + "test_analyze.swift"
        
        do {
            try swiftCode.write(toFile: tempFile, atomically: true, encoding: .utf8)
            defer { try? FileManager.default.removeItem(atPath: tempFile) }
            
            let result = runCLICommand(["analyze", tempFile])
            
            XCTAssertEqual(result.exitCode, 0, "Analysis failed: \(result.stderr)")
            XCTAssertFalse(result.stdout.isEmpty)
        } catch {
            XCTFail("Failed to create test file: \(error)")
        }
    }
    
    func testOptimizeCodeFile() {
        let swiftCode = """
        let x = 1 + 2 + 3 + 4
        let y = x * 2
        print(y)
        """
        
        let tempFile = NSTemporaryDirectory() + "test_optimize.swift"
        
        do {
            try swiftCode.write(toFile: tempFile, atomically: true, encoding: .utf8)
            defer { try? FileManager.default.removeItem(atPath: tempFile) }
            
            let result = runCLICommand(["optimize", tempFile])
            
            XCTAssertEqual(result.exitCode, 0, "Optimization failed: \(result.stderr)")
        } catch {
            XCTFail("Failed to create test file: \(error)")
        }
    }
    
    // MARK: - Job Status Tests
    
    func testGetJobStatus() {
        let jobId = "test-job-id-12345"
        let result = runCLICommand(["status", jobId])
        
        // Depending on whether job exists, should return valid status code
        XCTAssertTrue(result.exitCode == 0 || result.exitCode == 1)
    }
    
    func testListJobs() {
        let result = runCLICommand(["list"])
        
        XCTAssertEqual(result.exitCode, 0)
        // Output should be JSON or table format
        XCTAssertFalse(result.stdout.isEmpty)
    }
    
    func testListJobsWithFilter() {
        let result = runCLICommand(["list", "--status=completed"])
        
        XCTAssertEqual(result.exitCode, 0)
        XCTAssertFalse(result.stdout.isEmpty)
    }
    
    // MARK: - Configuration Tests
    
    func testConfigCommand() {
        let result = runCLICommand(["config", "--show"])
        
        XCTAssertEqual(result.exitCode, 0)
        XCTAssertFalse(result.stdout.isEmpty)
    }
    
    func testSetConfig() {
        let result = runCLICommand(["config", "set", "verbosity", "debug"])
        
        XCTAssertTrue(result.exitCode == 0 || result.exitCode == 1)
    }
    
    // MARK: - Daemon Control Tests
    
    func testDaemonStartCommand() {
        let result = runCLICommand(["daemon", "start"])
        
        // May already be running, so accept both 0 and 1
        XCTAssertTrue(result.exitCode == 0 || result.exitCode == 1)
    }
    
    func testDaemonStatusCommand() {
        let result = runCLICommand(["daemon", "status"])
        
        XCTAssertEqual(result.exitCode, 0)
        XCTAssertTrue(result.stdout.contains("running") || result.stdout.contains("status") || !result.stdout.isEmpty)
    }
    
    func testDaemonLogsCommand() {
        let result = runCLICommand(["daemon", "logs", "--lines=10"])
        
        XCTAssertEqual(result.exitCode, 0)
        // Logs may be empty on fresh start
        XCTAssertFalse(result.stderr.contains("error") || result.stderr.contains("not found"))
    }
    
    // MARK: - File Input Tests
    
    func testProcessMultipleFiles() {
        let tempDir = NSTemporaryDirectory() + "anigma_test_\(UUID().uuidString)/"
        
        do {
            try FileManager.default.createDirectory(atPath: tempDir, withIntermediateDirectories: true)
            defer { try? FileManager.default.removeItem(atPath: tempDir) }
            
            // Create test files
            for i in 0..<3 {
                let content = "func test\(i)() { return \(i) }"
                let path = tempDir + "test\(i).swift"
                try content.write(toFile: path, atomically: true, encoding: .utf8)
            }
            
            let result = runCLICommand(["batch", tempDir])
            
            XCTAssertEqual(result.exitCode, 0, "Batch processing failed: \(result.stderr)")
        } catch {
            XCTFail("Failed to set up test directory: \(error)")
        }
    }
    
    // MARK: - Output Format Tests
    
    func testJSONOutputFormat() {
        let result = runCLICommand(["list", "--format=json"])
        
        XCTAssertEqual(result.exitCode, 0)
        
        // Try to parse as JSON
        if let data = result.stdout.data(using: .utf8) {
            do {
                _ = try JSONSerialization.jsonObject(with: data)
                // Successfully parsed JSON
            } catch {
                XCTFail("Output is not valid JSON: \(result.stdout)")
            }
        }
    }
    
    func testTableOutputFormat() {
        let result = runCLICommand(["list", "--format=table"])
        
        XCTAssertEqual(result.exitCode, 0)
        XCTAssertTrue(result.stdout.contains("|") || result.stdout.contains("-"))
    }
    
    // MARK: - Error Handling Tests
    
    func testNonexistentFile() {
        let result = runCLICommand(["analyze", "/nonexistent/file.swift"])
        
        XCTAssertNotEqual(result.exitCode, 0)
        XCTAssertTrue(result.stderr.contains("not found") || result.stderr.contains("No such"))
    }
    
    func testInvalidJobId() {
        let result = runCLICommand(["status", "invalid-job-id"])
        
        XCTAssertNotEqual(result.exitCode, 0)
    }
    
    func testMissingRequiredArgument() {
        let result = runCLICommand(["refactor"])  // Missing file argument
        
        XCTAssertNotEqual(result.exitCode, 0)
        XCTAssertTrue(result.stderr.contains("required") || result.stderr.contains("argument"))
    }
    
    // MARK: - Concurrency Tests
    
    func testConcurrentCLICommands() {
        let commandCount = 5
        let expectation = XCTestExpectation(description: "All CLI commands complete")
        expectation.expectedFulfillmentCount = commandCount
        
        for i in 0..<commandCount {
            DispatchQueue.global().async {
                let result = self.runCLICommand(["list"])
                XCTAssertEqual(result.exitCode, 0, "Command \(i) failed")
                expectation.fulfill()
            }
        }
        
        wait(for: [expectation], timeout: timeout * 2)
    }
    
    // MARK: - Integration Scenario Tests
    
    func testCompleteWorkflow() {
        // 1. Create a test file
        let swiftCode = "func main() { print(\"Hello\") }"
        let tempFile = NSTemporaryDirectory() + "workflow_test.swift"
        
        do {
            try swiftCode.write(toFile: tempFile, atomically: true, encoding: .utf8)
            defer { try? FileManager.default.removeItem(atPath: tempFile) }
            
            // 2. Submit for analysis
            let analyzeResult = runCLICommand(["analyze", tempFile])
            XCTAssertEqual(analyzeResult.exitCode, 0, "Analysis failed")
            
            // 3. Submit for refactoring
            let refactorResult = runCLICommand(["refactor", tempFile])
            XCTAssertEqual(refactorResult.exitCode, 0, "Refactoring failed")
            
            // 4. Check job list
            let listResult = runCLICommand(["list"])
            XCTAssertEqual(listResult.exitCode, 0, "List failed")
            
        } catch {
            XCTFail("Workflow test failed: \(error)")
        }
    }
}
