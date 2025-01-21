import Foundation
import AVFoundation
import Capacitor
import MachO

@objc(FileuploadPluginPlugin)
public class FileuploadPluginPlugin: CAPPlugin, CAPBridgedPlugin {
    public let identifier = "FileuploadPluginPlugin"
    public let jsName = "FileuploadPlugin"
    public let pluginMethods: [CAPPluginMethod] = [
        CAPPluginMethod(name: "processFile", returnType: CAPPluginReturnPromise)
    ]
    private let defaultVideoQuality = AVAssetExportPresetLowQuality  // Set default quality
    override public func load() {
        super.load()
        NotificationCenter.default.addObserver(self, selector: #selector(handleMemoryWarning), name: UIApplication.didReceiveMemoryWarningNotification, object: nil)
        print("Memory warning observer registered")
    }
    @objc private func handleMemoryWarning() {
        print("Memory warning received, cleaning up resources.")
        cleanupMemory()  // Call cleanup method to release memory
    }


    @objc func processFile(_ call: CAPPluginCall) {
        guard let filePath = call.getString("filePath"),
              let fileType = call.getString("type"),
              let fileNamePrefix = call.getString("name") else {
            call.reject("File path, type, and name are required")
            return
        }

        Task(priority: .background) {
            do {
                print("Original filePath:", filePath)

                // Remove `file://` prefix if present
                let sanitizedPath = filePath.hasPrefix("file://") ? String(filePath.dropFirst(7)) : filePath
                let decodedPath = sanitizedPath.removingPercentEncoding ?? sanitizedPath
                print("Decoded filePath:", decodedPath)

                // Ensure the file exists
                guard FileManager.default.fileExists(atPath: decodedPath) else {
                    call.reject("File does not exist at path: \(decodedPath)")
                    return
                }

                // Copy the file to a persistent location
                let persistentUrl = try copyToPersistentLocation(tempPath: decodedPath)
                print("Persistent file path:", persistentUrl.path)

                logMemoryUsage()  // Track memory before processing

                // Process the file
                let result = try await processFileInBackground(fileUrl: persistentUrl, fileType: fileType, fileNamePrefix: fileNamePrefix)

                logMemoryUsage()  // Track memory after processing

                cleanupMemory()  // Free up memory

                DispatchQueue.main.async {
                    call.resolve(result)
                }
            } catch {
                print("Error processing media file:", error.localizedDescription)
                DispatchQueue.main.async {
                    call.reject("Error processing media file: \(error.localizedDescription)")
                }
                cleanupMemory()  // Free memory on error
            }
        }
    }

    // Function to process file in background asynchronously
    private func processFileInBackground(fileUrl: URL, fileType: String, fileNamePrefix: String) async throws -> [String: Any] {
        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async { [self] in
                autoreleasepool {
                    do {
                        var fileData: Data

                        // Simulate potential crash scenario by allocating large memory chunk
                        print("Allocating large memory chunk...")
                        var largeMemoryChunk: [UInt8]? = nil

                        do {
                            largeMemoryChunk = [UInt8](repeating: 0, count: 100_000_000) // Allocate 100MB
                            print("Memory chunk allocated successfully.")
                        } catch {
                            print("Failed to allocate large memory chunk, freeing resources.")
                            largeMemoryChunk = nil  // Release allocated memory if an error occurs
                            throw NSError(domain: "MemoryAllocationError", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to allocate memory"])
                        }

                        // Compress video if it's a supported format
                        if fileType.lowercased() == "mp4" || fileType.lowercased() == "mov" {
                            if let compressedData = try? self.compressVideo(inputUrl: fileUrl, quality: defaultVideoQuality) {
                                fileData = compressedData
                            } else {
                                throw NSError(domain: "CompressionError", code: -1, userInfo: [NSLocalizedDescriptionKey: "Compression failed"])
                            }
                        } else {
                            // Read file in chunks to optimize memory usage
                            fileData = try Data(contentsOf: fileUrl)
                        }

                        let size = fileData.count
                        let timestamp = Int(Date().timeIntervalSince1970)
                        let finalFileName = "\(fileNamePrefix)_\(timestamp).\(fileType)"

                        // Convert file data to byte array
                        let byteArray = [UInt8](fileData)

                        // Clear file data memory
                        fileData.removeAll()
                        largeMemoryChunk?.removeAll()  // Free allocated memory chunk
                        largeMemoryChunk = nil  // Ensure memory is freed

                        let result: [String: Any] = [
                            "size": size,
                            "type": fileType,
                            "fileName": finalFileName,
                            "byteArray": byteArray
                        ]

                        logMemoryUsage()
                        continuation.resume(returning: result)
                    } catch {
                        continuation.resume(throwing: error)
                    }
                }
            }
        }
    }

      // Function to compress video with configurable quality
    private func compressVideo(inputUrl: URL, quality: String) throws -> Data {
        let asset = AVURLAsset(url: inputUrl)
        guard let exportSession = AVAssetExportSession(asset: asset, presetName: quality) else {
            throw NSError(domain: "VideoCompression", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to create AVAssetExportSession"])
        }

        let tempFileUrl = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString + ".mp4")
        exportSession.outputURL = tempFileUrl
        exportSession.outputFileType = .mp4
        exportSession.shouldOptimizeForNetworkUse = true

        let semaphore = DispatchSemaphore(value: 0)
        exportSession.exportAsynchronously {
            semaphore.signal()
        }

        semaphore.wait()

        if exportSession.status == .completed {
            let compressedData = try Data(contentsOf: tempFileUrl)
            try FileManager.default.removeItem(at: tempFileUrl) // Cleanup the temporary file
            print("Video compression successful with quality: \(quality)")
            return compressedData
        } else {
            throw NSError(domain: "VideoCompression", code: -1, userInfo: [NSLocalizedDescriptionKey: exportSession.error?.localizedDescription ?? "Unknown error"])
        }
    }

    // Function to copy file to persistent storage location
    private func copyToPersistentLocation(tempPath: String) throws -> URL {
        let fileManager = FileManager.default
        let tempUrl = URL(fileURLWithPath: tempPath)
        let documentsDirectory = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
        let destinationUrl = documentsDirectory.appendingPathComponent(tempUrl.lastPathComponent)

        if fileManager.fileExists(atPath: destinationUrl.path) {
            try fileManager.removeItem(at: destinationUrl)
        }

        try fileManager.copyItem(at: tempUrl, to: destinationUrl)

        print("File copied to persistent location:", destinationUrl.path)
        return destinationUrl
    }

    // Function to log memory usage
    private func logMemoryUsage() {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size) / 4

        let result: kern_return_t = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }

        if result == KERN_SUCCESS {
            let usedMemoryMB = info.resident_size / (1024 * 1024)
            print("Used memory: \(usedMemoryMB) MB")
        } else {
            print("Error retrieving memory info")
        }
    }

    // Function to clean up memory
    private func cleanupMemory() {
        DispatchQueue.global(qos: .background).async {
            print("Performing memory cleanup...")
            
            // Clear the URL cache
            URLCache.shared.removeAllCachedResponses()

            // Remove temporary files
            let tempDirectory = FileManager.default.temporaryDirectory
            do {
                let tempFiles = try FileManager.default.contentsOfDirectory(at: tempDirectory, includingPropertiesForKeys: nil)
                for file in tempFiles {
                    try FileManager.default.removeItem(at: file)
                }
                print("Temporary files cleaned.")
            } catch {
                print("Error cleaning temp files:", error.localizedDescription)
            }

            print("Memory cleanup completed.")
        }
    }

}

