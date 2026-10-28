import AVFoundation
import SwiftUI

/// Short sound effects of the Parcours mode. They live in the app bundle: nothing is downloaded.
@MainActor
enum Sound: String, CaseIterable {
    case tap, right, wrong, star, complete

    private static var players: [Sound: AVAudioPlayer] = [:]
    private static let key = "soundsOn"

    static var isOn: Bool {
        get { UserDefaults.standard.object(forKey: key) as? Bool ?? true }
        set { UserDefaults.standard.set(newValue, forKey: key) }
    }

    /// Plays the sound from the start, unless sounds are muted.
    func play(after delay: TimeInterval = 0) {
        guard delay <= 0 else {
            Task {
                try? await Task.sleep(for: .seconds(delay))
                play()
            }
            return
        }
        guard Sound.isOn, let player = player() else { return }
        player.currentTime = 0
        player.play()
    }

    private func player() -> AVAudioPlayer? {
        if let p = Sound.players[self] { return p }
        for ext in ["wav", "mp3"] {
            guard let url = Bundle.main.url(forResource: rawValue, withExtension: ext, subdirectory: "Sounds") ?? Bundle.main.url(forResource: rawValue, withExtension: ext),
                  let p = try? AVAudioPlayer(contentsOf: url) else { continue }
            p.prepareToPlay()
            Sound.players[self] = p
            return p
        }
        return nil
    }
}

/// A speaker button to mute or unmute the sound effects.
struct SoundToggle: View {
    @State private var on = Sound.isOn

    var body: some View {
        Button {
            on.toggle()
            Sound.isOn = on
            if on { Sound.tap.play() }
        } label: {
            Image(systemName: on ? "speaker.wave.2.fill" : "speaker.slash.fill")
                .font(.headline).foregroundStyle(.secondary).frame(width: 32, height: 32)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(on ? "Couper les sons" : "Activer les sons")
    }
}
