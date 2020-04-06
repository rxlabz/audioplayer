import AVFoundation
import AVKit

#if os(iOS)
    import Flutter
    import UIKit
#elseif os(macOS)
    import FlutterMacOS
#endif

let CHANNEL_NAME: String! = "bz.rxla.flutter/audio"

public class SwiftAudioplayerPlugin: NSObject, FlutterPlugin {
    var position: CMTime = CMTimeMake(value: 0, timescale: 1)
    var lastUrl: String! = ""
    var isPlaying: Bool = false
    var observers: [Any] = []
    var timeObservers: [Any] = []
    var _channel: FlutterMethodChannel
    @objc var player: AVPlayer?
    var playerItem: AVPlayerItem?

    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(name: CHANNEL_NAME, binaryMessenger: registrar.messenger())
        let instance = SwiftAudioplayerPlugin(channel: channel)
        registrar.addMethodCallDelegate(instance, channel: channel)
    }

    init(channel: FlutterMethodChannel) {
        _channel = channel
        super.init()
    }

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "play":
            guard let info: Dictionary = call.arguments as? [String: Any] else {
                result(0)
                return
            }
            guard let url: String = info["url"] as? String, let isLocal: Bool = info["isLocal"] as? Bool else {
                result(0)
                return
            }
            play(url: url, isLocal: isLocal)
        case "pause":
            pause()
        case "stop":
            stop()
        case "seek":
            guard let sec: Double = call.arguments as? Double else {
                result(0)
                return
            }
            seek(time: CMTimeMakeWithSeconds(sec, preferredTimescale: 1))
        case "mute":
            guard let isMuted: Bool = call.arguments as? Bool else {
                result(0)
                return
            }
            mute(muted: isMuted)
        default:
            result(FlutterMethodNotImplemented)
        }
        result(1)
    }

    func play(url: String!, isLocal: Bool) {
        //Bigining of Edit
        do {
            try AVAudioSession.sharedInstance().setCategory(AVAudioSession.Category.playback, options: AVAudioSession.CategoryOptions.defaultToSpeaker)
                   NSLog("Playback OK")
                   try AVAudioSession.sharedInstance().setActive(true)
                   NSLog("Session is Active")
               } catch {
                   NSLog("ERROR: CANNOT PLAY MUSIC IN BACKGROUND. Message from code: \"\(error)\"")
               }
        //End of Edit
        if url != lastUrl {
            playerItem?.removeObserver(self, forKeyPath: #keyPath(player.currentItem.status))

            for ob in observers {
                NotificationCenter.default.removeObserver(ob)
            }
            observers.removeAll()

            playerItem = AVPlayerItem(url: isLocal ? URL(fileURLWithPath: url) : URL(string: url)!)
            lastUrl = url

            let anObserver = NotificationCenter.default.addObserver(
                forName: Notification.Name.AVPlayerItemDidPlayToEndTime,
                object: playerItem,
                queue: nil, using: onSoundComplete
            )
            observers.append(anObserver)

            if player != nil {
                player!.replaceCurrentItem(with: playerItem)
            } else {
                player = AVPlayer(playerItem: playerItem)
                // Stream player position.
                // This call is only active when the player is active so there's no need to
                // remove it when player is paused or stopped.
                let interval = CMTime(seconds: 0.2, preferredTimescale: CMTimeScale(NSEC_PER_SEC))
                let timeObserver = player!.addPeriodicTimeObserver(forInterval: interval, queue: nil, using: onTimeInterval)
                timeObservers.append(timeObserver)
            }

            // is sound ready
            player!.currentItem?.addObserver(self,
                                             forKeyPath: #keyPath(player.currentItem.status),
                                             context: nil)
        }
        onStart()
        player!.play()
        isPlaying = true
    }

    func onStart() {
        let duration: CMTime = player!.currentItem!.duration
        if CMTimeGetSeconds(duration) > 0 {
            let mseconds: Int = Int(CMTimeGetSeconds(duration) * 1000)
            _channel.invokeMethod("audio.onStart", arguments: mseconds)
        }
    }

    func onSoundComplete(note _: Notification) {
        stop()
        _channel.invokeMethod("audio.onComplete", arguments: nil)
    }

    func onTimeInterval(_ time: CMTime) {
        let mseconds = time.seconds * 1000
        _channel.invokeMethod("audio.onCurrentPosition", arguments: Int(mseconds))
    }

    func pause() {
        player?.pause()
        isPlaying = false
        _channel.invokeMethod("audio.onPause", arguments: nil)
    }

    func stop() {
        if isPlaying {
            player!.pause()
            isPlaying = false
        }
        playerItem?.seek(to: CMTimeMake(value: 0, timescale: 1))
        _channel.invokeMethod("audio.onStop", arguments: nil)
    }

    func mute(muted: Bool) {
        player?.isMuted = muted
    }

    func seek(time: CMTime) {
        playerItem?.seek(to: time)
    }

    open override func observeValue(
        forKeyPath keyPath: String?, of object: Any?,
        change: [NSKeyValueChangeKey: Any]?, context: UnsafeMutableRawPointer?
    ) {
        if keyPath == #keyPath(player.currentItem.status) {
            if player!.currentItem!.status == AVPlayerItem.Status.readyToPlay {
                onStart()
            } else if player!.currentItem!.status == AVPlayerItem.Status.failed {
                _channel.invokeMethod("audio.onError", arguments: [player!.currentItem!.error?.localizedDescription])
            }
        } else {
            // Any unrecognized context must belong to super
            super.observeValue(forKeyPath: keyPath, of: object, change: change, context: context)
        }
    }

    deinit {
        for ob in timeObservers {
            player?.removeTimeObserver(ob)
        }
        for ob in observers {
            NotificationCenter.default.removeObserver(ob)
        }
        observers.removeAll()
    }
}
