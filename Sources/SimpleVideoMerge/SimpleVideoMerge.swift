//
//  SimpleVideoMerge.swift
//  SimpleVideoMerge
//
//  Created by Dustin Herschberger on 8/5/24.
//

import AVFoundation
import Foundation

/// This class implements the ability to merge multiple video files into a single video file.
class SimpleVideoMerge {
    /// Creates a list of ``AVAsset`` objects for a given list of files.
    ///
    /// Performs some basic checks on the input URLs and generates a list of AVAssets that appear to be valid.
    /// This will likely be moved and/or completely re-written in the future, but will work as a starting point.
    /// The intention is the URLs provided are the source videos to be merged together, in the order that they should
    /// be merged in.
    /// - Note: The application must have permission to access the URLs to ultimately be able to read the source files!
    /// - Parameter videoURLs: A list of ``URL`` objects that represent video files to be merged.
    /// - Returns: A list of ``AVAsset`` objects for each valid URL from the input. Invalid URLs will be skipped!
    private func getVideoAssets(videoURLs: [URL]) -> [AVAsset] {
        // For now, compatible with only these input source video types.
        let acceptableVideoExtensions = ["mov", "mp4", "m4v"]

        // Filter the URLs provided to get only the ones that have the appropriate extension.
        let filteredUrls = videoURLs.filter { vidUrl in
            // If one of the inputs is just empty, it's not valid for this.
            if vidUrl.absoluteString.isEmpty {
                return false
            }

            // If one of the inputs doesn't have the correct extension, ignore it.
            // This isn't protecting against the wrong extension on a given file or other issues.
            if !acceptableVideoExtensions.contains(vidUrl.pathExtension.lowercased()) {
                return false
            }

            // URL passed the basic checks.
            return true
        }

        // Create the AVAsset objects for the URLs that appear to be valid.
        var vidAssets: [AVAsset] = []

        for url in filteredUrls {
            vidAssets.append(AVAsset(url: url))
        }
        return vidAssets
    }

    /// Gets a file URL for the merged video.
    ///
    /// The file will be in the typical "Movies" folder in the user home directory.
    /// Later this will be moved to a property so that the user can specify the path.
    /// - Note: The application must have write permission to the location where the file will be stored.
    /// - Returns: A URL for the merged video file if the file does not already exist. If it does exist, returns `nil`.
    private func getOutputPath() -> URL? {
        // For now, just put it in the typical "Movies" dir.
        let fileMgr = FileManager.default
        let moviesDir = URL(fileURLWithPath: "/Users/dustin/Movies/", isDirectory: true)

        // To help avoid dealing with issues like the file already exists from a previous test,
        // create a random filename based on the current time.
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd-HH-mm-ss"
        let fileName = dateFormatter.string(from: Date())
        let outputPath = moviesDir.appending(component: fileName).appendingPathExtension(for: .mpeg4Movie)
        if fileMgr.fileExists(atPath: outputPath.absoluteString) {
            return nil
        }
        return outputPath
    }

    /// Merge the videos at the paths provided by the input parameter in the order they are listed.
    ///
    /// Currently this provides no way to specify the path of the resulting file nor any way to customize
    /// any of the parameters such as video quality, add/remove audio, etc.
    ///
    /// Also, this provides no indication of errors or progress of creating files.
    ///
    /// If there is an error, it will silently be ignored.
    /// - Parameter videoURLs: All of the source files to be merged.
    public func mergeVideos(videoURLs: [URL]) async {
        // Convert the input URLs into AVAsset objects.
        let videoAssets = getVideoAssets(videoURLs: videoURLs)

        // Need to have at least 2 files to be able to merge.
        guard videoAssets.count > 1 else { return }

        // For now, we auto-create the output path.
        guard let fileOutputPath = getOutputPath() else { return }

        // File output shouldn't be one of the inputs.
        guard !videoURLs.contains(fileOutputPath) else { return }

        // The composition is the output file. Add video and audio tracks.
        let composition = AVMutableComposition()

        guard let videoTrack = composition.addMutableTrack(withMediaType: .video,
                                                           preferredTrackID: kCMPersistentTrackID_Invalid) else {
            return
        }

        guard let audioTrack = composition.addMutableTrack(withMediaType: .audio,
                                                           preferredTrackID: kCMPersistentTrackID_Invalid) else {
            return
        }

        // The first video will be inserted at the beginning of the composition.
        var insertTime = CMTime(seconds: 0, preferredTimescale: 1)

        // For each source file, add the video and audio tracks to the composition.
        for sourceAsset in videoAssets {
            do {
                // Need to know the duration of the source video.
                // Transform might be important but I'm not sure yet.
                // Get both properties in a single shot since it's an asynchronous task.
                let (duration, transform) = try await sourceAsset.load(.duration, .preferredTransform)

                // My test files from a camera all have a single black frame at the end. I think they are
                // 30 fps so try to get the entire source except the last frame. This is something that can
                // be converted into a customization feature at some point.
                let modifiedDuration = duration - CMTimeMake(value: 1, timescale: 30)

                // Create a time range that identifies the start and end point in the source file.
                let frameTimeRange = CMTimeRange(start: CMTime.zero, duration: modifiedDuration)

                // Load the video track of the source file.
                if let assetVideoTrack = try await sourceAsset.loadTracks(withMediaType: .video).first {
                    // A video track was loaded, so insert it into the composition.
                    try videoTrack.insertTimeRange(frameTimeRange, of: assetVideoTrack, at: insertTime)
                    videoTrack.preferredTransform = transform // Maybe this should be before inserting the track?
                }

                // Load the audio track of the source file.
                if let assetAudioTrack = try await sourceAsset.loadTracks(withMediaType: .audio).first {
                    // An audio track was loaded, so insert it into the composition.
                    try audioTrack.insertTimeRange(frameTimeRange, of: assetAudioTrack, at: insertTime)
                }

                // The next file should be inserted at the end of the file that was just inserted.
                insertTime = insertTime + modifiedDuration
            }
            catch {
                // No fancy error handling here yet.
                print("asset errors: \(error)")
            }
        }

        // The composition has been created, but the composition now needs to be exported.
        if let exportSession = AVAssetExportSession(asset: composition, presetName: AVAssetExportPresetHighestQuality) {
            exportSession.shouldOptimizeForNetworkUse = false // Not really sure what this does. An example I saw had this set true.
            exportSession.outputFileType = .mp4
            exportSession.outputURL = fileOutputPath
            await exportSession.export() // Starts the exporting! Can take a while!
        }
    }
}
