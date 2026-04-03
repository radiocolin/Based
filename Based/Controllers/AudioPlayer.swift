import AVFoundation

class AudioPlayer {
    static let shared = AudioPlayer()
    private var player: AVPlayer?
    var isPlaying: Bool {
        return player?.rate != 0 && player?.error == nil
    }
    
    func play(url: URL) {
        // If already playing this URL, do nothing? Or replace?
        // Simple implementation: replace.
        let playerItem = AVPlayerItem(url: url)
        player = AVPlayer(playerItem: playerItem)
        player?.play()
    }
    
    func stop() {
        player?.pause()
        player = nil
    }
    
    func pause() {
        player?.pause()
    }
    
    func resume() {
        player?.play()
    }
}
