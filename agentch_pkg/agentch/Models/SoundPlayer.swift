import AppKit

struct SoundPlayer {
    /// Play a subtle system sound when a session needs attention.
    static func playAttentionSound() {
        NSSound(named: "Tink")?.play()
    }
}
