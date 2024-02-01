
import Foundation
import SwiftUI

#if canImport(UIKit)
import UIKit
#else
import AppKit
public typealias UIViewRepresentable = NSViewRepresentable
#endif

public struct MoonVideoPlayer {
    @ObservedObject
    public private(set) var coordinator: Coordinator
    public let url: URL
    public let options: MoonOptions
    public init(coordinator: Coordinator, url: URL, options: MoonOptions) {
        self.coordinator = coordinator
        self.url = url
        self.options = options
    }
}

extension MoonVideoPlayer: UIViewRepresentable {
    public func makeCoordinator() -> Coordinator {
        coordinator
    }

    #if canImport(UIKit)
    public typealias UIViewType = MoonPlayerLayer
    public func makeUIView(context: Context) -> UIViewType {
        let view = context.coordinator.makeView(url: url, options: options)
        return view
    }

    public func updateUIView(_ view: UIViewType, context: Context) {
        updateView(view, context: context)
    }

    // iOS tvOS真机先调用onDisappear在调用dismantleUIView，但是模拟器就反过来了。
    public static func dismantleUIView(_: UIViewType, coordinator: Coordinator) {
        coordinator.resetPlayer()
    }
    #else
    public typealias NSViewType = MoonPlayerLayer
    public func makeNSView(context: Context) -> NSViewType {
        context.coordinator.makeView(url: url, options: options)
    }

    public func updateNSView(_ view: NSViewType, context: Context) {
        updateView(view, context: context)
    }

    // macOS先调用onDisappear在调用dismantleNSView
    public static func dismantleNSView(_ view: NSViewType, coordinator: Coordinator) {
        coordinator.resetPlayer()
        view.window?.aspectRatio = CGSize(width: 16, height: 9)
    }
    #endif

    private func updateView(_ view: MoonPlayerLayer, context: Context) {
        if view.url != url {
            _ = context.coordinator.makeView(url: url, options: options)
        }
    }

    public final class Coordinator: ObservableObject {
        @Published
        public var state = MoonPlayerState.prepareToPlay
        @Published
        public var isMuted: Bool = false {
            didSet {
                playerLayer?.player.isMuted = isMuted
            }
        }

        @Published
        public var isScaleAspectFill = false {
            didSet {
                playerLayer?.player.contentMode = isScaleAspectFill ? .scaleAspectFill : .scaleAspectFit
            }
        }

        @Published
        public var playbackRate: Float = 1.0 {
            didSet {
                playerLayer?.player.playbackRate = playbackRate
            }
        }

        @Published
        public var isMaskShow = true {
            didSet {
                if isMaskShow != oldValue {
                    if isMaskShow {
                        delayItem?.cancel()
                        // 播放的时候才自动隐藏
                        guard state == .bufferFinished else { return }
                        delayItem = DispatchWorkItem { [weak self] in
                            self?.isMaskShow = false
                        }
                        DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + MoonOptions.animateDelayTimeInterval,
                                                      execute: delayItem!)
                    }
                    #if os(macOS)
                    isMaskShow ? NSCursor.unhide() : NSCursor.setHiddenUntilMouseMoves(true)
                    if let window = playerLayer?.window {
                        if !window.styleMask.contains(.fullScreen) {
                            window.standardWindowButton(.closeButton)?.superview?.superview?.isHidden = !isMaskShow
                            //                    window.standardWindowButton(.zoomButton)?.isHidden = !isMaskShow
                            //                    window.standardWindowButton(.closeButton)?.isHidden = !isMaskShow
                            //                    window.standardWindowButton(.miniaturizeButton)?.isHidden = !isMaskShow
                            //                    window.titleVisibility = isMaskShow ? .visible : .hidden
                        }
                    }
                    #endif
                }
            }
        }

        public var subtitleModel = SubtitleModel()
        public var timemodel = ControllerTimeModel()
        // 在SplitView模式下，第二次进入会先调用makeUIView。然后在调用之前的dismantleUIView.所以如果进入的是同一个View的话，就会导致playerLayer被清空了。最准确的方式是在onDisappear清空playerLayer
        public var playerLayer: MoonPlayerLayer? {
            didSet {
                oldValue?.delegate = nil
                oldValue?.pause()
            }
        }

        private var delayItem: DispatchWorkItem?
        fileprivate var onPlay: ((TimeInterval, TimeInterval) -> Void)?
        fileprivate var onFinish: ((MoonPlayerLayer, Error?) -> Void)?
        fileprivate var onStateChanged: ((MoonPlayerLayer, MoonPlayerState) -> Void)?
        fileprivate var onBufferChanged: ((Int, TimeInterval) -> Void)?

        public init() {}

        public func makeView(url: URL, options: MoonOptions) -> MoonPlayerLayer {
            defer {
                DispatchQueue.main.async { [weak self] in
                    self?.subtitleModel.url = url
                }
            }
            if let playerLayer {
                if playerLayer.url == url {
                    return playerLayer
                }
                playerLayer.delegate = nil
                playerLayer.set(url: url, options: options)
                playerLayer.delegate = self
                return playerLayer
            } else {
                let playerLayer = MoonPlayerLayer(url: url, options: options)
                playerLayer.delegate = self
                self.playerLayer = playerLayer
                return playerLayer
            }
        }

        public func resetPlayer() {
            onStateChanged = nil
            onPlay = nil
            onFinish = nil
            onBufferChanged = nil
            playerLayer = nil
            delayItem?.cancel()
            delayItem = nil
            DispatchQueue.main.async { [weak self] in
                self?.subtitleModel.url = nil
            }
        }

        public func skip(interval: Int) {
            if let playerLayer {
                seek(time: playerLayer.player.currentPlaybackTime + TimeInterval(interval))
            }
        }

        public func seek(time: TimeInterval) {
            playerLayer?.seek(time: TimeInterval(time))
        }
    }
}

extension MoonVideoPlayer.Coordinator: MoonPlayerLayerDelegate {
    public func player(layer: MoonPlayerLayer, state: MoonPlayerState) {
        if state == .readyToPlay {
            playbackRate = layer.player.playbackRate
            if let subtitleDataSouce = layer.player.subtitleDataSouce {
                // 要延后增加内嵌字幕。因为有些内嵌字幕是放在视频流的。所以会比readyToPlay回调晚。
                DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 1) { [weak self] in
                    guard let self else { return }
                    self.subtitleModel.addSubtitle(dataSouce: subtitleDataSouce)
                    if self.subtitleModel.selectedSubtitleInfo == nil, layer.options.autoSelectEmbedSubtitle {
                        self.subtitleModel.selectedSubtitleInfo = subtitleDataSouce.infos.first { $0.isEnabled }
                    }
                }
            }
        } else if state == .bufferFinished {
            isMaskShow = false
        } else {
            isMaskShow = true
        }
        self.state = state
        onStateChanged?(layer, state)
    }

    public func player(layer _: MoonPlayerLayer, currentTime: TimeInterval, totalTime: TimeInterval) {
        onPlay?(currentTime, totalTime)
        let current = Int(currentTime)
        let total = Int(max(0, totalTime))
        if timemodel.currentTime != current {
            timemodel.currentTime = current
        }
        if timemodel.totalTime != total {
            timemodel.totalTime = total
        }
        _ = subtitleModel.subtitle(currentTime: currentTime)
    }

    public func player(layer: MoonPlayerLayer, finish error: Error?) {
        onFinish?(layer, error)
    }

    public func player(layer _: MoonPlayerLayer, bufferedCount: Int, consumeTime: TimeInterval) {
        onBufferChanged?(bufferedCount, consumeTime)
    }
}

extension MoonVideoPlayer: Equatable {
    public static func == (lhs: MoonVideoPlayer, rhs: MoonVideoPlayer) -> Bool {
        lhs.url == rhs.url
    }
}

public extension MoonVideoPlayer {
    func onBufferChanged(_ handler: @escaping (Int, TimeInterval) -> Void) -> Self {
        coordinator.onBufferChanged = handler
        return self
    }

    /// Playing to the end.
    func onFinish(_ handler: @escaping (MoonPlayerLayer, Error?) -> Void) -> Self {
        coordinator.onFinish = handler
        return self
    }

    func onPlay(_ handler: @escaping (TimeInterval, TimeInterval) -> Void) -> Self {
        coordinator.onPlay = handler
        return self
    }

    /// Playback status changes, such as from play to pause.
    func onStateChanged(_ handler: @escaping (MoonPlayerLayer, MoonPlayerState) -> Void) -> Self {
        coordinator.onStateChanged = handler
        return self
    }
}

extension View {
    func then(_ body: (inout Self) -> Void) -> Self {
        var result = self
        body(&result)
        return result
    }
}

/// 这是一个频繁变化的model。View要少用这个
public class ControllerTimeModel: ObservableObject {
    // 改成int才不会频繁更新
    @Published
    public var currentTime = 0
    @Published
    public var totalTime = 1
}
