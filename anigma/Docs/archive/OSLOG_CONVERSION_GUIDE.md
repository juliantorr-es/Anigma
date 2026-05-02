# Anigma OSLog Conversion Guide

## 🎯 Overview

This guide documents the automated OSLog conversion process for the Anigma codebase, following Apple's best practices for Unified Logging. The conversion replaces `print()` statements with structured `OSLog` logging for better performance, debugging, and production readiness.

## 🚀 Automated Conversion Script

The `bulk_convert_harmonia.py` script automates the conversion process with the following features:

### ✨ Key Features

- **Bulk Conversion**: Processes multiple files automatically
- **Smart Category Detection**: Determines appropriate logger categories based on file content
- **Privacy Handling**: Adds proper privacy annotations for sensitive data
- **Log Level Detection**: Automatically uses info/error/warning levels based on message content
- **Backup & Restore**: Creates backups and validates conversions
- **CLI Tool Preservation**: Excludes files that appropriately use print() for user output

### 📋 Best Practices Implemented

Based on Apple's recommendations and industry best practices:

1. **Logger API**: Uses `Logger` (iOS 14+/macOS 11+) for Swifty syntax
2. **Structured Logging**: Replaces `print("message")` with `log.info("message")`
3. **Privacy Annotations**: Uses `.public` for non-sensitive data, `.private` for sensitive data
4. **Log Levels**: 
   - `.info` for informational messages
   - `.error` for errors and exceptions
   - `.warning` for warnings
5. **Subsystems & Categories**: Organizes logs by module/functionality
6. **Performance**: OSLog has minimal overhead compared to print()

### 🔧 Usage

```bash
# Run the conversion script
cd anigma
/usr/bin/python3 bulk_convert_harmonia.py

# Check remaining print statements
find Packages/HarmoniaModule -name "*.swift" | xargs grep -l "print(" 2>/dev/null | wc -l
```

## 📚 Conversion Patterns

### Basic Conversion

**Before:**
```swift
print("Processing started")
```

**After:**
```swift
log.info("Processing started")
```

### Error Handling

**Before:**
```swift
print("Failed to load data: \(error)")
```

**After:**
```swift
log.error("Failed to load data", metadata: ["error": "\(error, privacy: .public)"])
```

### String Interpolation

**Before:**
```swift
print("User \(userId) logged in")
```

**After:**
```swift
log.info("User logged in", metadata: ["userId": "\(userId, privacy: .public)"])
```

### Multiple Variables

**Before:**
```swift
print("Request \(requestId) from \(userId) completed in \(duration)ms")
```

**After:**
```swift
log.info("Request completed", metadata: [
    "requestId": "\(requestId, privacy: .public)",
    "userId": "\(userId, privacy: .public)",
    "duration": "\(duration)"
])
```

## 🎯 Logger Categories

The script automatically assigns categories based on file content:

| Category | Usage |
|----------|-------|
| `security` | Security-related modules |
| `migration` | Database migration systems |
| `network` | Network/API operations |
| `database` | Database operations |
| `class` | General class implementations |
| `struct` | General struct implementations |
| `actor` | Actor-based concurrency |
| `general` | Default category |

## ⚠️ Important Notes

### CLI Tools

Files in `CLI/`, `Harness/`, and `Tools/` directories are excluded by default because they often use `print()` appropriately for user-facing output. Review these manually to determine if OSLog conversion is needed.

### Privacy Considerations

- Use `.public` for non-sensitive data (most cases)
- Use `.private` for sensitive data (tokens, passwords, PII)
- Never log sensitive information in production

### Viewing Logs

After conversion, view logs in the **Console app** (not Xcode debug area):

1. Open Console.app
2. Filter by subsystem: `com.anigma.harmonia`
3. Use category filters to find specific logs
4. Enable "Info", "Debug", "Error" messages as needed

## 📈 Progress Tracking

### AnigmaCore (✅ COMPLETE)
- **Files converted**: 20+
- **Print statements**: 58+ converted
- **Status**: 100% complete

### HarmoniaModule (🚧 IN PROGRESS)
- **Files converted**: 29+
- **Print statements**: 75+ converted
- **Status**: ~24% complete
- **Remaining**: ~234 print statements

## 🎓 Best Practices Reference

### Apple Documentation
- [OSLog Documentation](https://developer.apple.com/documentation/os/logging)
- [Unified Logging](https://developer.apple.com/videos/play/wwdc2016/721/)
- [Privacy Best Practices](https://developer.apple.com/documentation/foundation/oslog/protecting_privacy_when_logging_message_data)

### Recommended Patterns

```swift
// Good: Structured logging with metadata
log.info("User action completed", metadata: [
    "action": "\(action, privacy: .public)",
    "duration": "\(duration)"
])

// Good: Error logging with context
log.error("Database connection failed", metadata: [
    "error": "\(error.localizedDescription, privacy: .public)",
    "retryCount": "\(retryCount)"
])

// Avoid: Logging sensitive data
log.info("User email: \(user.email)")  // ❌ Bad
log.info("User logged in", metadata: ["userId": "\(user.id.hash)"])  // ✅ Good
```

## 🔄 Conversion Workflow

1. **Run automated script** for bulk conversion
2. **Manually review** complex cases and CLI tools
3. **Test builds** to ensure no regressions
4. **Validate logs** in Console app
5. **Iterate** on remaining files

## 🚀 Next Steps

1. **Run script again** to catch newly qualified files
2. **Complete HarmoniaModule** conversion (~76% remaining)
3. **Test all builds** to ensure stability
4. **Document any manual exceptions**
5. **Monitor logs** in production

## 📝 Changelog

### v2.0 (Current)
- Added smart category detection
- Improved privacy handling
- Added log level detection (info/error/warning)
- Implemented backup/restore functionality
- Added conversion validation
- Enhanced error handling

### v1.0 (Initial)
- Basic print-to-OSLog conversion
- Simple regex patterns
- Manual category assignment

## 🤝 Contributing

To contribute to the OSLog conversion effort:

1. **Fork** the repository
2. **Run the script** on targeted files
3. **Test** the conversions
4. **Submit PR** with changes
5. **Document** any special cases

## 📊 Metrics

Track conversion progress with:

```bash
# Count remaining print statements
grep -r "print(" Packages/ | grep -v ".backup" | wc -l

# Count OSLog usage
grep -r "log\.info\|log\.error\|log\.warning" Packages/ | wc -l

# List files still needing conversion
grep -rl "print(" Packages/ | grep -v ".backup" | grep -v "CLI" | grep -v "Harness" | grep -v "Tools"
```

---

**Last Updated**: 2024
**Status**: Active Development
**Target Completion**: 100% OSLog adoption