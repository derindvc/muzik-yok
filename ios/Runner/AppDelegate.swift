import AVFoundation
import AudioToolbox
import CoreHaptics
import Flutter
import ShazamKit
import SoundAnalysis
import UIKit
import UserNotifications

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private let monitor = AmbientMusicMonitor()
  private let screenTime = ScreenTimeBridge()

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    guard let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "AmbientMusicMonitor") else { return }
    let channel = FlutterMethodChannel(name: "muzik_yok/ambient_music", binaryMessenger: registrar.messenger())
    channel.setMethodCallHandler { [weak self] call, result in
      guard let self else { return }
      switch call.method {
      case "start":
        let arguments = call.arguments as? [String: Any] ?? [:]
        let seconds = arguments["durationSeconds"] as? Int ?? 1800
        self.monitor.start(durationSeconds: seconds) { error in
          if let error {
            result(FlutterError(code: "MONITOR_START_FAILED", message: error.localizedDescription, details: nil))
          } else {
            result(self.monitor.status)
          }
        }
      case "stop":
        self.monitor.stop()
        result(true)
      case "status":
        result(self.monitor.status)
      case "markFalsePositive":
        self.monitor.markFalsePositive()
        result(self.monitor.status)
      case "saveSession":
        let arguments = call.arguments as? [String: Any] ?? [:]
        result(self.monitor.saveSession(arguments))
      case "saveNote":
        let arguments = call.arguments as? [String: Any] ?? [:]
        result(self.monitor.saveNote(arguments))
      case "beginSession":
        let arguments = call.arguments as? [String: Any] ?? [:]
        self.monitor.beginSession(arguments)
        result(self.monitor.sessionStatus)
      case "sessionStatus":
        result(self.monitor.sessionStatus)
      case "cancelSession":
        self.monitor.cancelSession()
        result(true)
      case "recentSessions":
        result(self.monitor.recentSessions)
      case "clearSessions":
        UserDefaults.standard.removeObject(forKey: "MuzikYokRecentSessions")
        result(true)
      case "deleteSession":
        let arguments = call.arguments as? [String: Any] ?? [:]
        result(self.monitor.deleteSession(arguments))
      default:
        result(FlutterMethodNotImplemented)
      }
    }
    let screenTimeChannel = FlutterMethodChannel(name: "muzik_yok/screen_time", binaryMessenger: registrar.messenger())
    screenTimeChannel.setMethodCallHandler { [weak self] call, result in
      guard let self else { return }
      switch call.method {
      case "pickApplications":
        self.screenTime.pickApplications(result: result)
      case "startShield":
        do {
          let arguments = call.arguments as? [String: Any] ?? [:]
          let seconds = arguments["durationSeconds"] as? Int ?? 1800
          result(try self.screenTime.startShield(durationSeconds: seconds))
        } catch {
          result(FlutterError(code: "SHIELD_START_FAILED", message: error.localizedDescription, details: nil))
        }
      case "status":
        result(self.screenTime.status)
      case "stopShield":
        result(self.screenTime.stopShield())
      default:
        result(FlutterMethodNotImplemented)
      }
    }
    let settingsChannel = FlutterMethodChannel(name: "muzik_yok/settings", binaryMessenger: registrar.messenger())
    settingsChannel.setMethodCallHandler { call, result in
      switch call.method {
      case "getDarkMode":
        result(UserDefaults.standard.object(forKey: "MuzikYokDarkMode") as? Bool ?? true)
      case "setDarkMode":
        let enabled = call.arguments as? Bool ?? true
        UserDefaults.standard.set(enabled, forKey: "MuzikYokDarkMode")
        result(nil)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }
}

private final class AmbientMusicMonitor: NSObject, SNResultsObserving, SHSessionDelegate {
  private let analysisQueue = DispatchQueue(label: "muzik_yok.sound_analysis")
  private let melodyDetector = TonalMelodyDetector()
  private var lastMelodyDiagnosticsPersistDate = Date.distantPast
  private var lastHeartbeatPersistDate = Date.distantPast
  private var engine: AVAudioEngine?
  private var analyzer: SNAudioStreamAnalyzer?
  private var shazamSession: SHSession?
  private var shazamConverter: AVAudioConverter?
  private var shazamFeedUntil: Date?
  private var lastShazamAttempt: Date?
  private var songTitle = ""
  private var songArtist = ""
  private var songState = "idle"
  private var songError = ""
  private var timer: Timer?
  private var endDate: Date?
  private var lastAlertDate: Date?
  private var lastMusicEvidenceDate: Date?
  private var lastDetectionDate: Date?
  private var lastDetectionNotifiedInBackground = false
  private var consecutiveMusicWindows = 0
  private var currentLabel = ""
  private var currentConfidence = 0.0
  private var running = false
  private var completed = false
  private var liveActivityStopRequested = false
  private var suppressUntil: Date?
  private var falsePositiveCount = UserDefaults.standard.integer(forKey: "MuzikYokFalsePositiveCount")
  private var notificationsAuthorized = true
  private var hapticEngine: CHHapticEngine?
  private let activeSessionKey = "MuzikYokActiveSession"
  private let sessionEndNotificationID = "muzikyok.session.end"

  override init() {
    super.init()
    NotificationCenter.default.addObserver(
      self,
      selector: #selector(handleAudioInterruption(_:)),
      name: AVAudioSession.interruptionNotification,
      object: AVAudioSession.sharedInstance()
    )
    NotificationCenter.default.addObserver(
      self,
      selector: #selector(handleBackgroundEntry),
      name: UIApplication.didEnterBackgroundNotification,
      object: nil
    )
    NotificationCenter.default.addObserver(
      self,
      selector: #selector(handleForegroundEntry),
      name: UIApplication.didBecomeActiveNotification,
      object: nil
    )
  }

  deinit {
    NotificationCenter.default.removeObserver(self)
  }

  @objc private func handleBackgroundEntry() {
    guard running else { return }
    analysisQueue.async { [weak self] in
      self?.melodyDetector.reset()
      self?.melodyDetector.enabled = true
    }
    lastShazamAttempt = nil
    startShazamMatch(at: Date())
  }

  @objc private func handleForegroundEntry() {
    analysisQueue.async { [weak self] in
      self?.melodyDetector.enabled = false
      self?.melodyDetector.reset()
    }
  }

  @objc private func handleAudioInterruption(_ notification: Notification) {
    guard let rawType = notification.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt,
          AVAudioSession.InterruptionType(rawValue: rawType) == .ended else { return }
    DispatchQueue.main.async { [weak self] in
      guard let self, self.running, let endDate = self.endDate else { return }
      let secondsLeft = Int(ceil(endDate.timeIntervalSinceNow))
      guard secondsLeft > 0 else {
        self.completed = true
        self.stop()
        return
      }
      do {
        try self.begin(durationSeconds: secondsLeft)
      } catch {
        self.stop()
      }
    }
  }

  var sessionStatus: [String: Any]? {
    guard var session = UserDefaults.standard.dictionary(forKey: activeSessionKey) else { return nil }
    let endMs = session["endMs"] as? Int ?? 0
    session["completed"] = Int(Date().timeIntervalSince1970 * 1000) >= endMs
    session["remainingSeconds"] = max(0, Int(ceil(Double(endMs) / 1000 - Date().timeIntervalSince1970)))
    if session["completed"] as? Bool == true, !liveActivityStopRequested {
      liveActivityStopRequested = true
      if #available(iOS 16.2, *) { Task { @MainActor in ThinkingLiveActivity.stop() } }
    }
    return session
  }

  func beginSession(_ arguments: [String: Any]) {
    cancelSession(stopLiveActivity: false)
    liveActivityStopRequested = false
    let seconds = max(1, arguments["durationSeconds"] as? Int ?? 1800)
    let minutes = max(1, arguments["minutes"] as? Int ?? 30)
    let intention = String((arguments["intention"] as? String ?? "").prefix(300))
    let endMs = Int(Date().addingTimeInterval(TimeInterval(seconds)).timeIntervalSince1970 * 1000)
    UserDefaults.standard.set([
      "endMs": endMs,
      "minutes": minutes,
      "intention": intention,
    ] as [String: Any], forKey: activeSessionKey)

    let content = UNMutableNotificationContent()
    content.title = "Düşünme süren tamamlandı"
    content.body = "Aklındakileri not etmek için Müzik Yok'u aç."
    content.sound = .default
    let trigger = UNTimeIntervalNotificationTrigger(timeInterval: TimeInterval(seconds), repeats: false)
    let notification = UNNotificationRequest(identifier: sessionEndNotificationID, content: content, trigger: trigger)
    UNUserNotificationCenter.current().add(notification)
    if #available(iOS 16.2, *) {
      let end = Date(timeIntervalSince1970: Double(endMs) / 1000)
      Task { @MainActor in ThinkingLiveActivity.start(endDate: end) }
    }
  }

  func cancelSession(stopLiveActivity: Bool = true) {
    UserDefaults.standard.removeObject(forKey: activeSessionKey)
    UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [sessionEndNotificationID])
    UNUserNotificationCenter.current().removeDeliveredNotifications(withIdentifiers: [sessionEndNotificationID])
    if stopLiveActivity, !liveActivityStopRequested {
      liveActivityStopRequested = true
      if #available(iOS 16.2, *) { Task { @MainActor in ThinkingLiveActivity.stop() } }
    }
  }

  func markFalsePositive() {
    falsePositiveCount += 1
    UserDefaults.standard.set(falsePositiveCount, forKey: "MuzikYokFalsePositiveCount")
    suppressUntil = Date().addingTimeInterval(120)
    consecutiveMusicWindows = 0
  }

  var status: [String: Any] {
    if let endDate, Date() >= endDate, running {
      completed = true
      stop()
    }
    return [
      "running": running,
      "completed": completed,
      "remainingSeconds": max(0, Int(ceil(endDate?.timeIntervalSinceNow ?? 0))),
      "lastDetectionMs": lastDetectionDate.map { Int($0.timeIntervalSince1970 * 1000) } ?? 0,
      "lastDetectionNotifiedInBackground": lastDetectionNotifiedInBackground,
      "label": currentLabel,
      "confidence": currentConfidence,
      "falsePositiveCount": falsePositiveCount,
      "suppressedSeconds": max(0, Int(ceil(suppressUntil?.timeIntervalSinceNow ?? 0))),
      "songTitle": songTitle,
      "songArtist": songArtist,
      "songState": songState,
      "songError": songError,
      "notificationsAuthorized": notificationsAuthorized,
    ]
  }

  func start(durationSeconds: Int, completion: @escaping (Error?) -> Void) {
    guard durationSeconds > 0 else {
      completion(NSError(domain: "MuzikYok", code: 1, userInfo: [NSLocalizedDescriptionKey: "Süre sıfırdan büyük olmalı."]))
      return
    }
    AVAudioSession.sharedInstance().requestRecordPermission { [weak self] granted in
      DispatchQueue.main.async {
        guard let self else { return }
        guard granted else {
          completion(NSError(domain: "MuzikYok", code: 2, userInfo: [NSLocalizedDescriptionKey: "Mikrofon izni verilmedi. Ayarlar'dan izin verebilirsin."]))
          return
        }
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { granted, _ in
          DispatchQueue.main.async {
            self.notificationsAuthorized = granted
            UserDefaults.standard.set(granted, forKey: "MuzikYokNotificationsAuthorized")
            do {
              try self.begin(durationSeconds: durationSeconds)
              completion(nil)
            } catch {
              self.stop()
              completion(error)
            }
          }
        }
      }
    }
  }

  private func begin(durationSeconds: Int) throws {
    stop()
    completed = false
    lastDetectionDate = nil
    lastDetectionNotifiedInBackground = false
    lastAlertDate = nil
    lastMusicEvidenceDate = nil
    lastShazamAttempt = nil
    songTitle = ""
    songArtist = ""
    songState = "idle"
    songError = ""
    currentLabel = ""
    currentConfidence = 0
    suppressUntil = nil
    melodyDetector.reset()
    melodyDetector.enabled = UIApplication.shared.applicationState != .active
    for key in ["MuzikYokMaxMelodyConfidence", "MuzikYokMaxMelodyStableNotes", "MuzikYokMaxMelodyTonalFrames"] {
      UserDefaults.standard.removeObject(forKey: key)
    }
    let session = AVAudioSession.sharedInstance()
    try session.setCategory(.record, mode: .measurement)
    try session.setAllowHapticsAndSystemSoundsDuringRecording(true)
    try session.setActive(true)

    let audioEngine = AVAudioEngine()
    let input = audioEngine.inputNode
    let format = input.inputFormat(forBus: 0)
    guard format.sampleRate > 0 else {
      throw NSError(domain: "MuzikYok", code: 3, userInfo: [NSLocalizedDescriptionKey: "Mikrofon biçimi alınamadı."])
    }
    let request = try SNClassifySoundRequest(classifierIdentifier: .version1)
    guard request.knownClassifications.contains(where: { $0.lowercased().contains("music") || $0.lowercased().contains("singing") }) else {
      throw NSError(domain: "MuzikYok", code: 4, userInfo: [NSLocalizedDescriptionKey: "Bu iPhone'da müzik sınıflandırması kullanılamıyor."])
    }
    let streamAnalyzer = SNAudioStreamAnalyzer(format: format)
    try streamAnalyzer.add(request, withObserver: self)
    analyzer = streamAnalyzer
    if let shazamFormat = AVAudioFormat(standardFormatWithSampleRate: 48000, channels: 1) {
      shazamConverter = AVAudioConverter(from: format, to: shazamFormat)
    }
    input.installTap(onBus: 0, bufferSize: 8192, format: format) { [weak self] buffer, time in
      self?.analysisQueue.async { [weak self] in
        guard let self else { return }
        self.recordAudioHeartbeat()
        let melodyConfidence = self.melodyDetector.analyze(buffer)
        if self.melodyDetector.enabled,
           Date().timeIntervalSince(self.lastMelodyDiagnosticsPersistDate) >= 2 {
          self.lastMelodyDiagnosticsPersistDate = Date()
          let defaults = UserDefaults.standard
          defaults.set(max(defaults.double(forKey: "MuzikYokMaxMelodyConfidence"), self.melodyDetector.lastAverageStrength), forKey: "MuzikYokMaxMelodyConfidence")
          defaults.set(max(defaults.integer(forKey: "MuzikYokMaxMelodyStableNotes"), self.melodyDetector.lastStableNoteCount), forKey: "MuzikYokMaxMelodyStableNotes")
          defaults.set(max(defaults.integer(forKey: "MuzikYokMaxMelodyTonalFrames"), self.melodyDetector.lastTonalFrameCount), forKey: "MuzikYokMaxMelodyTonalFrames")
        }
        if let confidence = melodyConfidence {
          DispatchQueue.main.async { [weak self] in
            guard let self, self.running,
                  UIApplication.shared.applicationState != .active else { return }
            let now = Date()
            self.currentLabel = "melody"
            self.currentConfidence = confidence
            self.lastMusicEvidenceDate = now
            if self.lastAlertDate.map({ now.timeIntervalSince($0) >= self.alertCooldown }) ?? true,
               self.suppressUntil.map({ now >= $0 }) ?? true {
              self.issueMusicAlert(at: now)
            }
          }
        }
        self.analyzer?.analyze(buffer, atAudioFramePosition: time.sampleTime)
        self.feedShazam(buffer)
      }
    }
    do { try audioEngine.start() }
    catch {
      input.removeTap(onBus: 0)
      analyzer = nil
      throw error
    }
    engine = audioEngine
    endDate = Date().addingTimeInterval(TimeInterval(durationSeconds))
    running = true
    UserDefaults.standard.set(Int(Date().timeIntervalSince1970 * 1000), forKey: "MuzikYokLastMonitorStartMs")
    timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
      guard let self, let endDate = self.endDate else { return }
      if Date() >= endDate {
        self.completed = true
        if !self.liveActivityStopRequested {
          self.liveActivityStopRequested = true
          if #available(iOS 16.2, *) { Task { @MainActor in ThinkingLiveActivity.stop() } }
        }
        self.stop()
      } else {
        self.repeatAlertIfMusicContinues()
        if UIApplication.shared.applicationState != .active,
           self.lastShazamAttempt.map({ Date().timeIntervalSince($0) >= 35 }) ?? true {
          self.startShazamMatch(at: Date())
        }
        if self.songState == "searching",
           let lastShazamAttempt = self.lastShazamAttempt,
           Date().timeIntervalSince(lastShazamAttempt) > 30 {
          self.songState = "unavailable"
        }
      }
    }
  }

  private func recordAudioHeartbeat() {
    let now = Date()
    guard now.timeIntervalSince(lastHeartbeatPersistDate) >= 10 else { return }
    lastHeartbeatPersistDate = now
    UserDefaults.standard.set(Int(now.timeIntervalSince1970 * 1000), forKey: "MuzikYokLastAudioFrameMs")
  }

  private func feedShazam(_ buffer: AVAudioPCMBuffer) {
    guard let session = shazamSession,
          let feedUntil = shazamFeedUntil,
          Date() < feedUntil,
          let converter = shazamConverter else { return }
    let ratio = converter.outputFormat.sampleRate / converter.inputFormat.sampleRate
    let capacity = AVAudioFrameCount(ceil(Double(buffer.frameLength) * ratio) + 64)
    guard let converted = AVAudioPCMBuffer(pcmFormat: converter.outputFormat, frameCapacity: capacity) else { return }
    var supplied = false
    var conversionError: NSError?
    let result = converter.convert(to: converted, error: &conversionError) { _, status in
      guard !supplied else {
        status.pointee = .noDataNow
        return nil
      }
      supplied = true
      status.pointee = .haveData
      return buffer
    }
    if result != .error && converted.frameLength > 0 {
      session.matchStreamingBuffer(converted, at: nil)
    }
  }

  var recentSessions: [[String: Any]] {
    UserDefaults.standard.array(forKey: "MuzikYokRecentSessions") as? [[String: Any]] ?? []
  }

  func saveSession(_ arguments: [String: Any]) -> [String: Any] {
    let pending = sessionStatus
    let intention = String((arguments["intention"] as? String ?? pending?["intention"] as? String ?? "").prefix(300))
    let reflection = String((arguments["reflection"] as? String ?? "").prefix(1000))
    let minutes = max(1, arguments["minutes"] as? Int ?? pending?["minutes"] as? Int ?? 30)
    let record: [String: Any] = [
      "id": UUID().uuidString,
      "dateMs": Int(Date().timeIntervalSince1970 * 1000),
      "intention": intention,
      "reflection": reflection,
      "minutes": minutes,
    ]
    var sessions = recentSessions
    sessions.insert(record, at: 0)
    UserDefaults.standard.set(Array(sessions.prefix(100)), forKey: "MuzikYokRecentSessions")
    cancelSession()
    return record
  }

  func saveNote(_ arguments: [String: Any]) -> [String: Any]? {
    guard let session = sessionStatus, session["completed"] as? Bool == false else { return nil }
    let reflection = String((arguments["reflection"] as? String ?? "").trimmingCharacters(in: .whitespacesAndNewlines).prefix(1000))
    guard !reflection.isEmpty else { return nil }
    let record: [String: Any] = [
      "id": UUID().uuidString,
      "dateMs": Int(Date().timeIntervalSince1970 * 1000),
      "intention": "",
      "reflection": reflection,
      "minutes": session["minutes"] as? Int ?? 30,
    ]
    var sessions = recentSessions
    sessions.insert(record, at: 0)
    UserDefaults.standard.set(Array(sessions.prefix(100)), forKey: "MuzikYokRecentSessions")
    return record
  }

  func deleteSession(_ arguments: [String: Any]) -> Bool {
    var sessions = recentSessions
    let identifier = arguments["id"] as? String
    let dateMs = arguments["dateMs"] as? Int
    let reflection = arguments["reflection"] as? String
    guard let index = sessions.firstIndex(where: { item in
      if let identifier { return item["id"] as? String == identifier }
      return item["id"] == nil && item["dateMs"] as? Int == dateMs && item["reflection"] as? String == reflection
    }) else { return false }
    sessions.remove(at: index)
    UserDefaults.standard.set(sessions, forKey: "MuzikYokRecentSessions")
    return true
  }

  func stop() {
    UserDefaults.standard.set(Int(Date().timeIntervalSince1970 * 1000), forKey: "MuzikYokLastMonitorStopMs")
    timer?.invalidate()
    timer = nil
    running = false
    if let engine {
      engine.inputNode.removeTap(onBus: 0)
      engine.stop()
    }
    engine = nil
    analysisQueue.sync {
      analyzer = nil
      shazamSession = nil
      shazamConverter = nil
      shazamFeedUntil = nil
    }
    endDate = nil
    consecutiveMusicWindows = 0
    try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
  }

  func request(_ request: SNRequest, didProduce result: SNResult) {
    guard let classification = result as? SNClassificationResult else { return }
    let music = classification.classifications
      .filter { $0.identifier.lowercased().contains("music") || $0.identifier.lowercased().contains("singing") }
      .max(by: { $0.confidence < $1.confidence })
    DispatchQueue.main.async { [weak self] in
      guard let self, self.running else { return }
      self.currentLabel = music?.identifier ?? ""
      self.currentConfidence = music?.confidence ?? 0
      let threshold = 0.40
      let requiredWindows = 2
      if self.currentConfidence >= threshold {
        self.lastMusicEvidenceDate = Date()
        UserDefaults.standard.set(Int(Date().timeIntervalSince1970 * 1000), forKey: "MuzikYokLastMusicEvidenceMs")
      }
      self.consecutiveMusicWindows = self.currentConfidence >= threshold ? self.consecutiveMusicWindows + 1 : 0
      guard self.consecutiveMusicWindows >= requiredWindows else { return }
      self.consecutiveMusicWindows = 0
      let now = Date()
      guard self.suppressUntil.map({ now >= $0 }) ?? true else { return }
      guard self.lastAlertDate.map({ now.timeIntervalSince($0) >= self.alertCooldown }) ?? true else { return }
      self.issueMusicAlert(at: now)
    }
  }

  private var alertCooldown: TimeInterval {
    8
  }

  private func repeatAlertIfMusicContinues() {
    let now = Date()
    guard running,
          let lastAlertDate,
          let lastMusicEvidenceDate,
          now.timeIntervalSince(lastMusicEvidenceDate) < 8,
          now.timeIntervalSince(lastAlertDate) >= alertCooldown,
          suppressUntil.map({ now >= $0 }) ?? true else { return }
    issueMusicAlert(at: now)
  }

  private func issueMusicAlert(at now: Date) {
    lastAlertDate = now
    lastDetectionDate = now
    UserDefaults.standard.set(Int(now.timeIntervalSince1970 * 1000), forKey: "MuzikYokLastAlertMs")
    startShazamMatch(at: now)
    alertUser()
  }

  private func startShazamMatch(at now: Date) {
    guard lastShazamAttempt.map({ now.timeIntervalSince($0) >= 35 }) ?? true else { return }
    guard shazamConverter != nil else {
      songState = "unavailable"
      return
    }
    lastShazamAttempt = now
    songTitle = ""
    songArtist = ""
    songState = "searching"
    songError = ""
    analysisQueue.async { [weak self] in
      guard let self else { return }
      let session = SHSession()
      session.delegate = self
      self.shazamSession = session
      self.shazamFeedUntil = Date().addingTimeInterval(25)
    }
  }

  func session(_ session: SHSession, didFind match: SHMatch) {
    guard let item = match.mediaItems.first, let title = item.title, !title.isEmpty else { return }
    DispatchQueue.main.async { [weak self] in
      guard let self, self.running else { return }
      self.songTitle = title
      self.songArtist = item.artist ?? ""
      self.songState = "matched"
      if UIApplication.shared.applicationState != .active {
        let now = Date()
        self.lastMusicEvidenceDate = now
        if self.lastAlertDate.map({ now.timeIntervalSince($0) >= self.alertCooldown }) ?? true {
          self.issueMusicAlert(at: now)
        }
      }
    }
  }

  func session(_ session: SHSession, didNotFindMatchFor signature: SHSignature, error: Error?) {
    guard let error else { return }
    let nsError = error as NSError
    let message = Self.shazamErrorMessage(nsError)
    UserDefaults.standard.set("\(nsError.domain) \(nsError.code): \(nsError.localizedDescription)", forKey: "MuzikYokLastShazamError")
    DispatchQueue.main.async { [weak self] in
      guard let self, self.running, self.songState != "matched" else { return }
      self.songState = "error"
      self.songError = message
      // Network-type failures are usually transient: allow a new attempt after 10 s instead of 35 s.
      if nsError.domain == SHErrorDomain, nsError.code == SHError.Code.matchAttemptFailed.rawValue {
        self.lastShazamAttempt = Date().addingTimeInterval(-25)
      }
    }
  }

  private static func shazamErrorMessage(_ error: NSError) -> String {
    guard error.domain == SHErrorDomain, let code = SHError.Code(rawValue: error.code) else {
      return "Parça tanıma şu anda kullanılamıyor (\(error.domain) \(error.code))."
    }
    switch code {
    case .matchAttemptFailed:
      return "Shazam'a ulaşılamadı. İnternet bağlantısını kontrol et (SH \(error.code))."
    case .invalidAudioFormat, .audioDiscontinuity:
      return "Mikrofon sesi Shazam'a uygun değil (SH \(error.code))."
    case .signatureInvalid, .signatureDurationInvalid:
      return "Parça tanımak için ses yeterli değildi (SH \(error.code))."
    default:
      return "Parça tanıma şu anda kullanılamıyor (SH \(error.code))."
    }
  }

  func request(_ request: SNRequest, didFailWithError error: Error) {
    UserDefaults.standard.set(error.localizedDescription, forKey: "MuzikYokSoundAnalysisError")
  }

  private func alertUser() {
    if UIApplication.shared.applicationState == .active {
      lastDetectionNotifiedInBackground = false
      playAlertHaptics()
      return
    }
    lastDetectionNotifiedInBackground = true
    AudioServicesPlaySystemSound(kSystemSoundID_Vibrate)
    let content = UNMutableNotificationContent()
    content.title = "Yakında müzik algılandı"
    content.body = "Daha sessiz bir yere geçmek ister misin?"
    content.sound = .default
    let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
    UserDefaults.standard.set(Int(Date().timeIntervalSince1970 * 1000), forKey: "MuzikYokLastNotificationAttemptMs")
    UNUserNotificationCenter.current().add(request) { error in
      UserDefaults.standard.set(error?.localizedDescription ?? "", forKey: "MuzikYokLastNotificationError")
    }
  }

  func playAlertHaptics() {
    guard CHHapticEngine.capabilitiesForHardware().supportsHaptics else {
      AudioServicesPlaySystemSound(kSystemSoundID_Vibrate)
      return
    }
    do {
      if hapticEngine == nil {
        hapticEngine = try CHHapticEngine()
        hapticEngine?.playsHapticsOnly = true
      }
      let parameters = [
        CHHapticEventParameter(parameterID: .hapticIntensity, value: 1),
        CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.7),
      ]
      let events = [0.0, 0.85, 1.70, 2.55, 3.40].map {
        CHHapticEvent(eventType: .hapticContinuous, parameters: parameters, relativeTime: $0, duration: 0.72)
      }
      let pattern = try CHHapticPattern(events: events, parameters: [])
      let engine = hapticEngine!
      try engine.start()
      let player = try engine.makePlayer(with: pattern)
      try player.start(atTime: CHHapticTimeImmediate)
    } catch {
      UINotificationFeedbackGenerator().notificationOccurred(.warning)
      AudioServicesPlaySystemSound(kSystemSoundID_Vibrate)
    }
  }
}

private final class TonalMelodyDetector {
  private struct Frame {
    let time: Date
    let note: Int?
    let strength: Double
  }

  var enabled = false
  private(set) var lastAverageStrength = 0.0
  private(set) var lastStableNoteCount = 0
  private(set) var lastTonalFrameCount = 0
  private var frames: [Frame] = []
  private var lastCheck = Date.distantPast
  private var lastEmission = Date.distantPast
  private let baseFrequency = 130.8128

  func reset() {
    frames.removeAll(keepingCapacity: true)
    lastCheck = .distantPast
    lastEmission = .distantPast
    lastAverageStrength = 0
    lastStableNoteCount = 0
    lastTonalFrameCount = 0
  }

  func analyze(_ buffer: AVAudioPCMBuffer) -> Double? {
    guard enabled, let samples = buffer.floatChannelData?.pointee else { return nil }
    let now = Date()
    guard now.timeIntervalSince(lastCheck) >= 0.32 else { return nil }
    lastCheck = now

    let count = min(Int(buffer.frameLength), 4096)
    guard count >= 4096 else { return nil }
    var energy = 0.0
    for index in 0..<count {
      let sample = Double(samples[index])
      energy += sample * sample
    }
    let rms = sqrt(energy / Double(count))
    var bestNote: Int?
    var bestStrength = 0.0
    if rms >= 0.002 {
      let sampleRate = buffer.format.sampleRate
      for note in 0..<48 {
        let frequency = baseFrequency * pow(2, Double(note) / 12)
        let coefficient = 2 * cos(2 * .pi * frequency / sampleRate)
        var previous = 0.0
        var beforePrevious = 0.0
        for index in 0..<count {
          let value = Double(samples[index]) + coefficient * previous - beforePrevious
          beforePrevious = previous
          previous = value
        }
        let power = max(0, previous * previous + beforePrevious * beforePrevious - coefficient * previous * beforePrevious)
        let amplitude = 2 * sqrt(power) / Double(count)
        let strength = amplitude / (rms * sqrt(2))
        if strength > bestStrength {
          bestStrength = strength
          bestNote = note
        }
      }
    }

    frames.append(Frame(time: now, note: bestStrength >= 0.24 ? bestNote : nil, strength: bestStrength))
    frames.removeAll { now.timeIntervalSince($0.time) > 6 }
    lastTonalFrameCount = frames.filter { $0.note != nil }.count
    lastAverageStrength = min(1, frames.compactMap { $0.note == nil ? nil : $0.strength }.reduce(0, +) / Double(frames.count))
    guard frames.count >= 12,
          lastTonalFrameCount >= 9,
          now.timeIntervalSince(lastEmission) >= 5 else { return nil }

    var stableNotes: [Int] = []
    var runNote: Int?
    var runLength = 0
    func finishRun() {
      if let runNote, runLength >= 2,
         stableNotes.last.map({ abs($0 - runNote) >= 2 }) ?? true {
        stableNotes.append(runNote)
      }
    }
    for frame in frames {
      if let note = frame.note, let previous = runNote, abs(note - previous) <= 1 {
        runLength += 1
      } else {
        finishRun()
        runNote = frame.note
        runLength = frame.note == nil ? 0 : 1
      }
    }
    finishRun()
    lastStableNoteCount = stableNotes.count
    guard stableNotes.count >= 3,
          Set(stableNotes).count >= 3 else { return nil }
    let confidence = lastAverageStrength
    guard confidence >= 0.60 else { return nil }
    lastEmission = now
    return confidence
  }
}
