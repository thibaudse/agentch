import AppKit

struct SoundPlayer {
    static let availableSounds = ["Blow", "Bottle", "Frog", "Funk", "Glass", "Hero", "Morse", "Ping", "Pop", "Purr", "Submarine", "Tink"]

    static var selectedSound: String {
        get { UserDefaults.standard.string(forKey: "notificationSound") ?? "Blow" }
        set { UserDefaults.standard.set(newValue, forKey: "notificationSound") }
    }

    static var soundEnabled: Bool {
        get { UserDefaults.standard.object(forKey: "soundEnabled") as? Bool ?? true }
        set { UserDefaults.standard.set(newValue, forKey: "soundEnabled") }
    }

    static func playAttentionSound() {
        guard soundEnabled else { return }
        NSSound(named: selectedSound)?.play()
    }

    static func preview(_ name: String) {
        NSSound(named: name)?.play()
    }
}
