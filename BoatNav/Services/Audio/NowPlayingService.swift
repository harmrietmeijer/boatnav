import MediaPlayer
import Combine

class NowPlayingService: ObservableObject {

    @Published var isPlaying = false
    @Published var trackTitle: String?
    @Published var artistName: String?
    @Published var albumArtwork: UIImage?

    private var timer: Timer?

    init() {
        setupRemoteCommands()
        startPollingNowPlaying()
    }

    deinit {
        timer?.invalidate()
    }

    // MARK: - Remote Commands

    private func setupRemoteCommands() {
        let commandCenter = MPRemoteCommandCenter.shared()

        commandCenter.playCommand.addTarget { [weak self] _ in
            self?.isPlaying = true
            return .success
        }

        commandCenter.pauseCommand.addTarget { [weak self] _ in
            self?.isPlaying = false
            return .success
        }

        commandCenter.togglePlayPauseCommand.addTarget { [weak self] _ in
            self?.isPlaying.toggle()
            return .success
        }
    }

    // MARK: - Now Playing Info

    private func startPollingNowPlaying() {
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.updateNowPlayingInfo()
        }
    }

    private func updateNowPlayingInfo() {
        let info = MPNowPlayingInfoCenter.default().nowPlayingInfo

        trackTitle = info?[MPMediaItemPropertyTitle] as? String
        artistName = info?[MPMediaItemPropertyArtist] as? String

        if let artwork = info?[MPMediaItemPropertyArtwork] as? MPMediaItemArtwork {
            albumArtwork = artwork.image(at: CGSize(width: 80, height: 80))
        }
    }
}
