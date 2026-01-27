# Golden Audio Test Files

This directory contains test audio files for golden tests and validation.

## Files

### test_audio.wav
Simple 1-second 440Hz sine wave in WAV format:
- Sample rate: 44.1 kHz
- Channels: Stereo
- Duration: 1 second
- Format: 16-bit PCM

### test_audio.mp3  
Simple 1-second 440Hz sine wave in MP3 format:
- Sample rate: 44.1 kHz
- Channels: Stereo
- Duration: 1 second
- Bitrate: 128 kbps

### test_audio.flac
Simple 1-second 440Hz sine wave in FLAC format:
- Sample rate: 44.1 kHz
- Channels: Stereo
- Duration: 1 second
- Lossless compression

### test_audio.aac
Simple 1-second 440Hz sine wave in AAC format:
- Sample rate: 44.1 kHz
- Channels: Stereo
- Duration: 1 second
- Bitrate: 128 kbps

## Generation

These files were generated using the following commands:

```bash
# Generate WAV file
ffmpeg -f lavfi -i "sine=frequency=440:duration=1" -ar 44100 -ac 2 test_audio.wav

# Convert to MP3
ffmpeg -i test_audio.wav -codec:a mp3 -b:a 128k test_audio.mp3

# Convert to FLAC
ffmpeg -i test_audio.wav -codec:a flac test_audio.flac

# Convert to AAC
ffmpeg -i test_audio.wav -codec:a aac -b:a 128k test_audio.aac
```

## Usage

These files are used by:
- `AudioRenderCapsuleGoldenTests.swift` - Format detection and decoding validation
- `AudioRenderCapsuleTests.swift` - Basic functionality testing
- Performance benchmarks - Known-size audio files

## Properties

All files contain the same base audio data:
- Frequency: 440 Hz (A4 note)
- Amplitude: 0.5 (50% of full scale)
- Sample rate: 44.1 kHz
- Channels: 2 (stereo)
- Duration: 1.0 second

This makes them ideal for testing audio processing effects and waveform generation.