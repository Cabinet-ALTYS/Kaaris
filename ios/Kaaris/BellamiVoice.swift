import AVFoundation
import Foundation

enum BellamiVoice {
    private enum Tone: String {
        case neutral, direct, intense
    }

    static func makePlayer(for phase: CoachVoicePhase, preferences: CoachPreferences) -> AVAudioPlayer? {
        let tone = tone(for: preferences)
        guard let clip = url(for: phase, tone: tone) ?? url(for: phase, tone: .neutral) else { return nil }
        return try? AVAudioPlayer(contentsOf: clip)
    }

    private static func tone(for preferences: CoachPreferences) -> Tone {
        guard preferences.bluntConsent else { return .neutral }
        switch preferences.effectiveLanguageIntensity {
        case 3...: return .intense
        case 1...2: return .direct
        default: return .neutral
        }
    }

    private static func url(for phase: CoachVoicePhase, tone: Tone) -> URL? {
        let resource = "bellami-\(phase.rawValue)-\(tone.rawValue)"
        return Bundle.main.url(forResource: resource, withExtension: "mp3")
            ?? Bundle.main.url(forResource: resource, withExtension: "mp3", subdirectory: "CoachVoice")
    }
}
