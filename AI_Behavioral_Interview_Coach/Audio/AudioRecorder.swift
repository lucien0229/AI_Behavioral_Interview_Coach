import AVFoundation
import Foundation
import Observation

@MainActor
@Observable
final class AudioRecorder {
    enum PermissionState: Equatable {
        case unknown
        case granted
        case denied
    }

    enum RecordingState: Equatable {
        case idle
        case recording
        case recorded(URL)
        case playing
    }

    let minimumDuration: TimeInterval = 2

    var permissionState: PermissionState = .unknown
    var recordingState: RecordingState = .idle
    var elapsedSeconds: TimeInterval = 0

    var canSubmit: Bool {
        if case .recorded = recordingState {
            return elapsedSeconds >= minimumDuration
        }
        return false
    }

    @ObservationIgnored private var recorder: AVAudioRecorder?
    @ObservationIgnored private var player: AVAudioPlayer?
    @ObservationIgnored private var recordingTimer: Timer?
    @ObservationIgnored private var currentRecordingURL: URL?
    @ObservationIgnored private var playbackDelegate: PlaybackDelegate?

    func requestPermission() async {
        let granted = await requestSystemPermission()
        permissionState = granted ? .granted : .denied
    }

    func startRecording() {
        guard permissionState == .granted else { return }

        cleanupRecording()

        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("audio-recorder-\(UUID().uuidString)")
            .appendingPathExtension("m4a")

        do {
            try activateAudioSession()

            let settings: [String: Any] = [
                AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
                AVSampleRateKey: 44_100,
                AVNumberOfChannelsKey: 1,
                AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
            ]

            let recorder = try AVAudioRecorder(url: url, settings: settings)
            guard recorder.prepareToRecord(), recorder.record() else {
                try? FileManager.default.removeItem(at: url)
                deactivateAudioSession()
                recordingState = .idle
                elapsedSeconds = 0
                return
            }

            currentRecordingURL = url
            self.recorder = recorder
            elapsedSeconds = 0
            recordingState = .recording
            startRecordingTimer()
        } catch {
            try? FileManager.default.removeItem(at: url)
            recorder = nil
            currentRecordingURL = nil
            elapsedSeconds = 0
            recordingState = .idle
            deactivateAudioSession()
        }
    }

    func stopRecording() {
        guard case .recording = recordingState else { return }

        stopRecordingTimer()

        let recorder = self.recorder
        self.recorder = nil
        recorder?.stop()

        let duration = max(elapsedSeconds, recorder?.currentTime ?? 0)
        elapsedSeconds = duration

        if let url = currentRecordingURL, FileManager.default.fileExists(atPath: url.path) {
            recordingState = .recorded(url)
        } else {
            cleanupRecording()
        }

        deactivateAudioSession()
    }

    func playRecording() {
        guard case .recorded(let url) = recordingState else { return }
        guard FileManager.default.fileExists(atPath: url.path) else {
            cleanupRecording()
            return
        }

        stopPlayback()

        do {
            try activateAudioSession()

            let player = try AVAudioPlayer(contentsOf: url)
            let delegate = PlaybackDelegate(owner: self)
            player.delegate = delegate
            guard player.prepareToPlay(), player.play() else {
                self.player = nil
                playbackDelegate = nil
                recordingState = .recorded(url)
                deactivateAudioSession()
                return
            }

            self.player = player
            playbackDelegate = delegate
            recordingState = .playing
        } catch {
            self.player = nil
            playbackDelegate = nil
            recordingState = .recorded(url)
            deactivateAudioSession()
        }
    }

    func stopPlayback() {
        guard player != nil || isPlaying else {
            if case .playing = recordingState, let url = currentRecordingURL {
                recordingState = .recorded(url)
            }
            return
        }

        player?.stop()
        player = nil
        playbackDelegate = nil

        if let url = currentRecordingURL {
            recordingState = .recorded(url)
        } else {
            recordingState = .idle
        }

        deactivateAudioSession()
    }

    func rerecord() {
        cleanupRecording()
    }

    func cleanupRecording() {
        stopRecordingTimer()
        recorder?.stop()
        recorder = nil
        stopPlayback()

        if let url = currentRecordingURL {
            try? FileManager.default.removeItem(at: url)
        } else if case .recorded(let url) = recordingState {
            try? FileManager.default.removeItem(at: url)
        }

        currentRecordingURL = nil
        elapsedSeconds = 0
        recordingState = .idle
        deactivateAudioSession()
    }

    private var isPlaying: Bool {
        if case .playing = recordingState {
            return true
        }
        return false
    }

    private func startRecordingTimer() {
        recordingTimer?.invalidate()
        recordingTimer = Timer.scheduledTimer(withTimeInterval: 0.2, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.updateElapsedTime()
            }
        }
    }

    private func stopRecordingTimer() {
        recordingTimer?.invalidate()
        recordingTimer = nil
    }

    private func updateElapsedTime() {
        guard case .recording = recordingState, let recorder else { return }
        elapsedSeconds = recorder.currentTime
    }

    private func finishPlayback() {
        let url = currentRecordingURL ?? player?.url
        player = nil
        playbackDelegate = nil

        if let url, FileManager.default.fileExists(atPath: url.path) {
            recordingState = .recorded(url)
        } else {
            currentRecordingURL = nil
            elapsedSeconds = 0
            recordingState = .idle
        }

        deactivateAudioSession()
    }

    private func deactivateAudioSession() {
        #if os(iOS)
        try? AVAudioSession.sharedInstance().setActive(false, options: [.notifyOthersOnDeactivation])
        #endif
    }

    private func activateAudioSession() throws {
        #if os(iOS)
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playAndRecord, mode: .spokenAudio, options: [.defaultToSpeaker])
        try session.setActive(true)
        #endif
    }

    private func requestSystemPermission() async -> Bool {
        #if os(iOS)
        if #available(iOS 17.0, *) {
            return await AVAudioApplication.requestRecordPermission()
        } else {
            return await withCheckedContinuation { continuation in
                AVAudioSession.sharedInstance().requestRecordPermission { granted in
                    continuation.resume(returning: granted)
                }
            }
        }
        #else
        return false
        #endif
    }

    private final class PlaybackDelegate: NSObject, AVAudioPlayerDelegate {
        weak var owner: AudioRecorder?

        init(owner: AudioRecorder) {
            self.owner = owner
        }

        func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
            let url = player.url
            Task { @MainActor [weak owner] in
                owner?.handlePlaybackFinished(url: url, successfully: flag)
            }
        }

        func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: Error?) {
            let url = player.url
            Task { @MainActor [weak owner] in
                owner?.handlePlaybackFinished(url: url, successfully: false)
            }
        }
    }

    private func handlePlaybackFinished(url: URL?, successfully: Bool) {
        if !successfully {
            finishPlayback()
            return
        }

        if let url, FileManager.default.fileExists(atPath: url.path) {
            currentRecordingURL = url
        }

        finishPlayback()
    }
}
