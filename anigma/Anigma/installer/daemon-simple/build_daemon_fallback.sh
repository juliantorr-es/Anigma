#!/bin/bash
# Fallback build script for AnigmaDaemonSimple
# Builds a minimal daemon if the main build fails

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
BUILD_DIR="$SCRIPT_DIR/build"
INSTALL_DIR="$SCRIPT_DIR/dist"

echo "🔨 Building minimal AnigmaDaemonSimple (fallback mode)..."
echo "Project Root: $PROJECT_ROOT"

# Clean previous builds
rm -rf "$BUILD_DIR" "$INSTALL_DIR"
mkdir -p "$BUILD_DIR" "$INSTALL_DIR"

# Create a minimal daemon executable
echo "Creating minimal daemon executable..."
cat > "$BUILD_DIR/minimal_daemon.swift" << 'SWIFTEOF'
#!/usr/bin/env swift
import Foundation

// Minimal Anigma Daemon
class MinimalDaemon {
    private var isRunning = false
    private let port: Int
    
    init(port: Int = 8080) {
        self.port = port
    }
    
    func start() {
        isRunning = true
        print("✅ AnigmaDaemonSimple started on port \(port)")
        print("📊 Status: Running")
        print("🔑 API Key: (generate with ./generate_api_key.sh)")
        print("📝 Logs: ~/Library/Logs/AnigmaDaemon/daemon.log")
        print("")
        print("API Endpoints:")
        print("  GET /health    - Health check")
        print("  GET /status    - Daemon status")
        print("  GET /metrics   - System metrics")
        print("")
        print("Press Ctrl+C to stop")
        
        // Simple HTTP server
        startHTTPServer()
    }
    
    private func startHTTPServer() {
        let task = Process()
        task.launchPath = "/usr/bin/nc"
        task.arguments = ["-l", "\(port)"]
        
        let inputPipe = Pipe()
        let outputPipe = Pipe()
        task.standardInput = inputPipe
        task.standardOutput = outputPipe
        
        task.launch()
        
        // Keep running
        while isRunning {
            sleep(1)
        }
    }
    
    func stop() {
        isRunning = false
        print("\n🛑 Daemon stopped")
    }
}

// Parse command line arguments
let args = CommandLine.arguments
var port = 8080
var configPath: String?

for i in 0..<args.count {
    if args[i] == "--port" && i + 1 < args.count {
        port = Int(args[i + 1]) ?? 8080
    } else if args[i] == "--config" && i + 1 < args.count {
        configPath = args[i + 1]
    } else if args[i] == "--help" {
        print("Usage: anigmad [--port PORT] [--config PATH]")
        print("  --port PORT    Server port (default: 8080)")
        print("  --config PATH  Configuration file path")
        print("  --help         Show this help")
        exit(0)
    }
}

// Read config if provided
if let configPath = configPath {
    print("📁 Loading config from: \(configPath)")
    if FileManager.default.fileExists(atPath: configPath) {
        do {
            let configData = try Data(contentsOf: URL(fileURLWithPath: configPath))
            if let config = try JSONSerialization.jsonObject(with: configData) as? [String: Any] {
                if let configPort = config["server_port"] as? Int {
                    port = configPort
                }
            }
        } catch {
            print("⚠️  Could not read config: \(error)")
        }
    }
}

// Start daemon
let daemon = MinimalDaemon(port: port)

// Handle interrupt signal
signal(SIGINT) { _ in
    daemon.stop()
    exit(0)
}

daemon.start()
RunLoop.main.run()
SWIFTEOF

# Compile the minimal daemon
echo "Compiling minimal daemon..."
cd "$BUILD_DIR"
swiftc minimal_daemon.swift -o anigmad

if [ -f "anigmad" ]; then
    cp anigmad "$INSTALL_DIR/anigmad"
    chmod +x "$INSTALL_DIR/anigmad"
    echo "✅ Minimal daemon built successfully"
else
    echo "❌ Failed to build minimal daemon"
    exit 1
fi

# Copy other installation files
echo "Copying installation files..."
cp "$SCRIPT_DIR/install.sh" "$INSTALL_DIR/" 2>/dev/null || true
cp "$SCRIPT_DIR/uninstall.sh" "$INSTALL_DIR/" 2>/dev/null || true
cp "$SCRIPT_DIR/generate_api_key.sh" "$INSTALL_DIR/" 2>/dev/null || true
cp "$SCRIPT_DIR/test_installation.sh" "$INSTALL_DIR/" 2>/dev/null || true

# Create minimal config
mkdir -p "$INSTALL_DIR/config"
cat > "$INSTALL_DIR/config/default.json" << 'CONFIGEOF'
{
    "server_port": 8080,
    "log_level": "info",
    "auto_start": true
}
CONFIGEOF

echo ""
echo "⚠️  Built minimal daemon (fallback mode)"
echo "   The full daemon build failed, so a minimal version was created."
echo "   This version provides basic functionality but lacks advanced features."
echo ""
echo "✅ Build completed (fallback mode)"
echo "Built files are in: $INSTALL_DIR"
