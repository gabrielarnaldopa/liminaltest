import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
import UserNotifications

/// Waits for an answer while the app is closed.
///
/// The server keeps writing the answer (it runs there, not on the phone). When the app goes to the
/// background in the middle of an answer, this starts a background download that waits until the
/// answer is finished. iOS performs it even with the app suspended, then wakes the app briefly:
/// the answer is saved in the chat and a notification says it is ready.
final class BackgroundJobs: NSObject, URLSessionDownloadDelegate, @unchecked Sendable {
    static let shared = BackgroundJobs()
    static let identifier = "app.liminal.answers"

    /// Receives each finished answer: the job id and what the server wrote.
    @MainActor var onFinished: ((String, JobSnapshot) -> Void)?
    private var waiting: [CheckedContinuation<Void, Never>] = []
    private let lock = NSLock()

    private lazy var session: URLSession = {
        #if canImport(FoundationNetworking)
        // Linux checks only: background sessions exist only on Apple platforms.
        let config = URLSessionConfiguration.default
        #else
        let config = URLSessionConfiguration.background(withIdentifier: Self.identifier)
        config.sessionSendsLaunchEvents = true
        config.isDiscretionary = false
        #endif
        return URLSession(configuration: config, delegate: self, delegateQueue: nil)
    }()

    /// Starts waiting for one answer.
    func watch(_ request: URLRequest, jobID: String) {
        let task = session.downloadTask(with: request)
        task.taskDescription = jobID
        task.resume()
    }

    /// Called when iOS wakes the app for these downloads: reconnects and waits until they are delivered.
    func handleEvents() async {
        _ = session
        await withCheckedContinuation { continuation in
            lock.lock()
            waiting.append(continuation)
            lock.unlock()
        }
    }

    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        guard let jobID = downloadTask.taskDescription, let data = try? Data(contentsOf: location),
              let snapshot = LithiumClient.snapshot(from: data) else { return }
        Task { @MainActor in
            self.onFinished?(jobID, snapshot)
        }
    }

    func urlSessionDidFinishEvents(forBackgroundURLSession session: URLSession) {
        lock.lock()
        let done = waiting
        waiting = []
        lock.unlock()
        done.forEach { $0.resume() }
    }
}

/// Local notifications: «Lithium terminó tu respuesta».
enum Notifier {
    /// Asks once, the first time an answer runs on the server.
    static func requestIfNeeded() async {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        if settings.authorizationStatus == .notDetermined {
            _ = try? await center.requestAuthorization(options: [.alert, .sound])
        }
    }

    static func post(title: String, body: String, id: String) async {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        content.threadIdentifier = "answers"
        let request = UNNotificationRequest(identifier: id, content: content, trigger: nil)
        try? await UNUserNotificationCenter.current().add(request)
    }
}
