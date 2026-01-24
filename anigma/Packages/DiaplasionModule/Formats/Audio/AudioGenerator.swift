//
//  AudioGenerator.swift
//  DiaplasionModule
//
//  Generates audio files from SSML with voice selection and effects.
//

import AnigmaCore
import Foundation
import AnigmaPrimitives

#if canImport(AVFoundation)
import AVFoundation
#endif

/// Generates audio files from SSML with configurable voices and effects.
public struct AudioGenerator: Sendable {
    
    // MARK: - Configuration
    
    /// Default voice for audio generation
    public let defaultVoice: String?
    
    /// Speech rate multiplier
    public let speechRate: Float
    
    /// Speech pitch multiplier
    public let pitchMultiplier: Float
    
    /// Audio output format
    public let audioFormat: AudioFormat
    
    /// Audio quality setting
    public let audioQuality: AudioQuality
    
    /// Include pronunciation dictionary
    public let includePronunciation: Bool
    
    // MARK: - Initialization
    
    public init(
        defaultVoice: String? = nil,
        speechRate: Float? = nil,
        pitchMultiplier: Float? = nil,
        audioFormat: AudioFormat? = nil,
        audioQuality: AudioQuality = .high,
        includePronunciation: Bool? = nil
    ) {
        self.defaultVoice = defaultVoice ?? DiaplasionConfiguration.audioVoice
        self.speechRate = speechRate ?? Float(DiaplasionConfiguration.audioSpeechRate)
        self.pitchMultiplier = pitchMultiplier ?? Float(DiaplasionConfiguration.audioSpeechPitch)
        self.audioFormat = audioFormat ?? DiaplasionConfiguration.audioFormat
        self.audioQuality = audioQuality
        self.includePronunciation = includePronunciation ?? DiaplasionConfiguration.audioIncludePronunciation
    }
    
    // MARK: - Public Interface
    
    /// Generate audio file from SSML.
    public func generateAudio(
        from ssml: String,
        outputPath: URL,
        metadata: AudioMetadata? = nil
    ) async throws -> AudioGenerationResult {
        
        #if canImport(AVFoundation)
        let synthesizer = AVSpeechSynthesizer()
        
        // Process pronunciation dictionary if enabled
        let processedSSML = includePronunciation ? applyPronunciationDictionary(ssml) : ssml
        
        // Generate utterance from SSML
        let utterance = AVSpeechUtterance(string: processedSSML)
        
        // Configure utterance
        if let voice = selectedVoice {
            utterance.voice = voice
        }
        
        utterance.rate = speechRate
        utterance.pitchMultiplier = pitchMultiplier
        utterance.volume = 1.0
        
        // Set audio session for high quality recording (iOS only)
        #if os(iOS)
        try await configureAudioSession()
        #endif
        
        // Generate audio
        let startTime = Date()
        let audioData = try await generateAudioData(synthesizer: synthesizer, utterance: utterance)
        let duration = Date().timeIntervalSince(startTime)
        
        // Save to file
        try await saveAudioData(audioData, to: outputPath)
        
        // Generate metadata if not provided
        let finalMetadata = metadata ?? generateDefaultMetadata(
            ssml: processedSSML,
            duration: duration,
            outputPath: outputPath
        )
        
        return AudioGenerationResult(
            outputPath: outputPath,
            duration: duration,
            fileSize: outputPath.fileSize,
            format: audioFormat,
            metadata: finalMetadata,
            processingTime: duration
        )
        #else
        throw AudioGenerationError.platformUnsupported
        #endif
    }
    
    /// Generate audio files for multiple chunks.
    public func generateAudioForChunks(
        _ chunks: [TextChunk],
        outputDirectory: URL,
        progressHandler: ((AudioProgress) -> Void)? = nil
    ) async throws -> [AudioGenerationResult] {
        
        var results: [AudioGenerationResult] = []
        let totalChunks = chunks.count
        
        for (index, chunk) in chunks.enumerated() {
            let progress = AudioProgress(
                currentChunk: index + 1,
                totalChunks: totalChunks,
                percentage: Double(index + 1) / Double(totalChunks) * 100
            )
            
            progressHandler?(progress)
            
            // Generate SSML for this chunk
            let ssml = generateSSMLForChunk(chunk)
            
            // Generate output file path
            let fileName = "chunk_\(String(format: "%03d", index + 1)).\(audioFormat.rawValue)"
            let outputPath = outputDirectory.appendingPathComponent(fileName)
            
            // Generate audio
            let result = try await generateAudio(
                from: ssml,
                outputPath: outputPath,
                metadata: AudioMetadata(
                    title: "Chunk \(index + 1)",
                    format: audioFormat,
                    chapter: index + 1,
                    totalChapters: totalChunks,
                    chunkType: chunk.chunkType.rawValue
                )
            )
            
            results.append(result)
            
            await Logger.shared.debug(
                "Generated audio for chunk \(index + 1)/\(totalChunks)",
                category: "Diaplasion"
            )
        }
        
        return results
    }
    
    /// Get available voices for audio generation.
    public func getAvailableVoices() -> [AudioVoice] {
        #if canImport(AVFoundation)
        return AVSpeechSynthesisVoice.speechVoices().compactMap { voice in
            AudioVoice(
                identifier: voice.identifier,
                name: voice.name,
                language: voice.language,
                quality: voice.quality == .enhanced ? .enhanced : .standard,
                gender: inferGender(from: voice.name)
            )
        }
        #else
        return []
        #endif
    }
    
    // MARK: - Private Implementation
    
    #if canImport(AVFoundation)
    private var selectedVoice: AVSpeechSynthesisVoice? {
        guard let defaultVoice = defaultVoice else { return nil }
        
        return AVSpeechSynthesisVoice.speechVoices().first { voice in
            voice.identifier.contains(defaultVoice) || voice.name.lowercased().contains(defaultVoice.lowercased())
        }
    }
    
    private func configureAudioSession() async throws {
        #if os(iOS)
        let audioSession = AVAudioSession.sharedInstance()
        try audioSession.setCategory(.playAndRecord, mode: .default)
        try audioSession.setActive(true)
        #endif
    }
    
    private func generateAudioData(
        synthesizer: AVSpeechSynthesizer,
        utterance: AVSpeechUtterance
    ) async throws -> Data {
        return try await withCheckedThrowingContinuation { continuation in
            var audioData = Data()
            
            synthesizer.write(utterance) { buffer in
                guard let pcmBuffer = buffer as? AVAudioPCMBuffer else {
                    if !audioData.isEmpty {
                        continuation.resume(returning: audioData)
                    } else {
                        continuation.resume(throwing: AudioGenerationError.noAudioData)
                    }
                    return
                }
                
                let frameLength = Int(pcmBuffer.frameLength)
                if frameLength > 0 {
                    let audioBuffer = pcmBuffer.audioBufferList.pointee.mBuffers
                    if let mData = audioBuffer.mData {
                        audioData.append(Data(bytes: mData, count: Int(audioBuffer.mDataByteSize)))
                    }
                }
            }
        }
    }
    #endif
    
    private func saveAudioData(_ audioData: Data, to outputPath: URL) async throws {
        // Convert to requested format
        let finalData = try convertAudioFormat(audioData, to: audioFormat)
        
        try finalData.write(to: outputPath)
    }
    
    private func convertAudioFormat(_ audioData: Data, to format: AudioFormat) throws -> Data {
        // Simplified format conversion
        // In practice, this would use AudioConverter or similar
        switch format {
        case .m4a:
            return audioData // Assuming input is already in suitable format
        case .wav:
            return try convertToWAV(audioData)
        case .mp3:
            return try convertToMP3(audioData)
        }
    }
    
    private func convertToWAV(_ data: Data) throws -> Data {
        // Simplified WAV conversion
        // In practice, this would use AudioConverter
        return data // Placeholder
    }
    
    private func convertToMP3(_ data: Data) throws -> Data {
        // Simplified MP3 conversion
        // In practice, this would use AudioConverter or third-party library
        return data // Placeholder
    }
    
    private func generateSSMLForChunk(_ chunk: TextChunk) -> String {
        var ssml = "<speak>"
        
        // Add prosody based on chunk type
        switch chunk.chunkType {
        case .heading:
            ssml += "<prosody rate=\"slow\" pitch=\"high\">"
        case .caption:
            ssml += "<prosody rate=\"slow\" volume=\"soft\">"
        default:
            ssml += "<prosody rate=\"normal\" pitch=\"medium\">"
        }
        
        // Escape SSML special characters
        let escapedText = escapeSSML(chunk.text)
        ssml += escapedText
        
        ssml += "</prosody>"
        ssml += "</speak>"
        
        return ssml
    }
    
    private func escapeSSML(_ text: String) -> String {
        return text
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "'", with: "&apos;")
    }
    
    private func generateDefaultMetadata(ssml: String, duration: TimeInterval, outputPath: URL) -> AudioMetadata {
        return AudioMetadata(
            title: "Generated Audio",
            artist: "Anigma Diaplasion",
            album: "Document Audio",
            date: Date(),
            duration: duration,
            format: audioFormat,
            language: DiaplasionConfiguration.defaultLanguage,
            voice: selectedVoice?.name ?? "Default"
        )
    }
    
    private func applyPronunciationDictionary(_ ssml: String) -> String {
        // Apply pronunciation dictionary rules
        var processed = ssml
        
        // Common pronunciation adjustments
        let pronunciationRules: [String: String] = [
            "README": "read me",
            "iOS": "eye o s",
            "macOS": "mac o s",
            "API": "A P I",
            "SQL": "S Q L",
            "URL": "U R L",
            "HTTP": "H T T P",
            "HTTPS": "H T T P S",
            "JSON": "jay sun",
            "XML": "E M L",
            "HTML": "H T M L",
            "CSS": "C S S",
            "JS": "jay ess",
            "PDF": "P D F",
            "EPUB": "E pub"
        ]
        
        for (word, pronunciation) in pronunciationRules {
            processed = processed.replacingOccurrences(
                of: "\\b\(word)\\b",
                with: "<phoneme alphabet=\"ipa\">\(pronunciation)</phoneme>",
                options: .regularExpression
            )
        }
        
        return processed
    }
    
    private func inferGender(from voiceName: String) -> AudioVoiceGender? {
        let name = voiceName.lowercased()
        if name.contains("female") || name.contains("woman") || name.contains("girl") {
            return .female
        } else if name.contains("male") || name.contains("man") || name.contains("boy") {
            return .male
        } else {
            return nil // Unknown
        }
    }
}

// MARK: - Supporting Types

/// Audio quality settings.
public enum AudioQuality: String, CaseIterable, Sendable {
    case low = "low"
    case medium = "medium"
    case high = "high"
    case lossless = "lossless"
    
    /// Bitrate for this quality level.
    public var bitrate: Int {
        switch self {
        case .low: return 64
        case .medium: return 128
        case .high: return 192
        case .lossless: return 320
        }
    }
    
    /// Sample rate for this quality level.
    public var sampleRate: Int {
        switch self {
        case .low: return 22050
        case .medium: return 44100
        case .high: return 44100
        case .lossless: return 48000
        }
    }
}

/// Voice information for audio generation.
public struct AudioVoice: Sendable {
    public let identifier: String
    public let name: String
    public let language: String
    public let quality: AudioVoiceQuality
    public let gender: AudioVoiceGender?
    
    public init(
        identifier: String,
        name: String,
        language: String,
        quality: AudioVoiceQuality,
        gender: AudioVoiceGender?
    ) {
        self.identifier = identifier
        self.name = name
        self.language = language
        self.quality = quality
        self.gender = gender
    }
}

/// Voice quality levels.
public enum AudioVoiceQuality: String, CaseIterable, Sendable {
    case standard = "standard"
    case enhanced = "enhanced"
}

/// Voice gender.
public enum AudioVoiceGender: String, CaseIterable, Sendable {
    case male = "male"
    case female = "female"
    case unknown = "unknown"
}

/// Metadata for generated audio.
public struct AudioMetadata: Sendable {
    public let title: String?
    public let artist: String?
    public let album: String?
    public let date: Date?
    public let duration: TimeInterval?
    public let format: AudioFormat
    public let language: String?
    public let voice: String?
    public let chapter: Int?
    public let totalChapters: Int?
    public let chunkType: String?
    
    public init(
        title: String? = nil,
        artist: String? = nil,
        album: String? = nil,
        date: Date? = nil,
        duration: TimeInterval? = nil,
        format: AudioFormat,
        language: String? = nil,
        voice: String? = nil,
        chapter: Int? = nil,
        totalChapters: Int? = nil,
        chunkType: String? = nil
    ) {
        self.title = title
        self.artist = artist
        self.album = album
        self.date = date
        self.duration = duration
        self.format = format
        self.language = language
        self.voice = voice
        self.chapter = chapter
        self.totalChapters = totalChapters
        self.chunkType = chunkType
    }
}

/// Result of audio generation.
public struct AudioGenerationResult: Sendable {
    public let outputPath: URL
    public let duration: TimeInterval
    public let fileSize: Int64?
    public let format: AudioFormat
    public let metadata: AudioMetadata
    public let processingTime: TimeInterval
    
    public init(
        outputPath: URL,
        duration: TimeInterval,
        fileSize: Int64?,
        format: AudioFormat,
        metadata: AudioMetadata,
        processingTime: TimeInterval
    ) {
        self.outputPath = outputPath
        self.duration = duration
        self.fileSize = fileSize
        self.format = format
        self.metadata = metadata
        self.processingTime = processingTime
    }
    
    /// File size in MB.
    public var sizeMB: Double {
        guard let fileSize = fileSize else { return 0 }
        return Double(fileSize) / (1024 * 1024)
    }
}

/// Progress during audio generation.
public struct AudioProgress: Sendable {
    public let currentChunk: Int
    public let totalChunks: Int
    public let percentage: Double
    
    public init(currentChunk: Int, totalChunks: Int, percentage: Double) {
        self.currentChunk = currentChunk
        self.totalChunks = totalChunks
        self.percentage = percentage
    }
}

/// Audio generation errors.
public enum AudioGenerationError: LocalizedError {
    case platformUnsupported
    case voiceNotFound
    case synthesisFailed
    case fileFormatError
    case noAudioData
    
    public var errorDescription: String? {
        switch self {
        case .platformUnsupported:
            return "Audio generation not supported on this platform"
        case .voiceNotFound:
            return "Specified voice not found"
        case .synthesisFailed:
            return "Speech synthesis failed"
        case .fileFormatError:
            return "Audio file format conversion failed"
        case .noAudioData:
            return "No audio data was generated"
        }
    }
}

// MARK: - System Integration

/// System that generates audio files from text chunks.
public struct AudioGenerationSystem: System {
    public var name: String { "AudioGeneration" }
    
    private let generator: AudioGenerator
    
    public init(generator: AudioGenerator = AudioGenerator()) {
        self.generator = generator
    }
    
    public func update(world: World) async {
        let entities = await world.query(
            ChunkedTextComponent.self,
            TransformRequestComponent.self
        )
        
        for (entity, chunked, transform) in entities {
            // Skip if not processing audio
            if !transform.targetFormats.contains(.audioReady) {
                continue
            }
            
            // Skip if already processed
            if await world.hasComponent(entity, GeneratedAudioComponent.self) {
                continue
            }
            
            // Create output directory for this entity
            let outputDirectory = createOutputDirectory(for: entity)
            
            do {
                let results = try await generator.generateAudioForChunks(
                    chunked.chunks,
                    outputDirectory: outputDirectory
                ) { progress in
                    Task {
                        await world.addComponent(entity, ProgressUpdateComponent(
                            action: .update(
                                currentStep: progress.currentChunk,
                                stage: .processing,
                                message: "Generated audio for chunk \(progress.currentChunk) of \(progress.totalChunks)",
                                metadata: ["percentage": "\(String(format: "%.1f", progress.percentage))"]
                            )
                        ))
                    }
                }
                
                let component = GeneratedAudioComponent(
                    audioFiles: results,
                    outputDirectory: outputDirectory,
                    generationDate: Date(),
                    totalDuration: results.reduce(0) { $0 + $1.duration },
                    totalSizeMB: results.reduce(0) { $0 + $1.sizeMB }
                )
                
                await world.addComponent(entity, component)
                
                await Logger.shared.info(
                    "Generated \(results.count) audio files for entity \(entity)",
                    category: "Diaplasion"
                )
                
            } catch {
                await Logger.shared.error(
                    "Audio generation failed: \(error)",
                    category: "Diaplasion"
                )
                
                // Add error component
                await world.addComponent(entity, AudioGenerationErrorComponent(
                    error: error.localizedDescription,
                    timestamp: Date()
                ))
            }
        }
    }
    
    private func createOutputDirectory(for entity: EntityID) -> URL {
        let tempDir = FileManager.default.temporaryDirectory
        return tempDir.appendingPathComponent("diaplasion_audio_\(entity)")
    }
}

/// Component containing generated audio files.
public struct GeneratedAudioComponent: Component {
    public let audioFiles: [AudioGenerationResult]
    public let outputDirectory: URL
    public let generationDate: Date
    public let totalDuration: TimeInterval
    public let totalSizeMB: Double
    
    public init(
        audioFiles: [AudioGenerationResult],
        outputDirectory: URL,
        generationDate: Date,
        totalDuration: TimeInterval,
        totalSizeMB: Double
    ) {
        self.audioFiles = audioFiles
        self.outputDirectory = outputDirectory
        self.generationDate = generationDate
        self.totalDuration = totalDuration
        self.totalSizeMB = totalSizeMB
    }
}

/// Component for audio generation errors.
public struct AudioGenerationErrorComponent: Component {
    public let error: String
    public let timestamp: Date
    
    public init(error: String, timestamp: Date) {
        self.error = error
        self.timestamp = timestamp
    }
}

// MARK: - Extensions

extension URL {
    /// Get file size in bytes.
    var fileSize: Int64 {
        do {
            let attributes = try FileManager.default.attributesOfItem(atPath: self.path)
            return attributes[.size] as? Int64 ?? 0
        } catch {
            return 0
        }
    }
}
