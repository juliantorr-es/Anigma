// SyntaxCapsuleTests.swift
// Tests for SyntaxCapsule functionality

import Foundation
import XCTest
@testable import SyntaxCapsule
import CapsuleCore
import TelemetryCore

final class SyntaxCapsuleTests: XCTestCase {
    
    var capsule: SyntaxCapsule!
    var diagnostics: MockDiagnostics!
    
    override func setUp() async throws {
        try await super.setUp()
        diagnostics = MockDiagnostics()
        capsule = SyntaxCapsule(diagnostics: diagnostics)
    }
    
    override func tearDown() async throws {
        capsule = nil
        diagnostics = nil
        try await super.tearDown()
    }
    
    // MARK: - Language Detection Tests
    
    func testDetectSwiftLanguage() async throws {
        let swiftCode = """
        import Foundation
        
        class HelloWorld {
            func greet(name: String) -> String {
                return "Hello, \\(name)!"
            }
        }
        """
        
        let detectedLanguage = try await capsule.detectLanguage(swiftCode)
        XCTAssertEqual(detectedLanguage, .swift)
    }
    
    func testDetectPythonLanguage() async throws {
        let pythonCode = """
        import os
        
        class HelloWorld:
            def greet(self, name: str) -> str:
                return f"Hello, {name}!"
        
        if __name__ == "__main__":
            hw = HelloWorld()
            print(hw.greet("World"))
        """
        
        let detectedLanguage = try await capsule.detectLanguage(pythonCode)
        XCTAssertEqual(detectedLanguage, .python)
    }
    
    func testDetectCppLanguage() async throws {
        let cppCode = """
        #include <iostream>
        #include <string>
        
        class HelloWorld {
        public:
            std::string greet(const std::string& name) {
                return "Hello, " + name + "!";
            }
        };
        
        int main() {
            HelloWorld hw;
            std::cout << hw.greet("World") << std::endl;
            return 0;
        }
        """
        
        let detectedLanguage = try await capsule.detectLanguage(cppCode)
        XCTAssertEqual(detectedLanguage, .cpp)
    }
    
    func testDetectRustLanguage() async throws {
        let rustCode = """
        use std::fmt;
        
        struct HelloWorld;
        
        impl HelloWorld {
            fn greet(name: &str) -> String {
                format!("Hello, {}!", name)
            }
        }
        
        fn main() {
            println!("{}", HelloWorld::greet("World"));
        }
        """
        
        let detectedLanguage = try await capsule.detectLanguage(rustCode)
        XCTAssertEqual(detectedLanguage, .rust)
    }
    
    func testDetectLanguageByFilename() async throws {
        let code = "print('Hello, World!')"
        
        let detectedFromPy = try await capsule.detectLanguage(code, filenameHint: "script.py")
        XCTAssertEqual(detectedFromPy, .python)
        
        let detectedFromRs = try await capsule.detectLanguage(code, filenameHint: "script.rs")
        XCTAssertEqual(detectedFromRs, .rust)
    }
    
    // MARK: - Parsing Tests
    
    func testParseSwiftCode() async throws {
        let swiftCode = """
        import Foundation
        
        class Calculator {
            private var result: Double = 0.0
            
            func add(_ value: Double) -> Calculator {
                result += value
                return self
            }
            
            func getResult() -> Double {
                return result
            }
        }
        """
        
        let parseResult = try await capsule.parse(swiftCode, language: .swift)
        
        XCTAssertEqual(parseResult.detectedLanguage, .swift)
        XCTAssertGreaterThan(parseResult.tokens.count, 0)
        XCTAssertEqual(parseResult.metadata.inputLength, swiftCode.count)
        
        // Check for keywords
        let keywords = capsule.extractTokens(from: parseResult, ofType: .keyword)
        XCTAssertTrue(keywords.contains { $0.text == "class" })
        XCTAssertTrue(keywords.contains { $0.text == "private" })
        XCTAssertTrue(keywords.contains { $0.text == "func" })
        XCTAssertTrue(keywords.contains { $0.text == "return" })
        
        // Check for identifiers
        let identifiers = capsule.extractIdentifiers(from: parseResult)
        XCTAssertTrue(identifiers.contains("Calculator"))
        XCTAssertTrue(identifiers.contains("result"))
        XCTAssertTrue(identifiers.contains("add"))
        XCTAssertTrue(identifiers.contains("getResult"))
        
        // Check for string literals
        let strings = capsule.extractStringLiterals(from: parseResult)
        XCTAssertTrue(strings.contains("Foundation"))
    }
    
    func testParsePythonCode() async throws {
        let pythonCode = """
        import numpy as np
        
        class DataProcessor:
            def __init__(self, data: list):
                self.data = data
                self.processed = False
            
            def process(self) -> list:
                """Process the data and return results."""
                result = [x * 2 for x in self.data]
                self.processed = True
                return result
        """
        
        let parseResult = try await capsule.parse(pythonCode, language: .python)
        
        XCTAssertEqual(parseResult.detectedLanguage, .python)
        XCTAssertGreaterThan(parseResult.tokens.count, 0)
        
        // Check for keywords
        let keywords = capsule.extractTokens(from: parseResult, ofType: .keyword)
        XCTAssertTrue(keywords.contains { $0.text == "class" })
        XCTAssertTrue(keywords.contains { $0.text == "def" })
        XCTAssertTrue(keywords.contains { $0.text == "self" })
        XCTAssertTrue(keywords.contains { $0.text == "return" })
        
        // Check for comments
        let comments = capsule.extractTokens(from: parseResult, ofType: .comment)
        XCTAssertGreaterThan(comments.count, 0)
    }
    
    func testParseCppCode() async throws {
        let cppCode = """
        #include <vector>
        #include <algorithm>
        
        template<typename T>
        class Container {
        private:
            std::vector<T> items;
        
        public:
            void add(const T& item) {
                items.push_back(item);
            }
            
            size_t size() const {
                return items.size();
            }
        };
        """
        
        let parseResult = try await capsule.parse(cppCode, language: .cpp)
        
        XCTAssertEqual(parseResult.detectedLanguage, .cpp)
        XCTAssertGreaterThan(parseResult.tokens.count, 0)
        
        // Check for keywords
        let keywords = capsule.extractTokens(from: parseResult, ofType: .keyword)
        XCTAssertTrue(keywords.contains { $0.text == "template" })
        XCTAssertTrue(keywords.contains { $0.text == "class" })
        XCTAssertTrue(keywords.contains { $0.text == "private" })
        XCTAssertTrue(keywords.contains { $0.text == "public" })
        XCTAssertTrue(keywords.contains { $0.text == "const" })
    }
    
    func testParseRustCode() async throws {
        let rustCode = """
        use std::collections::HashMap;
        
        #[derive(Debug)]
        struct Cache {
            data: HashMap<String, String>,
        }
        
        impl Cache {
            pub fn new() -> Self {
                Self {
                    data: HashMap::new(),
                }
            }
            
            pub fn insert(&mut self, key: String, value: String) {
                self.data.insert(key, value);
            }
        }
        """
        
        let parseResult = try await capsule.parse(rustCode, language: .rust)
        
        XCTAssertEqual(parseResult.detectedLanguage, .rust)
        XCTAssertGreaterThan(parseResult.tokens.count, 0)
        
        // Check for keywords
        let keywords = capsule.extractTokens(from: parseResult, ofType: .keyword)
        XCTAssertTrue(keywords.contains { $0.text == "use" })
        XCTAssertTrue(keywords.contains { $0.text == "struct" })
        XCTAssertTrue(keywords.contains { $0.text == "impl" })
        XCTAssertTrue(keywords.contains { $0.text == "pub" })
        XCTAssertTrue(keywords.contains { $0.text == "mut" })
    }
    
    // MARK: - Token Extraction Tests
    
    func testExtractStringLiterals() async throws {
        let swiftCode = """
        let greeting = "Hello, World!"
        let path = '/usr/local/bin'
        let multiline = """
        This is a
        multiline string
        """
        """
        
        let parseResult = try await capsule.parse(swiftCode, language: .swift)
        let strings = capsule.extractStringLiterals(from: parseResult)
        
        XCTAssertTrue(strings.contains("Hello, World!"))
        XCTAssertTrue(strings.contains("/usr/local/bin"))
        XCTAssertTrue(strings.contains("This is a"))
    }
    
    func testExtractIdentifiers() async throws {
        let pythonCode = """
        def calculate_sum(numbers: list) -> int:
            total = 0
            for num in numbers:
                total += num
            return total
        
        result = calculate_sum([1, 2, 3, 4, 5])
        """
        
        let parseResult = try await capsule.parse(pythonCode, language: .python)
        let identifiers = capsule.extractIdentifiers(from: parseResult)
        
        let expectedIdentifiers = ["calculate_sum", "numbers", "total", "num", "result"]
        for identifier in expectedIdentifiers {
            XCTAssertTrue(identifiers.contains(identifier), "Missing identifier: \(identifier)")
        }
    }
    
    func testExtractTokensByType() async throws {
        let cppCode = """
        int main() {
            int count = 42;
            double pi = 3.14159;
            return count;
        }
        """
        
        let parseResult = try await capsule.parse(cppCode, language: .cpp)
        
        let keywords = capsule.extractTokens(from: parseResult, ofType: .keyword)
        let numbers = capsule.extractTokens(from: parseResult, ofType: .number)
        let identifiers = capsule.extractTokens(from: parseResult, ofType: .identifier)
        let punctuation = capsule.extractTokens(from: parseResult, ofType: .punctuation)
        
        XCTAssertGreaterThan(keywords.count, 0)
        XCTAssertGreaterThan(numbers.count, 0)
        XCTAssertGreaterThan(identifiers.count, 0)
        XCTAssertGreaterThan(punctuation.count, 0)
        
        // Check specific tokens
        XCTAssertTrue(keywords.contains { $0.text == "int" })
        XCTAssertTrue(keywords.contains { $0.text == "return" })
        XCTAssertTrue(numbers.contains { $0.text == "42" })
        XCTAssertTrue(numbers.contains { $0.text == "3.14159" })
        XCTAssertTrue(identifiers.contains { $0.text == "main" })
        XCTAssertTrue(identifiers.contains { $0.text == "count" })
        XCTAssertTrue(punctuation.contains { $0.text == "(" })
        XCTAssertTrue(punctuation.contains { $0.text == ")" })
        XCTAssertTrue(punctuation.contains { $0.text == ";" })
    }
    
    // MARK: - HTML Highlighting Tests
    
    func testHighlightToHTML() async throws {
        let swiftCode = """
        class Greeter {
            func sayHello(name: String) {
                print("Hello, \\(name)!")
            }
        }
        """
        
        let html = try await capsule.highlightToHTML(swiftCode, language: .swift, theme: "github")
        
        XCTAssertTrue(html.contains("<pre class=\"github-highlight\"><code>"))
        XCTAssertTrue(html.contains("</code></pre>"))
        XCTAssertTrue(html.contains("class=\"github-keyword\""))
        XCTAssertTrue(html.contains("class=\"github-identifier\""))
        XCTAssertTrue(html.contains("class=\"github-string\""))
        XCTAssertTrue(html.contains("class=\"github-punctuation\""))
    }
    
    func testHighlightWithDifferentThemes() async throws {
        let code = "let x = 42"
        
        let githubTheme = try await capsule.highlightToHTML(code, language: .swift, theme: "github")
        let darkTheme = try await capsule.highlightToHTML(code, language: .swift, theme: "dark")
        
        XCTAssertTrue(githubTheme.contains("github-highlight"))
        XCTAssertTrue(githubTheme.contains("github-keyword"))
        
        XCTAssertTrue(darkTheme.contains("dark-highlight"))
        XCTAssertTrue(darkTheme.contains("dark-keyword"))
    }
    
    // MARK: - Error Handling Tests
    
    func testParseEmptyCode() async throws {
        let emptyCode = ""
        let parseResult = try await capsule.parse(emptyCode)
        
        XCTAssertEqual(parseResult.tokens.count, 0)
        XCTAssertEqual(parseResult.metadata.inputLength, 0)
    }
    
    func testParseUnsupportedLanguage() async throws {
        let code = "some code"
        
        do {
            _ = try await capsule.parse(code, language: .unknown)
            XCTFail("Expected parse to fail for unknown language")
        } catch {
            XCTAssertTrue(error is CapsuleError)
        }
    }
    
    func testParseWithAutoDetection() async throws {
        let swiftCode = "let x = 42"
        let parseResult = try await capsule.parse(swiftCode, language: .unknown)
        
        XCTAssertEqual(parseResult.detectedLanguage, .swift)
        XCTAssertGreaterThan(parseResult.tokens.count, 0)
    }
    
    // MARK: - Utility Tests
    
    func testSupportedLanguages() {
        let supported = capsule.supportedLanguages()
        
        XCTAssertTrue(supported.contains(.swift))
        XCTAssertTrue(supported.contains(.python))
        XCTAssertTrue(supported.contains(.cpp))
        XCTAssertTrue(supported.contains(.rust))
        XCTAssertTrue(supported.contains(.javascript))
        XCTAssertTrue(supported.contains(.typescript))
        XCTAssertTrue(supported.contains(.json))
        XCTAssertTrue(supported.contains(.html))
        XCTAssertTrue(supported.contains(.css))
        XCTAssertTrue(supported.contains(.markdown))
    }
    
    func testIsSupported() {
        XCTAssertTrue(capsule.isSupported(.swift))
        XCTAssertTrue(capsule.isSupported(.python))
        XCTAssertTrue(capsule.isSupported(.cpp))
        XCTAssertTrue(capsule.isSupported(.rust))
        XCTAssertFalse(capsule.isSupported(.unknown))
    }
    
    func testLanguageProperties() {
        XCTAssertEqual(SupportedLanguage.swift.name, "swift")
        XCTAssertEqual(SupportedLanguage.swift.displayName, "Swift")
        XCTAssertEqual(SupportedLanguage.swift.fileExtensions, ["swift"])
        
        XCTAssertEqual(SupportedLanguage.python.name, "python")
        XCTAssertEqual(SupportedLanguage.python.displayName, "Python")
        XCTAssertEqual(SupportedLanguage.python.fileExtensions, ["py", "pyw"])
        
        XCTAssertEqual(SupportedLanguage.cpp.name, "cpp")
        XCTAssertEqual(SupportedLanguage.cpp.displayName, "C++")
        XCTAssertTrue(SupportedLanguage.cpp.fileExtensions.contains("cpp"))
        XCTAssertTrue(SupportedLanguage.cpp.fileExtensions.contains("hpp"))
        
        XCTAssertEqual(SupportedLanguage.rust.name, "rust")
        XCTAssertEqual(SupportedLanguage.rust.displayName, "Rust")
        XCTAssertEqual(SupportedLanguage.rust.fileExtensions, ["rs"])
    }
    
    func testTokenTypeProperties() {
        XCTAssertEqual(TokenType.keyword.name, "keyword")
        XCTAssertEqual(TokenType.identifier.name, "identifier")
        XCTAssertEqual(TokenType.string.name, "string")
        XCTAssertEqual(TokenType.number.name, "number")
        XCTAssertEqual(TokenType.comment.name, "comment")
        XCTAssertEqual(TokenType.operator.name, "operator")
        XCTAssertEqual(TokenType.punctuation.name, "punctuation")
    }
    
    func testCapsuleProperties() {
        let version = capsule.version
        XCTAssertFalse(version.isEmpty)
    }
    
    func testDiagnosticsIntegration() async throws {
        let swiftCode = "let x = 42"
        _ = try await capsule.parse(swiftCode, language: .swift)
        
        let spans = diagnostics.spans
        XCTAssertGreaterThan(spans.count, 0)
        
        let parseSpans = spans.filter { $0.name == "syntax.parse" }
        XCTAssertEqual(parseSpans.count, 1)
        
        let span = parseSpans.first!
        XCTAssertEqual(span.name, "syntax.parse")
        XCTAssertEqual(span.category, "SyntaxCapsule")
        XCTAssertEqual(span.status, .ok)
    }
    
    // MARK: - Position Tests
    
    func testTokenPositions() async throws {
        let code = """
        line 1
        line 2
        line 3
        """
        
        let parseResult = try await capsule.parse(code, language: .swift)
        
        for token in parseResult.tokens {
            XCTAssertGreaterThanOrEqual(token.position.startLine, 1)
            XCTAssertGreaterThanOrEqual(token.position.startColumn, 1)
            XCTAssertGreaterThanOrEqual(token.position.endLine, token.position.startLine)
            if token.position.endLine == token.position.startLine {
                XCTAssertGreaterThanOrEqual(token.position.endColumn, token.position.startColumn)
            }
        }
    }
    
    // MARK: - Complex Code Tests
    
    func testParseComplexSwiftCode() async throws {
        let complexSwiftCode = """
        import Foundation
        import Combine
        
        // MARK: - Data Models
        
        struct User: Codable, Identifiable {
            let id: UUID
            let name: String
            let email: String
            let createdAt: Date
        }
        
        // MARK: - View Model
        
        @MainActor
        class UserViewModel: ObservableObject {
            @Published var users: [User] = []
            @Published var isLoading = false
            @Published var errorMessage: String?
            
            private let userService: UserService
            private var cancellables = Set<AnyCancellable>()
            
            init(userService: UserService) {
                self.userService = userService
            }
            
            func loadUsers() async {
                isLoading = true
                errorMessage = nil
                
                do {
                    let fetchedUsers = try await userService.fetchUsers()
                    await MainActor.run {
                        self.users = fetchedUsers
                        self.isLoading = false
                    }
                } catch {
                    await MainActor.run {
                        self.errorMessage = "Failed to load users: \\(error.localizedDescription)"
                        self.isLoading = false
                    }
                }
            }
        }
        """
        
        let parseResult = try await capsule.parse(complexSwiftCode, language: .swift)
        
        XCTAssertGreaterThan(parseResult.tokens.count, 100)
        XCTAssertEqual(parseResult.detectedLanguage, .swift)
        
        // Check for various token types
        let keywords = capsule.extractTokens(from: parseResult, ofType: .keyword)
        let identifiers = capsule.extractTokens(from: parseResult, ofType: .identifier)
        let strings = capsule.extractStringLiterals(from: parseResult)
        let comments = capsule.extractTokens(from: parseResult, ofType: .comment)
        
        XCTAssertGreaterThan(keywords.count, 0)
        XCTAssertGreaterThan(identifiers.count, 0)
        XCTAssertGreaterThan(strings.count, 0)
        XCTAssertGreaterThan(comments.count, 0)
        
        // Check for specific Swift keywords
        let swiftKeywords = ["import", "struct", "let", "class", "func", "do", "try", "catch", "await", "async"]
        for keyword in swiftKeywords {
            XCTAssertTrue(keywords.contains { $0.text == keyword }, "Missing keyword: \(keyword)")
        }
    }
}

// MARK: - Mock Diagnostics

class MockDiagnostics: CapsuleDiagnostics {
    var spans: [MockDiagnosticSpan] = []
    
    func beginSpan(
        name: String,
        category: String,
        correlationID: String? = nil,
        tags: [String: String] = [:]
    ) -> DiagnosticSpan {
        let span = MockDiagnosticSpan(name: name, category: category, tags: tags)
        spans.append(span)
        return span
    }
    
    func event(
        level: DiagnosticLevel,
        category: String,
        message: String,
        correlationID: String? = nil,
        metadata: [String: String] = [:]
    ) {
        // Mock implementation
    }
    
    func getEvents(since: Date) -> [DiagnosticEvent] {
        return []
    }
    
    func getAllEvents() -> [DiagnosticEvent] {
        return []
    }
    
    func clearEvents() {
        // Mock implementation
    }
}

class MockDiagnosticSpan: DiagnosticSpan {
    let spanID: String
    let name: String
    let category: String
    let correlationID: String?
    let startTime: Date
    var endTime: Date?
    var status: SpanStatus?
    var tags: [String: String]
    
    init(name: String, category: String, tags: [String: String] = [:]) {
        self.spanID = UUID().uuidString
        self.name = name
        self.category = category
        self.correlationID = nil
        self.startTime = Date()
        self.tags = tags
    }
    
    func end(status: SpanStatus) {
        self.endTime = Date()
        self.status = status
    }
    
    func addTag(key: String, value: String) {
        tags[key] = value
    }
    
    func recordEvent(level: DiagnosticLevel, message: String) {
        // Mock implementation
    }
}

// MARK: - Golden Tests

final class SyntaxCapsuleGoldenTests: XCTestCase {
    
    func testGoldenSwiftHighlighting() async throws {
        let swiftCode = """
        import Foundation
        
        class Fibonacci {
            static func calculate(_ n: Int) -> Int {
                guard n > 1 else { return n }
                return calculate(n - 1) + calculate(n - 2)
            }
        }
        
        let result = Fibonacci.calculate(10)
        print("Fibonacci(10) = \\(result)")
        """
        
        let capsule = SyntaxCapsule()
        let html = try await capsule.highlightToHTML(swiftCode, language: .swift, theme: "xcode")
        
        // Expected HTML structure
        XCTAssertTrue(html.contains("<pre class=\"xcode-highlight\"><code>"))
        XCTAssertTrue(html.contains("class=\"xcode-keyword\""))
        XCTAssertTrue(html.contains("class=\"xcode-identifier\""))
        XCTAssertTrue(html.contains("class=\"xcode-string\""))
        XCTAssertTrue(html.contains("class=\"xcode-number\""))
        XCTAssertTrue(html.contains("class=\"xcode-punctuation\""))
        
        // Check for specific highlighted elements
        XCTAssertTrue(html.contains("import"))
        XCTAssertTrue(html.contains("class"))
        XCTAssertTrue(html.contains("static"))
        XCTAssertTrue(html.contains("func"))
        XCTAssertTrue(html.contains("guard"))
        XCTAssertTrue(html.contains("else"))
        XCTAssertTrue(html.contains("return"))
        XCTAssertTrue(html.contains("let"))
        XCTAssertTrue(html.contains("print"))
    }
    
    func testGoldenPythonHighlighting() async throws {
        let pythonCode = """
        import numpy as np
        import matplotlib.pyplot as plt
        
        def generate_data(n_points: int = 100) -> tuple:
            """Generate sample data for plotting."""
            x = np.linspace(0, 2 * np.pi, n_points)
            y = np.sin(x) + 0.1 * np.random.randn(n_points)
            return x, y
        
        if __name__ == "__main__":
            x, y = generate_data(200)
            plt.figure(figsize=(10, 6))
            plt.plot(x, y, 'b-', label='Data')
            plt.xlabel('X axis')
            plt.ylabel('Y axis')
            plt.title('Sample Plot')
            plt.legend()
            plt.grid(True, alpha=0.3)
            plt.show()
        """
        
        let capsule = SyntaxCapsule()
        let html = try await capsule.highlightToHTML(pythonCode, language: .python, theme: "pygments")
        
        // Expected HTML structure
        XCTAssertTrue(html.contains("<pre class=\"pygments-highlight\"><code>"))
        XCTAssertTrue(html.contains("class=\"pygments-keyword\""))
        XCTAssertTrue(html.contains("class=\"pygments-identifier\""))
        XCTAssertTrue(html.contains("class=\"pygments-string\""))
        XCTAssertTrue(html.contains("class=\"pygments-number\""))
        XCTAssertTrue(html.contains("class=\"pygments-comment\""))
        
        // Check for specific highlighted elements
        XCTAssertTrue(html.contains("import"))
        XCTAssertTrue(html.contains("def"))
        XCTAssertTrue(html.contains("return"))
        XCTAssertTrue(html.contains("if"))
        XCTAssertTrue(html.contains("__name__"))
    }
    
    func testGoldenCppHighlighting() async throws {
        let cppCode = """
        #include <iostream>
        #include <vector>
        #include <algorithm>
        #include <memory>
        
        template<typename T>
        class Sorter {
        private:
            std::vector<T> data_;
        
        public:
            Sorter(std::vector<T> data) : data_(std::move(data)) {}
            
            void sort() {
                std::sort(data_.begin(), data_.end());
            }
            
            void print() const {
                for (const auto& item : data_) {
                    std::cout << item << " ";
                }
                std::cout << std::endl;
            }
        };
        
        int main() {
            std::vector<int> numbers = {5, 2, 8, 1, 9, 3};
            auto sorter = std::make_unique<Sorter<int>>(numbers);
            
            sorter->sort();
            sorter->print();
            
            return 0;
        }
        """
        
        let capsule = SyntaxCapsule()
        let html = try await capsule.highlightToHTML(cppCode, language: .cpp, theme: "vscode")
        
        // Expected HTML structure
        XCTAssertTrue(html.contains("<pre class=\"vscode-highlight\"><code>"))
        XCTAssertTrue(html.contains("class=\"vscode-keyword\""))
        XCTAssertTrue(html.contains("class=\"vscode-identifier\""))
        XCTAssertTrue(html.contains("class=\"vscode-number\""))
        XCTAssertTrue(html.contains("class=\"vscode-punctuation\""))
        
        // Check for specific highlighted elements
        XCTAssertTrue(html.contains("#include"))
        XCTAssertTrue(html.contains("template"))
        XCTAssertTrue(html.contains("typename"))
        XCTAssertTrue(html.contains("class"))
        XCTAssertTrue(html.contains("private"))
        XCTAssertTrue(html.contains("public"))
        XCTAssertTrue(html.contains("const"))
        XCTAssertTrue(html.contains("auto"))
    }
    
    func testGoldenRustHighlighting() async throws {
        let rustCode = """
        use std::collections::HashMap;
        use std::fs::File;
        use std::io::{self, Read};
        
        #[derive(Debug, Clone)]
        struct Config {
            name: String,
            values: HashMap<String, String>,
        }
        
        impl Config {
            pub fn new(name: String) -> Self {
                Self {
                    name,
                    values: HashMap::new(),
                }
            }
            
            pub fn load_from_file(&mut self, path: &str) -> io::Result<()> {
                let mut file = File::open(path)?;
                let mut contents = String::new();
                file.read_to_string(&mut contents)?;
                
                // Parse configuration (simplified)
                self.values.insert("loaded".to_string(), "true".to_string());
                
                Ok(())
            }
        }
        
        fn main() {
            let mut config = Config::new("app".to_string());
            
            match config.load_from_file("config.txt") {
                Ok(()) => println!("Config loaded successfully!"),
                Err(e) => eprintln!("Failed to load config: {}", e),
            }
        }
        """
        
        let capsule = SyntaxCapsule()
        let html = try await capsule.highlightToHTML(rustCode, language: .rust, theme: "rust")
        
        // Expected HTML structure
        XCTAssertTrue(html.contains("<pre class=\"rust-highlight\"><code>"))
        XCTAssertTrue(html.contains("class=\"rust-keyword\""))
        XCTAssertTrue(html.contains("class=\"rust-identifier\""))
        XCTAssertTrue(html.contains("class=\"rust-string\""))
        XCTAssertTrue(html.contains("class=\"rust-comment\""))
        
        // Check for specific highlighted elements
        XCTAssertTrue(html.contains("use"))
        XCTAssertTrue(html.contains("struct"))
        XCTAssertTrue(html.contains("impl"))
        XCTAssertTrue(html.contains("pub"))
        XCTAssertTrue(html.contains("mut"))
        XCTAssertTrue(html.contains("match"))
        XCTAssertTrue(html.contains("Ok"))
        XCTAssertTrue(html.contains("Err"))
    }
}