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
    private let defaultVideoQuality = AVAssetExportPresetMediumQuality

    override public func load() {
        super.load()
        NotificationCenter.default.addObserver(self, selector: #selector(handleMemoryWarning), name: UIApplication.didReceiveMemoryWarningNotification, object: nil)
        print("UPLOADLARGEFILE Memory warning observer registered")
    }

    @objc private func handleMemoryWarning() {
        print("UPLOADLARGEFILE Memory warning received, cleaning up resources.")
        cleanupMemory()
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
                let sanitizedPath = filePath.hasPrefix("file://") ? String(filePath.dropFirst(7)) : filePath
                let decodedPath = sanitizedPath.removingPercentEncoding ?? sanitizedPath
                
                guard FileManager.default.fileExists(atPath: decodedPath) else {
                    call.reject("File does not exist at path: \(decodedPath)")
                    return
                }

                let persistentUrl = try copyToPersistentLocation(tempPath: decodedPath)
                logMemoryUsage()

                let result = try await processFileInBackground(fileUrl: persistentUrl, fileType: fileType, fileNamePrefix: fileNamePrefix)

                cleanupMemory()

                DispatchQueue.main.async {
                    call.resolve(result)
                }
            } catch {
                DispatchQueue.main.async {
                    call.reject("Error processing media file: \(error.localizedDescription)")
                }
                cleanupMemory()
            }
        }
    }

    private func processFileInBackground(fileUrl: URL, fileType: String, fileNamePrefix: String) async throws -> [String: Any] {
        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                autoreleasepool {
                    guard let self = self else { return }
                    do {
                        var fileData = Data()

                        // Process file in chunks to avoid memory spikes
                        let fileHandle = try FileHandle(forReadingFrom: fileUrl)
                        let chunkSize = 10 * 1024 * 1024 // Process 10MB at a time

                        while autoreleasepool(invoking: {
                            let chunk = fileHandle.readData(ofLength: chunkSize)
                            if chunk.isEmpty { return false }
                            fileData.append(chunk)
                            return true
                        }) {}
                        fileHandle.closeFile()

                        if fileType.lowercased() == "mp4" || fileType.lowercased() == "mov" {
                            if let resizedData = try? self.resizeVideo(inputUrl: fileUrl, targetWidth: 640, targetHeight: 480, quality: self.defaultVideoQuality) {
                                fileData = resizedData
                            } else {
                                throw NSError(domain: "ResizingError", code: -1, userInfo: [NSLocalizedDescriptionKey: "Resizing failed"])
                            }
                        }

                        let size = fileData.count
                        let timestamp = Int(Date().timeIntervalSince1970)
                        let finalFileName = "\(fileNamePrefix)_\(timestamp).\(fileType)"

                        let byteArray = [UInt8](fileData)

                        fileData.removeAll(keepingCapacity: false)

                        let result: [String: Any] = [
                            "size": size,
                            "type": fileType,
                            "fileName": finalFileName,
                            "byteArray": byteArray
                        ]

                        self.logMemoryUsage()
                        continuation.resume(returning: result)
                    } catch {
                        continuation.resume(throwing: error)
                    }
                }
            }
        }
    }

    private func copyToPersistentLocation(tempPath: String) throws -> URL {
        let fileManager = FileManager.default
        let tempUrl = URL(fileURLWithPath: tempPath)
        let documentsDirectory = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
        let destinationUrl = documentsDirectory.appendingPathComponent(tempUrl.lastPathComponent)

        if fileManager.fileExists(atPath: destinationUrl.path) {
            try fileManager.removeItem(at: destinationUrl)
        }

        try fileManager.copyItem(at: tempUrl, to: destinationUrl)
        return destinationUrl
    }

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
            print("UPLOADLARGEFILE Used memory: \(usedMemoryMB) MB")
        } else {
            print("UPLOADLARGEFILE Error retrieving memory info")
        }
    }

    private func cleanupMemory() {
        DispatchQueue.global(qos: .background).async {
            print("UPLOADLARGEFILE Performing memory cleanup...")
            URLCache.shared.removeAllCachedResponses()
            let tempDirectory = FileManager.default.temporaryDirectory
            do {
                let tempFiles = try FileManager.default.contentsOfDirectory(at: tempDirectory, includingPropertiesForKeys: nil)
                for file in tempFiles {
                    try FileManager.default.removeItem(at: file)
                }
                print("UPLOADLARGEFILE Temporary files cleaned.")
            } catch {
                print("UPLOADLARGEFILE Error cleaning temp files:", error.localizedDescription)
            }
            print("UPLOADLARGEFILE Memory cleanup completed.")
        }
    }

    private func resizeVideo(inputUrl: URL, targetWidth: CGFloat, targetHeight: CGFloat, quality: String) throws -> Data {
        let asset = AVURLAsset(url: inputUrl)
        guard let exportSession = AVAssetExportSession(asset: asset, presetName: quality) else {
            throw NSError(domain: "VideoResizing", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to create AVAssetExportSession"])
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
            let resizedData = try Data(contentsOf: tempFileUrl)
            try FileManager.default.removeItem(at: tempFileUrl)
            print("UPLOADLARGEFILE Video resized successfully to \(targetWidth)x\(targetHeight)")
            return resizedData
        } else {
            throw NSError(domain: "VideoResizing", code: -1, userInfo: [NSLocalizedDescriptionKey: exportSession.error?.localizedDescription ?? "Unknown error"])
        }
    }
}
