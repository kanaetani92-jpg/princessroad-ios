import UIKit
import Capacitor
import WebKit
import AVFoundation

final class NativeAudioEngine {
    static let shared = NativeAudioEngine()

    private let silentModePlaybackKey = "SilentModePlayback"
    private var activePlayers: [AVAudioPlayer] = []

    private init() {}

    @discardableResult
    func configure(enabled: Bool) -> Bool {
        let session = AVAudioSession.sharedInstance()

        do {
            if enabled {
                try session.setCategory(.playback, mode: .default, options: [])
            } else {
                try session.setCategory(.ambient, mode: .default, options: [.mixWithOthers])
            }

            try session.setActive(true)
            UserDefaults.standard.set(enabled, forKey: silentModePlaybackKey)
            NSLog("NativeAudioEngine: AVAudioSession playback = \(enabled)")
            return true
        } catch {
            NSLog("NativeAudioEngine error: \(error.localizedDescription)")
            return false
        }
    }

    @discardableResult
    func playTest(enabled: Bool) -> Bool {
        return playGoal(enabled: enabled)
    }

    @discardableResult
    func playGoal(enabled: Bool) -> Bool {
        guard configure(enabled: enabled) else { return false }
        let first = playSequence([659.25, 783.99, 987.77, 1174.66], startDelay: 0.02)
        _ = playSequence([659.25, 783.99, 987.77, 1174.66], startDelay: 0.78)
        return first
    }

    @discardableResult
    func playStation(enabled: Bool) -> Bool {
        guard configure(enabled: enabled) else { return false }
        return playSequence([783.99, 1046.50], startDelay: 0.02)
    }

    @discardableResult
    private func playSequence(_ frequencies: [Double], startDelay: TimeInterval) -> Bool {
        var firstStarted = false

        for (index, frequency) in frequencies.enumerated() {
            let delay = startDelay + Double(index) * 0.16

            if index == 0 && delay <= 0.05 {
                firstStarted = playTone(frequency: frequency, duration: 0.15)
                continue
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
                _ = self?.playTone(frequency: frequency, duration: 0.15)
            }

            if index == 0 {
                firstStarted = true
            }
        }

        return firstStarted
    }

    @discardableResult
    private func playTone(frequency: Double, duration: TimeInterval) -> Bool {
        do {
            let data = wavToneData(frequency: frequency, duration: duration, volume: 0.38)
            let player = try AVAudioPlayer(data: data)
            player.prepareToPlay()
            activePlayers.append(player)
            let started = player.play()

            if !started {
                NSLog("NativeAudioEngine playTone error: player.play() returned false")
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + duration + 1.0) { [weak self, weak player] in
                guard let player = player else { return }
                self?.activePlayers.removeAll { $0 === player }
            }

            return started
        } catch {
            NSLog("NativeAudioEngine playTone error: \(error.localizedDescription)")
            return false
        }
    }

    private func wavToneData(frequency: Double, duration: TimeInterval, volume: Double) -> Data {
        let sampleRate = 44100
        let sampleCount = Int(Double(sampleRate) * duration)
        let bytesPerSample = 2
        let dataSize = sampleCount * bytesPerSample
        var data = Data()

        func appendString(_ value: String) {
            data.append(contentsOf: value.utf8)
        }

        func appendUInt16(_ value: UInt16) {
            var littleEndian = value.littleEndian
            withUnsafeBytes(of: &littleEndian) { data.append(contentsOf: $0) }
        }

        func appendUInt32(_ value: UInt32) {
            var littleEndian = value.littleEndian
            withUnsafeBytes(of: &littleEndian) { data.append(contentsOf: $0) }
        }

        appendString("RIFF")
        appendUInt32(UInt32(36 + dataSize))
        appendString("WAVE")
        appendString("fmt ")
        appendUInt32(16)
        appendUInt16(1)
        appendUInt16(1)
        appendUInt32(UInt32(sampleRate))
        appendUInt32(UInt32(sampleRate * bytesPerSample))
        appendUInt16(UInt16(bytesPerSample))
        appendUInt16(16)
        appendString("data")
        appendUInt32(UInt32(dataSize))

        for i in 0..<sampleCount {
            let time = Double(i) / Double(sampleRate)
            let envelope: Double
            if time < 0.018 {
                envelope = time / 0.018
            } else if time > duration - 0.04 {
                envelope = max(0, (duration - time) / 0.04)
            } else {
                envelope = 1.0
            }

            let sample = sin(2.0 * Double.pi * frequency * time) * volume * envelope
            var intSample = Int16(max(-1.0, min(1.0, sample)) * Double(Int16.max)).littleEndian
            withUnsafeBytes(of: &intSample) { data.append(contentsOf: $0) }
        }

        return data
    }
}

final class NativeHapticEngine {
    static let shared = NativeHapticEngine()

    private init() {}

    func playStep() {
        DispatchQueue.main.async {
            let generator = UIImpactFeedbackGenerator(style: .medium)
            generator.prepare()
            generator.impactOccurred()
        }
    }

    func playTask() {
        DispatchQueue.main.async {
            let generator = UINotificationFeedbackGenerator()
            generator.prepare()
            generator.notificationOccurred(.success)
        }
    }
}

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate, WKScriptMessageHandler, UIDocumentPickerDelegate {

    var window: UIWindow?

    private let silentModePlaybackKey = "SilentModePlayback"
    private let nativeAudioMessageName = "NativeAudioMode"
    private let localDataMessageName = "LocalDataBridge"
    private var nativeAudioHandlerAttached = false
    private var localDataHandlerAttached = false
    private var pendingExportURL: URL?

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        applySavedAudioMode()

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.attachNativeAudioBridge()
            self.refreshAudioModeFromWebStorage()
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            self.attachNativeAudioBridge()
            self.refreshAudioModeFromWebStorage()
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
            self.attachNativeAudioBridge()
            self.refreshAudioModeFromWebStorage()
        }

        return true
    }

    func applicationDidBecomeActive(_ application: UIApplication) {
        attachNativeAudioBridge()
        refreshAudioModeFromWebStorage()
        applySavedAudioMode()
    }

    func applicationWillResignActive(_ application: UIApplication) {}
    func applicationDidEnterBackground(_ application: UIApplication) {}
    func applicationWillEnterForeground(_ application: UIApplication) {}
    func applicationWillTerminate(_ application: UIApplication) {}

    func application(
        _ app: UIApplication,
        open url: URL,
        options: [UIApplication.OpenURLOptionsKey: Any] = [:]
    ) -> Bool {
        return ApplicationDelegateProxy.shared.application(app, open: url, options: options)
    }

    func application(
        _ application: UIApplication,
        continue userActivity: NSUserActivity,
        restorationHandler: @escaping ([UIUserActivityRestoring]?) -> Void
    ) -> Bool {
        return ApplicationDelegateProxy.shared.application(
            application,
            continue: userActivity,
            restorationHandler: restorationHandler
        )
    }

    private func applySavedAudioMode() {
        let enabled = UserDefaults.standard.bool(forKey: silentModePlaybackKey)
        setSilentModePlayback(enabled)
    }

    private func findBridgeViewController(from viewController: UIViewController?) -> CAPBridgeViewController? {
        guard let viewController = viewController else { return nil }

        if let bridgeViewController = viewController as? CAPBridgeViewController {
            return bridgeViewController
        }

        if let navigationController = viewController as? UINavigationController {
            return findBridgeViewController(from: navigationController.visibleViewController)
        }

        if let tabBarController = viewController as? UITabBarController {
            return findBridgeViewController(from: tabBarController.selectedViewController)
        }

        for child in viewController.children {
            if let found = findBridgeViewController(from: child) {
                return found
            }
        }

        if let presented = viewController.presentedViewController {
            return findBridgeViewController(from: presented)
        }

        return nil
    }

    private func currentWebView() -> WKWebView? {
        guard let bridgeViewController = findBridgeViewController(from: window?.rootViewController) else {
            NSLog("NativeAudioMode: CAPBridgeViewController not found")
            return nil
        }

        guard let webView = bridgeViewController.webView else {
            NSLog("NativeAudioMode: webView not found")
            return nil
        }

        return webView
    }

    private func attachNativeAudioBridge() {
        guard let webView = currentWebView() else { return }

        if !nativeAudioHandlerAttached {
            webView.configuration.userContentController.add(self, name: nativeAudioMessageName)
            nativeAudioHandlerAttached = true
            NSLog("NativeAudioMode: WK bridge attached")
        }

        if !localDataHandlerAttached {
            webView.configuration.userContentController.add(self, name: localDataMessageName)
            localDataHandlerAttached = true
            NSLog("LocalDataBridge: WK bridge attached")
        }
    }

    private func refreshAudioModeFromWebStorage() {
        guard let webView = currentWebView() else { return }

        let script = """
        (() => {
          try {
            const candidates = [];
            for (let i = 0; i < localStorage.length; i++) {
              const key = localStorage.key(i);
              const raw = localStorage.getItem(key);
              candidates.push(raw);
            }
            for (const raw of candidates) {
              try {
                const value = JSON.parse(raw);
                if (value && typeof value === 'object') {
                  if (Object.prototype.hasOwnProperty.call(value, 'silentModePlayback')) {
                    return !!value.silentModePlayback;
                  }
                  if (value.cfg && Object.prototype.hasOwnProperty.call(value.cfg, 'silentModePlayback')) {
                    return !!value.cfg.silentModePlayback;
                  }
                  if (value.settings && Object.prototype.hasOwnProperty.call(value.settings, 'silentModePlayback')) {
                    return !!value.settings.silentModePlayback;
                  }
                }
              } catch (e) {}
            }
          } catch (e) {}
          return false;
        })();
        """

        webView.evaluateJavaScript(script) { result, error in
            if let error = error {
                NSLog("NativeAudioMode: localStorage read error \(error.localizedDescription)")
                return
            }

            guard let enabled = result as? Bool else {
                NSLog("NativeAudioMode: localStorage result is not Bool")
                return
            }

            UserDefaults.standard.set(enabled, forKey: self.silentModePlaybackKey)
            self.setSilentModePlayback(enabled)
            NSLog("NativeAudioMode: localStorage silentModePlayback = \(enabled)")
        }
    }

    func userContentController(
        _ userContentController: WKUserContentController,
        didReceive message: WKScriptMessage
    ) {
        if message.name == localDataMessageName {
            handleLocalDataMessage(message)
            return
        }

        guard message.name == nativeAudioMessageName else { return }

        let body = message.body as? [String: Any]
        let enabled = (body?["enabled"] as? Bool) ?? UserDefaults.standard.bool(forKey: silentModePlaybackKey)
        let action = (body?["action"] as? String) ?? "setSilentModePlayback"

        UserDefaults.standard.set(enabled, forKey: silentModePlaybackKey)

        switch action {
        case "playStepHaptic":
            NativeHapticEngine.shared.playStep()
            NSLog("NativeAudioMode: WK playStepHaptic")
        case "playTaskHaptic":
            NativeHapticEngine.shared.playTask()
            NSLog("NativeAudioMode: WK playTaskHaptic")
        case "playTest":
            _ = NativeAudioEngine.shared.playTest(enabled: enabled)
            NSLog("NativeAudioMode: WK playTest enabled = \(enabled)")
        case "playGoal":
            _ = NativeAudioEngine.shared.playGoal(enabled: enabled)
            NSLog("NativeAudioMode: WK playGoal enabled = \(enabled)")
        case "playStation":
            _ = NativeAudioEngine.shared.playStation(enabled: enabled)
            NSLog("NativeAudioMode: WK playStation enabled = \(enabled)")
        default:
            setSilentModePlayback(enabled)
            NSLog("NativeAudioMode: WK setSilentModePlayback enabled = \(enabled)")
        }
    }

    private func setSilentModePlayback(_ enabled: Bool) {
        _ = NativeAudioEngine.shared.configure(enabled: enabled)
    }

    private func handleLocalDataMessage(_ message: WKScriptMessage) {
        guard
            let body = message.body as? [String: Any],
            let action = body["action"] as? String
        else {
            notifyLocalDataResult(action: "unknown", status: "error")
            return
        }

        if action == "printHistory" {
            presentHistoryPrintController()
            return
        }

        guard action == "shareBackup", let content = body["content"] as? String else {
            notifyLocalDataResult(action: action, status: "error")
            return
        }

        let requestedName = (body["fileName"] as? String) ?? "focus-route-backup.json"
        let safeName = requestedName.replacingOccurrences(
            of: "[^A-Za-z0-9._-]",
            with: "-",
            options: .regularExpression
        )
        let fileURL = FileManager.default.temporaryDirectory.appendingPathComponent(safeName)

        do {
            try content.write(to: fileURL, atomically: true, encoding: .utf8)
        } catch {
            NSLog("LocalDataBridge write error: \(error.localizedDescription)")
            notifyLocalDataResult(action: action, status: "error")
            return
        }

        pendingExportURL = fileURL
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            guard let presenter = self.findBridgeViewController(from: self.window?.rootViewController) else {
                self.finishBackupExport(status: "error")
                return
            }

            let documentPicker = UIDocumentPickerViewController(forExporting: [fileURL], asCopy: true)
            documentPicker.delegate = self
            presenter.present(documentPicker, animated: true)
        }
    }

    func documentPicker(
        _ controller: UIDocumentPickerViewController,
        didPickDocumentsAt urls: [URL]
    ) {
        finishBackupExport(status: "completed")
    }

    func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
        finishBackupExport(status: "cancelled")
    }

    private func finishBackupExport(status: String) {
        if let fileURL = pendingExportURL {
            try? FileManager.default.removeItem(at: fileURL)
        }
        pendingExportURL = nil
        notifyLocalDataResult(action: "shareBackup", status: status)
    }

    private func presentHistoryPrintController() {
        guard
            let presenter = findBridgeViewController(from: window?.rootViewController),
            let webView = presenter.webView
        else {
            notifyPrintResult(status: "error")
            return
        }

        let printController = UIPrintInteractionController.shared
        let printInfo = UIPrintInfo(dictionary: nil)
        printInfo.jobName = "プリンセスロード きらめきの記録"
        printInfo.outputType = .general
        printController.printInfo = printInfo
        printController.printFormatter = webView.viewPrintFormatter()

        let completion: UIPrintInteractionController.CompletionHandler = { [weak self] _, completed, error in
            if error != nil {
                self?.notifyPrintResult(status: "error")
            } else {
                self?.notifyPrintResult(status: completed ? "completed" : "cancelled")
            }
        }

        let presented: Bool
        if UIDevice.current.userInterfaceIdiom == .pad {
            presented = printController.present(
                from: presenter.view.bounds,
                in: presenter.view,
                animated: true,
                completionHandler: completion
            )
        } else {
            presented = printController.present(animated: true, completionHandler: completion)
        }

        if !presented {
            notifyPrintResult(status: "error")
        }
    }

    private func notifyLocalDataResult(action: String, status: String) {
        guard let webView = currentWebView() else { return }
        let script = """
        window.dispatchEvent(new CustomEvent('focus-route-local-data-result', {
          detail: { action: '\(action)', status: '\(status)' }
        }));
        """
        webView.evaluateJavaScript(script)
    }

    private func notifyPrintResult(status: String) {
        guard let webView = currentWebView() else { return }
        let script = """
        window.dispatchEvent(new CustomEvent('focus-route-print-result', {
          detail: { status: '\(status)' }
        }));
        """
        webView.evaluateJavaScript(script)
    }
}

@objc(NativeAudioModePlugin)
public class NativeAudioModePlugin: CAPPlugin, CAPBridgedPlugin {
    public let identifier = "NativeAudioModePlugin"
    public let jsName = "NativeAudioMode"
    public let pluginMethods: [CAPPluginMethod] = [
        CAPPluginMethod(name: "setSilentModePlayback", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "playTest", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "playGoal", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "playStation", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "playStepHaptic", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "playTaskHaptic", returnType: CAPPluginReturnPromise)
    ]

    private let silentModePlaybackKey = "SilentModePlayback"

    override public func load() {
        _ = NativeAudioEngine.shared.configure(enabled: UserDefaults.standard.bool(forKey: silentModePlaybackKey))
    }

    @objc func setSilentModePlayback(_ call: CAPPluginCall) {
        let enabled = call.getBool("enabled") ?? false
        UserDefaults.standard.set(enabled, forKey: silentModePlaybackKey)
        let ok = NativeAudioEngine.shared.configure(enabled: enabled)
        if ok {
            call.resolve(["enabled": enabled, "native": true])
        } else {
            call.reject("AVAudioSession configuration failed", "AUDIO_SESSION_ERROR")
        }
    }

    @objc func playTest(_ call: CAPPluginCall) {
        let enabled = call.getBool("enabled") ?? UserDefaults.standard.bool(forKey: silentModePlaybackKey)
        let ok = NativeAudioEngine.shared.playTest(enabled: enabled)
        resolvePlayback(call, ok: ok)
    }

    @objc func playGoal(_ call: CAPPluginCall) {
        let enabled = call.getBool("enabled") ?? UserDefaults.standard.bool(forKey: silentModePlaybackKey)
        let ok = NativeAudioEngine.shared.playGoal(enabled: enabled)
        resolvePlayback(call, ok: ok)
    }

    @objc func playStation(_ call: CAPPluginCall) {
        let enabled = call.getBool("enabled") ?? UserDefaults.standard.bool(forKey: silentModePlaybackKey)
        let ok = NativeAudioEngine.shared.playStation(enabled: enabled)
        resolvePlayback(call, ok: ok)
    }

    @objc func playStepHaptic(_ call: CAPPluginCall) {
        NativeHapticEngine.shared.playStep()
        call.resolve(["played": true, "native": true])
    }

    @objc func playTaskHaptic(_ call: CAPPluginCall) {
        NativeHapticEngine.shared.playTask()
        call.resolve(["played": true, "native": true])
    }

    private func resolvePlayback(_ call: CAPPluginCall, ok: Bool) {
        if ok {
            call.resolve(["played": true, "native": true])
        } else {
            call.reject("Native audio playback failed", "PLAYBACK_ERROR")
        }
    }
}
