//
//  VideoCompressor.swift
//  DualFit
//
//  Handles video compression before upload.
//

import Foundation
import AVFoundation

/// Compresses videos before upload to save bandwidth and storage
struct VideoCompressor {
    
    /// Compression quality preset
    enum CompressionQuality {
        case low        // Smallest file, lower quality
        case medium     // Balance of size and quality
        case high       // Better quality, larger file
        
        var preset: String {
            switch self {
            case .low:
                return AVAssetExportPresetMediumQuality
            case .medium:
                return AVAssetExportPreset960x540
            case .high:
                return AVAssetExportPreset1280x720
            }
        }
    }
    
    /// Compress a video file
    /// - Parameters:
    ///   - inputURL: URL of the source video
    ///   - quality: Compression quality preset
    /// - Returns: URL of the compressed video file
    static func compress(
        videoAt inputURL: URL,
        quality: CompressionQuality = .medium
    ) async throws -> URL {
        let asset = AVURLAsset(url: inputURL)
        
        // Check video duration (max 60 seconds)
        let duration = try await asset.load(.duration)
        let durationSeconds = CMTimeGetSeconds(duration)
        
        if durationSeconds > 60 {
            throw VideoCompressorError.videoTooLong(maxSeconds: 60, actualSeconds: Int(durationSeconds))
        }
        
        // Create export session
        guard let exportSession = AVAssetExportSession(
            asset: asset,
            presetName: quality.preset
        ) else {
            throw VideoCompressorError.exportSessionCreationFailed
        }
        
        // Setup output
        let outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("mp4")
        
        exportSession.outputURL = outputURL
        exportSession.outputFileType = .mp4
        exportSession.shouldOptimizeForNetworkUse = true
        
        // Limit to first 60 seconds if somehow longer
        if durationSeconds > 60 {
            let timeRange = CMTimeRange(
                start: .zero,
                duration: CMTime(seconds: 60, preferredTimescale: 600)
            )
            exportSession.timeRange = timeRange
        }
        
        // Export
        await exportSession.export()
        
        switch exportSession.status {
        case .completed:
            return outputURL
        case .failed:
            throw exportSession.error ?? VideoCompressorError.exportFailed
        case .cancelled:
            throw VideoCompressorError.exportCancelled
        default:
            throw VideoCompressorError.exportFailed
        }
    }
    
    /// Get the file size of a video in MB
    static func fileSize(at url: URL) -> Double {
        guard let attributes = try? FileManager.default.attributesOfItem(atPath: url.path),
              let size = attributes[.size] as? Int64 else {
            return 0
        }
        return Double(size) / (1024 * 1024)
    }
    
    /// Validate a video file
    static func validate(videoAt url: URL) async throws {
        let asset = AVURLAsset(url: url)
        
        // Check if it's a valid video
        let tracks = try await asset.loadTracks(withMediaType: .video)
        if tracks.isEmpty {
            throw VideoCompressorError.invalidVideo
        }
        
        // Check duration
        let duration = try await asset.load(.duration)
        let durationSeconds = CMTimeGetSeconds(duration)
        
        if durationSeconds > 60 {
            throw VideoCompressorError.videoTooLong(maxSeconds: 60, actualSeconds: Int(durationSeconds))
        }
        
        // Check file size (max 100MB before compression)
        let size = fileSize(at: url)
        if size > 100 {
            throw VideoCompressorError.fileTooLarge(maxMB: 100, actualMB: Int(size))
        }
    }
}

/// Errors that can occur during video compression
enum VideoCompressorError: LocalizedError {
    case videoTooLong(maxSeconds: Int, actualSeconds: Int)
    case fileTooLarge(maxMB: Int, actualMB: Int)
    case invalidVideo
    case exportSessionCreationFailed
    case exportFailed
    case exportCancelled
    
    var errorDescription: String? {
        switch self {
        case .videoTooLong(let max, let actual):
            return "Video is too long (\(actual)s). Maximum allowed is \(max) seconds."
        case .fileTooLarge(let max, let actual):
            return "File is too large (\(actual)MB). Maximum allowed is \(max)MB."
        case .invalidVideo:
            return "The selected file is not a valid video."
        case .exportSessionCreationFailed:
            return "Failed to create video export session."
        case .exportFailed:
            return "Failed to compress video."
        case .exportCancelled:
            return "Video compression was cancelled."
        }
    }
}

