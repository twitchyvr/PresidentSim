import Foundation
import AVFoundation

// MARK: - Speech Service
// Handles text-to-speech for speeches and announcements

class SpeechService {
    private let synthesizer = AVSpeechSynthesizer()

    var isSpeaking: Bool {
        synthesizer.isSpeaking
    }

    func speak(_ text: String, rate: Float = 0.5, voice: AVSpeechSynthesisVoice? = nil) {
        stop()

        let utterance = AVSpeechUtterance(string: text)
        utterance.rate = rate
        utterance.pitchMultiplier = 1.0
        utterance.volume = 1.0

        // Use default voice if not specified
        let selectedVoice = voice ?? AVSpeechSynthesisVoice(language: "en-US")
        utterance.voice = selectedVoice

        synthesizer.speak(utterance)
    }

    func speakDraftSpeech(_ speech: String) {
        // Slightly slower rate for formal speeches
        speak(speech, rate: 0.45)
    }

    func stop() {
        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }
    }

    func pause() {
        if synthesizer.isSpeaking {
            synthesizer.pauseSpeaking(at: .word)
        }
    }

    func resume() {
        if synthesizer.isPaused {
            synthesizer.continueSpeaking()
        }
    }
}
