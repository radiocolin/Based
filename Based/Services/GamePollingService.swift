import Foundation
import Network
import OSLog

protocol GamePollingServiceDelegate: AnyObject {
    func pollingService(_ service: GamePollingService, shouldPerformUpdateFor gamePk: String, sessionID: UUID) async throws
    func pollingService(_ service: GamePollingService, didUpdateRTT rtt: TimeInterval)
    func pollingService(_ service: GamePollingService, didChangeConnectivity connected: Bool)
}

class GamePollingService {
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "Based", category: "GamePollingService")
    weak var delegate: GamePollingServiceDelegate?

    private var pollingTask: Task<Void, Never>?
    private(set) var pollingSessionID = UUID()
    private var networkMonitor: NWPathMonitor?

    private(set) var hasConnectivity = true
    private(set) var isConstrainedNetwork = false
    private(set) var linkQuality: NWPath.LinkQuality = .unknown
    private(set) var isBackgrounded = false

    private(set) var recentRTT: TimeInterval = 0
    private(set) var consecutiveErrors = 0
    private let maxBackoffInterval: TimeInterval = 60.0

    var needsInningCleanup = false
    var inningCleanupAttempts = 0
    let maxCleanupAttempts = 5

    var scheduledStartTime: Date?
    var lastPregameLineupProbeAt: Date?
    private var lastLoggedPollingInterval: Int?

    private let farPregameThreshold: TimeInterval = 3 * 60 * 60
    private let mediumPregameThreshold: TimeInterval = 90 * 60
    private let nearPregameThreshold: TimeInterval = 30 * 60

    func start(gamePk: String, scheduledStartTime: Date?) {
        stop()
        pollingSessionID = UUID()
        self.scheduledStartTime = scheduledStartTime

        let monitor = NWPathMonitor()
        networkMonitor = monitor
        monitor.pathUpdateHandler = { [weak self] path in
            guard let self else { return }
            let connected = (path.status == .satisfied)
            if self.hasConnectivity != connected || self.isConstrainedNetwork != path.isConstrained || self.linkQuality != path.linkQuality {
                self.logger.info("Network changed: connected=\(connected), constrained=\(path.isConstrained), quality=\(String(describing: path.linkQuality))")
                self.delegate?.pollingService(self, didChangeConnectivity: connected)
            }
            self.hasConnectivity = connected
            self.isConstrainedNetwork = path.isConstrained
            self.linkQuality = path.linkQuality
        }
        monitor.start(queue: DispatchQueue(label: "NetworkMonitor"))

        let sessionID = pollingSessionID
        pollingTask = Task {
            do {
                let start = CFAbsoluteTimeGetCurrent()
                try await delegate?.pollingService(self, shouldPerformUpdateFor: gamePk, sessionID: sessionID)
                updateRTT(CFAbsoluteTimeGetCurrent() - start)
                consecutiveErrors = 0
            } catch {
                if error is CancellationError { return }
                consecutiveErrors += 1
            }

            while !Task.isCancelled {
                if isBackgrounded || !hasConnectivity {
                    try? await Task.sleep(nanoseconds: 2_000_000_000)
                    continue
                }

                let interval = calculatePollingInterval(gamePk: gamePk)
                try? await Task.sleep(nanoseconds: UInt64(interval * 1_000_000_000))

                if Task.isCancelled { break }
                if isBackgrounded || !hasConnectivity { continue }

                do {
                    let start = CFAbsoluteTimeGetCurrent()
                    try await delegate?.pollingService(self, shouldPerformUpdateFor: gamePk, sessionID: sessionID)
                    updateRTT(CFAbsoluteTimeGetCurrent() - start)
                    consecutiveErrors = 0
                } catch {
                    if error is CancellationError { break }
                    consecutiveErrors += 1
                }
            }
        }
    }

    func stop() {
        pollingSessionID = UUID()
        pollingTask?.cancel()
        pollingTask = nil
        networkMonitor?.cancel()
        networkMonitor = nil
        resetState()
    }

    private func resetState() {
        needsInningCleanup = false
        inningCleanupAttempts = 0
        consecutiveErrors = 0
        recentRTT = 0
        linkQuality = .unknown
        lastLoggedPollingInterval = nil
        scheduledStartTime = nil
        lastPregameLineupProbeAt = nil
    }

    func didEnterBackground() {
        isBackgrounded = true
    }

    func willEnterForeground(gamePk: String) {
        isBackgrounded = false
        let sessionID = pollingSessionID
        Task {
            do {
                let start = CFAbsoluteTimeGetCurrent()
                try await delegate?.pollingService(self, shouldPerformUpdateFor: gamePk, sessionID: sessionID)
                updateRTT(CFAbsoluteTimeGetCurrent() - start)
                consecutiveErrors = 0
            } catch {
                if !(error is CancellationError) { consecutiveErrors += 1 }
            }
        }
    }

    private func updateRTT(_ sample: TimeInterval) {
        recentRTT = recentRTT == 0 ? sample : (0.3 * sample + 0.7 * recentRTT)
        delegate?.pollingService(self, didUpdateRTT: recentRTT)
    }

    private func calculatePollingInterval(gamePk: String) -> TimeInterval {
        let base = basePollingInterval()
        let interval = consecutiveErrors > 0 ? min(base * pow(2.0, Double(consecutiveErrors - 1)), maxBackoffInterval) : base
        logPollingIntervalIfNeeded(interval, base: base)
        return interval
    }

    private func basePollingInterval() -> TimeInterval {
        let interval: TimeInterval = 10.0
        // This needs info from the current game state which might be in GameService.
        // For now, let's assume we pass what we need or GameService provides it.
        // I'll make this more robust in the coordinator.
        return interval
    }

    // Helper to allow GameService to provide the base interval based on game state
    func calculateInterval(base: TimeInterval) -> TimeInterval {
        let interval = consecutiveErrors > 0 ? min(base * pow(2.0, Double(consecutiveErrors - 1)), maxBackoffInterval) : base
        logPollingIntervalIfNeeded(interval, base: base)
        return interval
    }

    private func logPollingIntervalIfNeeded(_ interval: TimeInterval, base: TimeInterval) {
        let rounded = Int(interval.rounded())
        if lastLoggedPollingInterval != rounded {
            lastLoggedPollingInterval = rounded
            logger.debug("Polling interval: \(rounded)s (base=\(Int(base.rounded()))s, errors=\(self.consecutiveErrors))")
        }
    }

    func pregamePollingInterval(state: String, now: Date = Date()) -> TimeInterval {
        if state.contains("warmup") || state.contains("starting soon") { return 20.0 }
        guard let scheduledStartTime else { return 120.0 }
        let seconds = scheduledStartTime.timeIntervalSince(now)
        if seconds > farPregameThreshold { return 20 * 60 }
        if seconds > mediumPregameThreshold { return 10 * 60 }
        if seconds > nearPregameThreshold { return 3 * 60 }
        return seconds > 0 ? 60 : 20.0
    }

    func shouldProbePregameLineup(now: Date = Date()) -> Bool {
        guard let lastProbe = lastPregameLineupProbeAt else { return true }
        let secondsUntilFirstPitch = scheduledStartTime?.timeIntervalSince(now) ?? 0
        let interval: TimeInterval
        if secondsUntilFirstPitch > farPregameThreshold { interval = 20 * 60 }
        else if secondsUntilFirstPitch > mediumPregameThreshold { interval = 10 * 60 }
        else if secondsUntilFirstPitch > nearPregameThreshold { interval = 5 * 60 }
        else if secondsUntilFirstPitch > 0 { interval = 2 * 60 }
        else { interval = 60 }
        return now.timeIntervalSince(lastProbe) >= interval
    }
}
