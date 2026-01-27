# AudioRenderCapsule

A comprehensive audio processing and rendering capsule for the Anigma ecosystem. Supports multiple audio formats with real-time effects processing and waveform visualization.

## Features

### Audio Format Support
- **MP3** - MPEG-1/2/2.5 Layer III
- **WAV** - PCM and compressed variants  
- **FLAC** - Free Lossless Audio Codec
- **AAC** - Advanced Audio Coding
- **OGG** - Ogg Vorbis (detection)

### Audio Effects
- **Reverb** - Room simulation with adjustable parameters
- **Equalizer** - 10-band parametric EQ
- **Compressor** - Dynamic range compression
- **Delay** - Echo and delay effects

### Visualization
- **Waveform Generation** - Peak and RMS waveform data
- **Multi-channel Support** - Separate waveforms per channel
- **Configurable Resolution** - Adjustable width and height

### Performance
- **FFmpeg Integration** - Hardware-accelerated decoding
- **Memory Efficient** - Streaming processing pipeline
- **Concurrent Processing** - Thread-safe actor model
- **Batch Operations** - Parallel processing of multiple files

## Architecture

The AudioRenderCapsule follows the Anigma capsule architecture with:
- Swift actor wrapper for thread safety
- C++ native library for performance-critical operations
- Comprehensive error handling with `CapsuleError` mapping
- Full diagnostics integration for observability
- Extensive testing including golden fixtures and benchmarks

## Usage

### Basic Audio Decoding

```swift
import AudioRenderCapsule

let capsule = AudioRenderCapsule()

// Decode audio file
let audioData = Data(contentsOf: audioFileURL)
let decodedAudio = try await capsule.decode(data: audioData)

print("Sample rate: \(decodedAudio.metadata.sampleRate) Hz")
print("Duration: \(decodedAudio.metadata.durationSeconds) seconds")
print("Channels: \(decodedAudio.metadata.channels)")
```

### Format Detection

```swift
// Auto-detect audio format
let format = await capsule.detectFormat(data: audioData)
switch format {
case .mp3: print("MP3 file")
case .wav: print("WAV file")
case .flac: print("FLAC file")
case .aac: print("AAC file")
default: print("Unknown format")
}
```

### Audio Effects

```swift
// Apply reverb effect
let reverbParams = AudioEffectParameters(
    type: .reverb,
    roomSize: 0.8,
    wetLevel: 0.4,
    dryLevel: 0.6
)
let audioWithReverb = try await capsule.applyEffect(
    to: decodedAudio, 
    effect: reverbParams
)

// Apply equalizer
let eqParams = AudioEffectParameters(
    type: .equalizer,
    bands: [3.0, 2.0, 1.0, 0.0, -1.0, 0.0, 1.0, 2.0, 3.0, 2.0]
)
let equalizedAudio = try await capsule.applyEffect(
    to: decodedAudio, 
    effect: eqParams
)
```

### Waveform Visualization

```swift
// Generate waveform for visualization
let waveform = try await capsule.generateWaveform(
    from: decodedAudio,
    width: 800,
    height: 200
)

// Access peak and RMS data
for x in 0..<Int(waveform.width) {
    for channel in 0..<Int(waveform.channels) {
        let index = x * Int(waveform.channels) + channel
        let peak = waveform.peaks[index]
        let rms = waveform.rms[index]
        
        // Render waveform visualization
        drawWaveformPixel(x: x, channel: channel, peak: peak, rms: rms)
    }
}
```

### Batch Processing

```swift
// Process multiple audio files in parallel
let audioFiles = [audioData1, audioData2, audioData3]
let results = await capsule.decodeBatch(audioFiles: audioFiles)

for (index, result) in results.enumerated() {
    if let decoded = result {
        print("File \(index): \(decoded.metadata.durationSeconds) seconds")
    } else {
        print("File \(index): Failed to decode")
    }
}
```

### Diagnostics Integration

```swift
import TelemetryCore

let diagnostics = DefaultCapsuleDiagnostics()
let capsule = AudioRenderCapsule(diagnostics: diagnostics)

// Perform operations
_ = try await capsule.decode(data: audioData)

// Access diagnostic events
let events = diagnostics.getAllEvents()
for event in events {
    print("\(event.level): \(event.message)")
}
```

## API Reference

### AudioRenderCapsule

Main actor for audio processing operations.

#### Properties
- `version: String` - Library version information

#### Methods

##### Decoding
- `decode(data:format:)` - Decode audio with optional format hint
- `decodeMP3(_:)` - Decode MP3 audio
- `decodeWAV(_:)` - Decode WAV audio
- `decodeFLAC(_:)` - Decode FLAC audio
- `decodeAAC(_:)` - Decode AAC audio

##### Effects
- `applyEffect(to:effect:)` - Apply audio effect to decoded audio

##### Visualization
- `generateWaveform(from:width:height:)` - Generate waveform data

##### Utilities
- `detectFormat(data:)` - Auto-detect audio format
- `decodeBatch(audioFiles:format:)` - Batch process multiple files
- `getLastError()` - Get last native library error message

### Data Types

#### AudioFormat
Supported audio formats:
- `mp3` - MPEG audio
- `wav` - Waveform audio
- `flac` - Free lossless audio codec
- `aac` - Advanced audio coding
- `ogg` - Ogg container
- `unknown` - Unrecognized format

#### SampleFormat
Audio sample formats:
- `u8` - Unsigned 8-bit
- `s16` - Signed 16-bit
- `s32` - Signed 32-bit
- `f32` - Float 32-bit (default)
- `f64` - Float 64-bit

#### AudioEffectType
Available effect types:
- `reverb` - Reverberation effect
- `equalizer` - 10-band parametric EQ
- `compressor` - Dynamic range compression
- `delay` - Echo/delay effect
- `none` - No effect

#### AudioEffectParameters
Parameters for audio effects with proper clamping and validation.

#### AudioMetadata
Complete audio file metadata including:
- Sample rate and channels
- Duration and bit rate
- Format information
- ID3 tags (title, artist, album)
- Computed properties (duration in seconds, total samples)

#### DecodedAudio
Decoded audio data with metadata and efficient memory management.

#### AudioWaveform
Waveform visualization data with:
- Configurable dimensions
- Peak and RMS values per channel
- Multi-channel support

## Error Handling

The capsule maps all native errors to the canonical `CapsuleError` type:

```swift
do {
    let decoded = try await capsule.decode(data: audioData)
} catch let error as CapsuleError {
    switch error {
    case .invalidInput(let field, let constraint):
        print("Invalid input for \(field): \(constraint)")
    case .unsupportedFormat:
        print("Audio format not supported")
    case .decodeFailed:
        print("Audio decoding failed")
    case .memoryAllocation:
        print("Insufficient memory")
    // ... other error cases
    }
}
```

## Performance Considerations

### Memory Management
- Native library handles memory allocation/deallocation
- Swift wrapper uses proper memory management with `Data` deallocator
- Large audio files are processed in streaming fashion

### Concurrency
- Swift actor ensures thread safety
- Native library supports concurrent operations
- Batch processing uses `TaskGroup` for parallel execution

### Hardware Acceleration
- FFmpeg integration enables hardware-accelerated decoding
- SIMD optimizations for audio effects
- Efficient buffer management for large datasets

## Testing

The capsule includes comprehensive test coverage:

### Unit Tests
- Basic functionality testing
- Error handling verification
- Parameter validation
- Data structure integrity

### Golden Tests
- Known input/output verification
- Reference implementation comparison
- Regression testing with fixtures

### Contract Tests
- Anigma capsule compliance
- API consistency verification
- Lifecycle management testing

### Benchmarks
- Performance regression testing
- Memory usage profiling
- Concurrent operation testing

Run tests with:
```bash
swift test --filter AudioRenderCapsuleTests
swift test --filter AudioRenderCapsuleGoldenTests  
swift test --filter AudioRenderCapsuleContractTests
swift test --filter AudioRenderCapsuleBenchmarks
```

## Dependencies

### Required
- **CapsuleCore** - Core capsule infrastructure
- **TelemetryCore** - Diagnostics and observability
- **FFmpeg** - Audio decoding and processing (libavformat, libavcodec, libswresample)

### Build Requirements
- macOS 14.0+ / iOS 17.0+
- Swift 6.0 with strict concurrency
- C++17 compatible compiler
- FFmpeg development libraries

## Installation

The AudioRenderCapsule is distributed as a Swift package:

```swift
dependencies: [
    .package(path: "Packages/AudioRenderCapsule")
]
```

### FFmpeg Setup

For macOS with Homebrew:
```bash
brew install ffmpeg
```

The capsule will automatically link against the installed FFmpeg libraries.

## Contributing

When contributing to the AudioRenderCapsule:

1. Follow the Anigma coding standards
2. Add comprehensive tests for new features
3. Update documentation and API references
4. Ensure Swift 6 compliance
5. Run the full test suite before submitting

## License

This capsule is part of the Anigma project and follows the project's licensing terms.

## Changelog

### v1.0.0
- Initial release
- Support for MP3, WAV, FLAC, AAC formats
- Reverb, equalizer, compressor, delay effects
- Waveform visualization
- Comprehensive testing suite
- FFmpeg integration
- Swift 6 compliance