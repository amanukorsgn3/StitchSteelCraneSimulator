import AudioToolbox
import UIKit

final class FeedbackService {
    static let shared = FeedbackService()

    private let impact = UIImpactFeedbackGenerator(style: .medium)
    private let heavy = UIImpactFeedbackGenerator(style: .heavy)
    private let note = UINotificationFeedbackGenerator()

    private init() {
        impact.prepare()
        heavy.prepare()
        note.prepare()
    }

    func playSet() {
        playTone(1104)
        if PlayerStore.shared.hapticsEnabled {
            impact.impactOccurred()
            impact.prepare()
        }
    }

    func playDrop() {
        playTone(1053)
        if PlayerStore.shared.hapticsEnabled {
            note.notificationOccurred(.error)
            note.prepare()
        }
    }

    func playClear() {
        playTone(1025)
        if PlayerStore.shared.hapticsEnabled {
            note.notificationOccurred(.success)
            note.prepare()
        }
    }

    func playFail() {
        playTone(1073)
        if PlayerStore.shared.hapticsEnabled {
            heavy.impactOccurred()
            heavy.prepare()
        }
    }

    func previewSound() {
        playTone(1104)
    }

    func previewHaptics() {
        guard PlayerStore.shared.hapticsEnabled else { return }
        impact.impactOccurred()
        impact.prepare()
    }

    private func playTone(_ soundID: SystemSoundID) {
        guard PlayerStore.shared.soundEnabled else { return }
        AudioServicesPlaySystemSound(soundID)
    }
}
