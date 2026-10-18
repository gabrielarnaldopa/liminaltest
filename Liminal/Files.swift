import SwiftUI
import UIKit
import PDFKit
import AVFoundation
import UniformTypeIdentifiers
import Observation

/// Reads what it can from a file on the device: PDF text and pages, audio length, image size and thumbnail.
/// Word files are read on the server once it is connected.
enum FileReader {
    static func kind(of url: URL) -> FileKind {
        switch url.pathExtension.lowercased() {
        case "pdf": return .pdf
        case "docx", "doc": return .word
        case "mp3", "m4a", "wav", "aac", "ogg", "opus", "caf": return .audio
        case "jpg", "jpeg", "png", "heic", "gif", "webp": return .image
        case "txt", "md", "csv", "json": return .text
        case "xlsx", "xls", "numbers": return .sheet
        default: return .other
        }
    }

    /// Reads a file picked with the Files app. Call off the main thread.
    static func read(url: URL, into attachment: Attachment) async -> Attachment {
        var result = attachment
        let granted = url.startAccessingSecurityScopedResource()
        defer { if granted { url.stopAccessingSecurityScopedResource() } }
        result.size = (try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
        switch result.kind {
        case .pdf:
            if let document = PDFDocument(url: url) {
                result.pages = document.pageCount
                var text = ""
                var index = 0
                while index < min(document.pageCount, 20) && text.count < 8000 {
                    text += (document.page(at: index)?.string ?? "") + "\n"
                    index += 1
                }
                result.text = String(text.prefix(8000)).trimmingCharacters(in: .whitespacesAndNewlines)
            } else {
                result.failed = true
            }
        case .text:
            if let text = try? String(contentsOf: url, encoding: .utf8) {
                result.text = String(text.prefix(8000))
            } else {
                result.failed = true
            }
        case .audio:
            result.duration = await audioDuration(url)
        case .image:
            if let data = try? Data(contentsOf: url), let image = UIImage(data: data) {
                applyImage(image, to: &result)
            } else {
                result.failed = true
            }
        case .word, .sheet, .other:
            break
        }
        result.isReading = false
        return result
    }

    static func audioDuration(_ url: URL) async -> Double {
        let asset = AVURLAsset(url: url)
        guard let duration = try? await asset.load(.duration) else { return 0 }
        let seconds = CMTimeGetSeconds(duration)
        return seconds.isFinite ? seconds : 0
    }

    static func applyImage(_ image: UIImage, to attachment: inout Attachment) {
        attachment.width = Int(image.size.width * image.scale)
        attachment.height = Int(image.size.height * image.scale)
        let side: CGFloat = 96
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: side, height: side))
        let thumb = renderer.image { _ in
            let ratio = max(side / image.size.width, side / image.size.height)
            let size = CGSize(width: image.size.width * ratio, height: image.size.height * ratio)
            image.draw(in: CGRect(x: (side - size.width) / 2, y: (side - size.height) / 2,
                                  width: size.width, height: size.height))
        }
        attachment.thumbnail = thumb.jpegData(compressionQuality: 0.7)
        VisionCache.store(image, for: attachment.id)
    }

    /// An attachment for a photo taken with the camera or chosen in Photos.
    static func photoAttachment(_ image: UIImage, name: String) -> Attachment {
        let data = image.jpegData(compressionQuality: 0.8) ?? Data()
        var attachment = Attachment(name: name, size: data.count, kind: .image)
        applyImage(image, to: &attachment)
        return attachment
    }
}

// MARK: - Voice notes

/// Records a voice note to a temporary file.
@MainActor
@Observable
final class VoiceRecorder {
    private(set) var isRecording = false
    private(set) var startedAt: Date? = nil
    @ObservationIgnored private var recorder: AVAudioRecorder? = nil
    @ObservationIgnored private var fileURL: URL? = nil

    /// Returns false when the microphone is not allowed.
    func start() async -> Bool {
        let allowed = await AVAudioApplication.requestRecordPermission()
        guard allowed else { return false }
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker])
            try session.setActive(true)
            let url = FileManager.default.temporaryDirectory
                .appendingPathComponent("nota-de-voz-\(Int(Date().timeIntervalSince1970)).m4a")
            let settings: [String: Any] = [
                AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
                AVSampleRateKey: 44_100,
                AVNumberOfChannelsKey: 1,
                AVEncoderAudioQualityKey: AVAudioQuality.medium.rawValue
            ]
            let recorder = try AVAudioRecorder(url: url, settings: settings)
            recorder.record()
            self.recorder = recorder
            fileURL = url
            startedAt = Date()
            isRecording = true
            return true
        } catch {
            return false
        }
    }

    /// Stops and returns the voice note as an attachment.
    func stop() -> Attachment? {
        guard let recorder, let fileURL, let startedAt else { return nil }
        recorder.stop()
        self.recorder = nil
        self.startedAt = nil
        isRecording = false
        try? AVAudioSession.sharedInstance().setActive(false)
        let size = (try? fileURL.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
        var attachment = Attachment(name: fileURL.lastPathComponent, size: size, kind: .audio)
        attachment.duration = Date().timeIntervalSince(startedAt)
        return attachment
    }
}

// MARK: - Camera and share sheet

/// Takes a photo with the camera.
struct CameraPicker: UIViewControllerRepresentable {
    var onPhoto: (UIImage) -> Void
    @Environment(\.dismiss) private var dismiss

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = UIImagePickerController.isSourceTypeAvailable(.camera) ? .camera : .photoLibrary
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ controller: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    @MainActor
    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: CameraPicker
        init(_ parent: CameraPicker) { self.parent = parent }

        func imagePickerController(_ picker: UIImagePickerController,
                                   didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            if let image = info[.originalImage] as? UIImage {
                parent.onPhoto(image)
            }
            parent.dismiss()
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
}

/// The iOS share sheet: save to Files, send by WhatsApp, print and more.
struct ShareSheet: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: [url], applicationActivities: nil)
    }

    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}

struct SharedFile: Identifiable {
    let id = UUID()
    let url: URL
}
