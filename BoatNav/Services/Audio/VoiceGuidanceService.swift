import AVFoundation
import CoreLocation
import Combine

class VoiceGuidanceService: ObservableObject {

    @Published var isEnabled: Bool {
        didSet { UserDefaults.standard.set(isEnabled, forKey: "voiceGuidanceEnabled") }
    }

    private let synthesizer = AVSpeechSynthesizer()
    private let voice = AVSpeechSynthesisVoice(language: "nl-NL")

    // Track which maneuver index was announced at which stage
    private var announcedWarning: Int = -1   // ~500m
    private var announcedAlert: Int = -1     // ~200m
    private var announcedImmediate: Int = -1 // ~50m
    private var announcedArrival = false

    private let warningThreshold: CLLocationDistance = 500
    private let alertThreshold: CLLocationDistance = 200
    private let immediateThreshold: CLLocationDistance = 75

    init() {
        let defaults = UserDefaults.standard
        if defaults.object(forKey: "voiceGuidanceEnabled") == nil {
            defaults.set(true, forKey: "voiceGuidanceEnabled")
        }
        self.isEnabled = defaults.bool(forKey: "voiceGuidanceEnabled")
        configureAudioSession()
    }

    private func configureAudioSession() {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .voicePrompt, options: [.duckOthers, .interruptSpokenAudioAndMixWithOthers])
        } catch {
            #if DEBUG
            print("[Voice] Audio session config failed: \(error)")
            #endif
        }
    }

    func update(maneuverIndex: Int, maneuver: RouteManeuver, distance: CLLocationDistance) {
        guard isEnabled else { return }

        // Warning announcement (~500m)
        if distance <= warningThreshold && distance > alertThreshold && announcedWarning != maneuverIndex {
            announcedWarning = maneuverIndex
            let text = warningAnnouncement(for: maneuver, distance: distance)
            speak(text)
        }

        // Alert announcement (~200m)
        if distance <= alertThreshold && distance > immediateThreshold && announcedAlert != maneuverIndex {
            announcedAlert = maneuverIndex
            let text = alertAnnouncement(for: maneuver, distance: distance)
            speak(text)
        }

        // Immediate announcement (~75m)
        if distance <= immediateThreshold && announcedImmediate != maneuverIndex {
            announcedImmediate = maneuverIndex
            let text = immediateAnnouncement(for: maneuver)
            speak(text)
        }
    }

    func announceDepart(instruction: String) {
        guard isEnabled else { return }
        speak(instruction)
    }

    func announceArrival() {
        guard isEnabled, !announcedArrival else { return }
        announcedArrival = true
        speak("U bent aangekomen op uw bestemming.")
    }

    func reset() {
        announcedWarning = -1
        announcedAlert = -1
        announcedImmediate = -1
        announcedArrival = false
        synthesizer.stopSpeaking(at: .word)
    }

    // MARK: - Announcement text

    private func warningAnnouncement(for maneuver: RouteManeuver, distance: CLLocationDistance) -> String {
        let distText = formatDistance(distance)
        switch maneuver.type {
        case .turn(let direction):
            return "Over \(distText), \(directionPhrase(direction))."
        case .bridge(let height):
            return "Over \(distText), brug. Doorvaarthoogte \(String(format: "%.1f", height)) meter."
        case .lock(let name):
            return "Over \(distText), sluis \(name)."
        case .arrive:
            return "Over \(distText) bereikt u uw bestemming."
        case .depart:
            return ""
        }
    }

    private func alertAnnouncement(for maneuver: RouteManeuver, distance: CLLocationDistance) -> String {
        let distText = formatDistance(distance)
        switch maneuver.type {
        case .turn(let direction):
            return "Over \(distText), \(directionPhrase(direction))."
        case .bridge(let height):
            return "Brug nadert. Doorvaarthoogte \(String(format: "%.1f", height)) meter."
        case .lock(let name):
            return "Sluis \(name) nadert."
        case .arrive:
            return "U nadert uw bestemming."
        case .depart:
            return ""
        }
    }

    private func immediateAnnouncement(for maneuver: RouteManeuver) -> String {
        switch maneuver.type {
        case .turn(let direction):
            return "Nu \(directionPhrase(direction))."
        case .bridge:
            return "Brug."
        case .lock:
            return "Sluis."
        case .arrive:
            return "U bent aangekomen."
        case .depart:
            return ""
        }
    }

    private func directionPhrase(_ direction: RouteManeuver.TurnDirection) -> String {
        switch direction {
        case .left: return "linksaf"
        case .slightLeft: return "links aanhouden"
        case .straight: return "rechtdoor"
        case .slightRight: return "rechts aanhouden"
        case .right: return "rechtsaf"
        }
    }

    private func formatDistance(_ meters: CLLocationDistance) -> String {
        if meters >= 1000 {
            return String(format: "%.1f kilometer", meters / 1000)
        } else {
            let rounded = Int((meters / 50).rounded()) * 50
            return "\(max(rounded, 50)) meter"
        }
    }

    // MARK: - Speech

    private func speak(_ text: String) {
        guard !text.isEmpty else { return }

        // Interrupt any ongoing announcement
        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .word)
        }

        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = voice
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate * 0.95
        utterance.pitchMultiplier = 1.0
        utterance.preUtteranceDelay = 0.1
        utterance.postUtteranceDelay = 0.3

        #if DEBUG
        print("[Voice] \(text)")
        #endif

        synthesizer.speak(utterance)
    }
}
