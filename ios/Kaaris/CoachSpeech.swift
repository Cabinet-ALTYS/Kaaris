import AVFoundation
import Combine
import Speech
import UIKit

@MainActor
final class CoachSpeech: NSObject, ObservableObject, AVSpeechSynthesizerDelegate {
    enum Permission: Equatable {
        case notDetermined, requesting, granted, denied, unavailable
    }

    @Published private(set) var transcript = ""
    @Published private(set) var recording = false
    @Published private(set) var finishing = false
    @Published private(set) var permission: Permission = .notDetermined
    @Published private(set) var errorMessage: String?
    @Published private(set) var speaking = false

    static let dynamicVoiceName = "Voix iOS"

    private let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "fr-FR"))
    private let speaker = AVSpeechSynthesizer()
    private var speechID: ObjectIdentifier?
    private var capture: Capture?
    private var recognitionID: UUID?
    private var permissionTask: Task<Void, Never>?
    private var deadline: Task<Void, Never>?
    private var observations: Set<AnyCancellable> = []

    override init() {
        super.init()
        permission = Self.authorization()
        speaker.usesApplicationAudioSession = false
        speaker.delegate = self

        NotificationCenter.default.publisher(for: UIApplication.didEnterBackgroundNotification)
            .sink { [weak self] _ in
                Task { @MainActor [weak self] in self?.cancel() }
            }
            .store(in: &observations)
        NotificationCenter.default.publisher(for: AVAudioSession.interruptionNotification)
            .sink { [weak self] notification in
                guard let type = notification.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt,
                      type == AVAudioSession.InterruptionType.began.rawValue else { return }
                Task { @MainActor [weak self] in self?.cancel() }
            }
            .store(in: &observations)
        NotificationCenter.default.publisher(for: AVAudioSession.mediaServicesWereResetNotification)
            .sink { [weak self] _ in
                Task { @MainActor [weak self] in self?.cancel() }
            }
            .store(in: &observations)
    }

    func start() {
        guard !recording, permissionTask == nil else { return }
        stopSpeaking()
        clearCapture()
        errorMessage = nil

        let id = UUID()
        recognitionID = id
        permission = .requesting
        permissionTask = Task { [weak self] in
            let status = await Self.requestPermissions()
            guard let self, self.recognitionID == id, !Task.isCancelled else { return }
            self.permissionTask = nil
            self.permission = status
            guard status == .granted else {
                self.recognitionID = nil
                self.errorMessage = "Autorise le microphone et la reconnaissance vocale dans les réglages iOS."
                return
            }
            self.startCapture(id: id)
        }
    }

    func stop() {
        if permissionTask != nil {
            clearCapture()
            permission = Self.authorization()
            return
        }
        guard recording, let id = recognitionID else { return }
        capture?.finishInput()
        recording = false
        finishing = true
        scheduleDeadline(after: .milliseconds(850), id: id) { speech in
            speech.finishRecognition()
        }
    }

    func cancel() {
        clearCapture()
        if permission == .requesting {
            permission = Self.authorization()
        }
        stopSpeaking()
    }

    func speak(_ text: String) {
        guard !recording, permissionTask == nil else { return }
        let text = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, let voice = AVSpeechSynthesisVoice(language: "fr-FR") else { return }
        stopSpeaking()
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = voice
        utterance.rate = 0.47
        speechID = ObjectIdentifier(utterance)
        speaking = true
        speaker.speak(utterance)
    }

    func stopSpeaking() {
        speechID = nil
        speaker.stopSpeaking(at: .immediate)
        speaking = false
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        handleSpeechEnd(ObjectIdentifier(utterance))
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        handleSpeechEnd(ObjectIdentifier(utterance))
    }

    private nonisolated func handleSpeechEnd(_ id: ObjectIdentifier) {
        Task { @MainActor [weak self] in
            guard let self, self.speechID == id else { return }
            self.speechID = nil
            self.speaking = false
        }
    }

    private static func authorization() -> Permission {
        let speech = SFSpeechRecognizer.authorizationStatus()
        let microphone = AVAudioApplication.shared.recordPermission
        if speech == .denied || speech == .restricted || microphone == .denied { return .denied }
        if speech == .authorized && microphone == .granted { return .granted }
        return .notDetermined
    }

    private static func requestPermissions() async -> Permission {
        let current = authorization()
        guard current == .notDetermined else { return current }
        if AVAudioApplication.shared.recordPermission == .undetermined {
            guard await AVAudioApplication.requestRecordPermission(), !Task.isCancelled else { return .denied }
        }
        if SFSpeechRecognizer.authorizationStatus() == .notDetermined {
            let speech = await withCheckedContinuation { continuation in
                SFSpeechRecognizer.requestAuthorization { continuation.resume(returning: $0) }
            }
            guard speech == .authorized else { return .denied }
        }
        return authorization()
    }

    private func startCapture(id: UUID) {
        guard let recognizer, recognizer.supportsOnDeviceRecognition, recognizer.isAvailable else {
            recognitionID = nil
            permission = .unavailable
            errorMessage = "La dictée locale en français est indisponible sur cet appareil."
            return
        }

        let capture = Capture()
        self.capture = capture
        capture.task = recognizer.recognitionTask(with: capture.request) { [weak self] result, error in
            let text = result?.bestTranscription.formattedString
            let finished = result?.isFinal == true || error != nil
            Task { @MainActor [weak self] in
                guard let self, self.recognitionID == id else { return }
                if let text, !text.isEmpty {
                    self.transcript = text
                }
                if finished {
                    self.finishRecognition()
                }
            }
        }

        do {
            try capture.startInput()
            transcript = ""
            recording = true
            scheduleDeadline(after: .seconds(25), id: id) { $0.stop() }
        } catch {
            clearCapture()
            errorMessage = "Le microphone est indisponible pour le moment."
        }
    }

    private func finishRecognition() {
        clearCapture()
        if transcript.isEmpty {
            errorMessage = "Aucun mot reconnu. Tu peux dicter à nouveau ou écrire."
        }
    }

    private func scheduleDeadline(after duration: Duration, id: UUID, action: @escaping @MainActor (CoachSpeech) -> Void) {
        deadline?.cancel()
        deadline = Task { [weak self] in
            do {
                try await Task.sleep(for: duration)
            } catch {
                return
            }
            guard let self, self.recognitionID == id else { return }
            action(self)
        }
    }

    private func clearCapture() {
        recognitionID = nil
        permissionTask?.cancel()
        permissionTask = nil
        deadline?.cancel()
        deadline = nil
        capture?.cancel()
        capture = nil
        recording = false
        finishing = false
    }

    private final class Capture {
        let request = SFSpeechAudioBufferRecognitionRequest()
        var task: SFSpeechRecognitionTask?

        private let engine = AVAudioEngine()
        private let session = AVAudioSession.sharedInstance()
        private let oldCategory: AVAudioSession.Category
        private let oldMode: AVAudioSession.Mode
        private let oldOptions: AVAudioSession.CategoryOptions
        private var changedCategory = false
        private var activatedSession = false
        private var installedTap = false
        private var endedInput = false

        init() {
            oldCategory = session.category
            oldMode = session.mode
            oldOptions = session.categoryOptions
            request.requiresOnDeviceRecognition = true
            request.shouldReportPartialResults = true
            request.taskHint = .dictation
        }

        func startInput() throws {
            try session.setCategory(.record, mode: .measurement)
            changedCategory = true
            try session.setActive(true)
            activatedSession = true
            let input = engine.inputNode
            let format = input.outputFormat(forBus: 0)
            guard format.sampleRate > 0, format.channelCount > 0 else { throw InputError.noRoute }
            input.installTap(onBus: 0, bufferSize: 1024, format: format) { [request] buffer, _ in
                request.append(buffer)
            }
            installedTap = true
            engine.prepare()
            try engine.start()
        }

        func finishInput() {
            guard !endedInput else { return }
            endedInput = true
            engine.stop()
            if installedTap {
                engine.inputNode.removeTap(onBus: 0)
                installedTap = false
            }
            request.endAudio()
            if activatedSession {
                try? session.setActive(false, options: .notifyOthersOnDeactivation)
                activatedSession = false
            }
            if changedCategory {
                try? session.setCategory(oldCategory, mode: oldMode, options: oldOptions)
                changedCategory = false
            }
        }

        func cancel() {
            finishInput()
            task?.cancel()
            task = nil
        }

        deinit {
            cancel()
        }

        private enum InputError: Error {
            case noRoute
        }
    }
}
