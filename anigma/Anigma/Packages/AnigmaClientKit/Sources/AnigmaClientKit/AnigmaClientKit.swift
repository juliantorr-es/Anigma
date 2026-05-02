/// AnigmaClientKit provides an HTTP client for interacting with the Anigma daemon API.
/// It supports job submission, polling for completion, and result retrieval with async/await patterns.

public struct AnigmaClient {
    /// Configuration for the Anigma daemon connection
    public struct Configuration {
        public let host: String
        public let port: Int
        public let scheme: String
        public let timeout: TimeInterval
        
        public init(
            host: String = "localhost",
            port: Int = 8080,
            scheme: String = "http",
            timeout: TimeInterval = 30.0
        ) {
            self.host = host
            self.port = port
            self.scheme = scheme
            self.timeout = timeout
        }
    }
    
    private let configuration: Configuration
    private let session: URLSession
    
    /// Initialize a new AnigmaClient
    public init(configuration: Configuration = Configuration()) {
        self.configuration = configuration
        let sessionConfig = URLSessionConfiguration.default
        sessionConfig.timeoutIntervalForRequest = configuration.timeout
        sessionConfig.timeoutIntervalForResource = configuration.timeout * 10
        self.session = URLSession(configuration: sessionConfig)
    }
    
    /// Build the base URL for API calls
    private func baseURL() -> URL? {
        let urlString = "\(configuration.scheme)://\(configuration.host):\(configuration.port)"
        return URL(string: urlString)
    }
}
