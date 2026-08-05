import Foundation
import AVFoundation
import UIKit

// Self-contained audio: short PCM buffers synthesized at startup (no asset files).
// All playback is gated by the Sound setting; failures degrade to silence.

final class SoundBox {
    static let shared = SoundBox()

    var enabled = true

    private let engine = AVAudioEngine()
    private var players: [AVAudioPlayerNode] = []
    private var nextPlayer = 0
    private var buffers: [String: AVAudioPCMBuffer] = [:]
    private var ready = false
    private let sampleRate: Double = 44100

    private init() {
        try? AVAudioSession.sharedInstance().setCategory(.ambient, options: [.mixWithOthers])
        try? AVAudioSession.sharedInstance().setActive(true)

        guard let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1) else { return }
        for _ in 0..<4 {
            let p = AVAudioPlayerNode()
            engine.attach(p)
            engine.connect(p, to: engine.mainMixerNode, format: format)
            players.append(p)
        }
        engine.mainMixerNode.outputVolume = 0.55

        buffers["plink"] = makeTone(freqStart: 920, freqEnd: 640, duration: 0.14, attack: 0.004, volume: 0.7)
        buffers["plinkHigh"] = makeTone(freqStart: 1180, freqEnd: 880, duration: 0.16, attack: 0.004, volume: 0.75)
        buffers["plunk"] = makeTone(freqStart: 260, freqEnd: 110, duration: 0.32, attack: 0.008, volume: 0.9)
        buffers["splash"] = makeNoise(duration: 0.28, volume: 0.4, lowpass: 0.25)
        buffers["whoosh"] = makeNoise(duration: 0.2, volume: 0.25, lowpass: 0.12)
        buffers["chime"] = makeTone(freqStart: 1040, freqEnd: 1040, duration: 0.4, attack: 0.006, volume: 0.5)
        buffers["thud"] = makeTone(freqStart: 150, freqEnd: 80, duration: 0.2, attack: 0.002, volume: 0.8)
        buffers["tick"] = makeTone(freqStart: 1400, freqEnd: 1300, duration: 0.05, attack: 0.002, volume: 0.35)

        do {
            try engine.start()
            ready = true
        } catch {
            ready = false
        }
    }

    private func makeTone(freqStart: Double, freqEnd: Double, duration: Double,
                          attack: Double, volume: Float) -> AVAudioPCMBuffer? {
        guard let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1) else { return nil }
        let frames = AVAudioFrameCount(duration * sampleRate)
        guard let buf = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frames) else { return nil }
        buf.frameLength = frames
        guard let data = buf.floatChannelData?[0] else { return nil }
        var phase = 0.0
        for i in 0..<Int(frames) {
            let t = Double(i) / sampleRate
            let prog = t / duration
            let freq = freqStart + (freqEnd - freqStart) * prog
            phase += 2 * .pi * freq / sampleRate
            let env: Double
            if t < attack {
                env = t / attack
            } else {
                env = exp(-(t - attack) * 9.0)
            }
            data[i] = Float(sin(phase) * env) * volume
        }
        return buf
    }

    private func makeNoise(duration: Double, volume: Float, lowpass: Double) -> AVAudioPCMBuffer? {
        guard let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1) else { return nil }
        let frames = AVAudioFrameCount(duration * sampleRate)
        guard let buf = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frames) else { return nil }
        buf.frameLength = frames
        guard let data = buf.floatChannelData?[0] else { return nil }
        var rng = SeededRNG(seed: 0xA11CE)
        var prev = 0.0
        for i in 0..<Int(frames) {
            let t = Double(i) / sampleRate
            let white = rng.double01() * 2 - 1
            prev = prev + lowpass * (white - prev)
            let env = sin(min(1.0, t / 0.03) * .pi / 2) * exp(-t * 11.0)
            data[i] = Float(prev * env) * volume * 2.2
        }
        return buf
    }

    func play(_ name: String) {
        guard enabled, ready, let buf = buffers[name] else { return }
        let p = players[nextPlayer]
        nextPlayer = (nextPlayer + 1) % players.count
        p.stop()
        p.scheduleBuffer(buf, at: nil, options: [], completionHandler: nil)
        p.play()
    }
}

final class HapticBox {
    static let shared = HapticBox()
    var enabled = true

    private let light = UIImpactFeedbackGenerator(style: .light)
    private let medium = UIImpactFeedbackGenerator(style: .medium)
    private let heavy = UIImpactFeedbackGenerator(style: .heavy)
    private let notify = UINotificationFeedbackGenerator()

    private init() {}

    func tapLight() { guard enabled else { return }; light.impactOccurred() }
    func tapMedium() { guard enabled else { return }; medium.impactOccurred() }
    func tapHeavy() { guard enabled else { return }; heavy.impactOccurred() }
    func success() { guard enabled else { return }; notify.notificationOccurred(.success) }
    func warning() { guard enabled else { return }; notify.notificationOccurred(.warning) }
}
