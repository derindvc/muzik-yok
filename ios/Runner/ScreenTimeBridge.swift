import DeviceActivity
import FamilyControls
import Flutter
import ManagedSettings
import SwiftUI
import UIKit

@available(iOS 16.0, *)
final class ScreenTimeBridge {
  private let selectionKey = "MuzikYokSelectedActivities"
  private let endKey = "MuzikYokShieldEnd"
  private let activity = DeviceActivityName("MuzikYokThinking")
  private let store = ManagedSettingsStore(named: .init("MuzikYokThinking"))
  private let center = DeviceActivityCenter()
  private var selection: FamilyActivitySelection

  init() {
    if let data = UserDefaults.standard.data(forKey: selectionKey),
       let saved = try? PropertyListDecoder().decode(FamilyActivitySelection.self, from: data) {
      selection = saved
    } else {
      selection = FamilyActivitySelection()
    }
    clearExpiredShield()
  }

  var status: [String: Any] {
    clearExpiredShield()
    let end = UserDefaults.standard.object(forKey: endKey) as? Date
    return [
      "available": screenTimeAvailable,
      "authorized": AuthorizationCenter.shared.authorizationStatus == .approved,
      "selectedCount": selection.applicationTokens.count + selection.categoryTokens.count,
      "shieldActive": end.map { $0 > Date() } ?? false,
      "remainingSeconds": max(0, Int(ceil(end?.timeIntervalSinceNow ?? 0))),
    ]
  }

  func pickApplications(result: @escaping FlutterResult) {
    guard screenTimeAvailable else {
      result(FlutterError(code: "SCREEN_TIME_UNAVAILABLE", message: "Bu Apple geliştirme hesabı Ekran Süresi uygulama engeline izin vermiyor.", details: nil))
      return
    }
    Task { @MainActor in
      do {
        try await AuthorizationCenter.shared.requestAuthorization(for: .individual)
        guard let root = UIApplication.shared.connectedScenes
          .compactMap({ $0 as? UIWindowScene })
          .flatMap({ $0.windows })
          .first(where: { $0.isKeyWindow })?.rootViewController else {
          throw NSError(domain: "MuzikYok", code: 20, userInfo: [NSLocalizedDescriptionKey: "Uygulama seçici açılamadı."])
        }
        let picker = AppPickerView(initial: selection) { [weak self] updated in
          guard let self else { return }
          self.selection = updated
          if let data = try? PropertyListEncoder().encode(updated) {
            UserDefaults.standard.set(data, forKey: self.selectionKey)
          }
          root.dismiss(animated: true)
          result(self.status)
        } onCancel: {
          root.dismiss(animated: true)
          result(nil)
        }
        let controller = UIHostingController(rootView: picker)
        controller.modalPresentationStyle = .pageSheet
        root.present(controller, animated: true)
      } catch {
        result(FlutterError(code: "SCREEN_TIME_AUTH", message: error.localizedDescription, details: nil))
      }
    }
  }

  func startShield(durationSeconds: Int) throws -> [String: Any] {
    guard screenTimeAvailable else {
      throw NSError(domain: "MuzikYok", code: 24, userInfo: [NSLocalizedDescriptionKey: "Ekran Süresi yetkisi bu geliştirme hesabında yok."])
    }
    clearExpiredShield()
    guard AuthorizationCenter.shared.authorizationStatus == .approved else {
      throw NSError(domain: "MuzikYok", code: 21, userInfo: [NSLocalizedDescriptionKey: "Ekran Süresi izni gerekli."])
    }
    guard !selection.applicationTokens.isEmpty || !selection.categoryTokens.isEmpty else {
      throw NSError(domain: "MuzikYok", code: 22, userInfo: [NSLocalizedDescriptionKey: "Önce engellenecek uygulamaları seç."])
    }
    guard durationSeconds >= 900 else {
      throw NSError(domain: "MuzikYok", code: 23, userInfo: [NSLocalizedDescriptionKey: "Uygulama kilidi için en az 15 dakika seçmelisin."])
    }
    let now = Date()
    let end = now.addingTimeInterval(TimeInterval(durationSeconds))
    let calendar = Calendar.current
    guard end.timeIntervalSince1970.isFinite,
          let startMinute = calendar.dateInterval(of: .minute, for: now)?.start,
          let endMinute = calendar.dateInterval(of: .minute, for: end)?.start else {
      throw NSError(domain: "MuzikYok", code: 25, userInfo: [NSLocalizedDescriptionKey: "Bu süre iPhone'un tarih aralığını aşıyor."])
    }
    let scheduleStart = now > startMinute ? startMinute.addingTimeInterval(60) : startMinute
    let scheduleEnd = end > endMinute ? endMinute.addingTimeInterval(60) : endMinute
    let fields: Set<Calendar.Component> = durationSeconds < 86400
      ? [.hour, .minute]
      : [.year, .month, .day, .hour, .minute]
    let schedule = DeviceActivitySchedule(
      intervalStart: calendar.dateComponents(fields, from: scheduleStart),
      intervalEnd: calendar.dateComponents(fields, from: scheduleEnd),
      repeats: false
    )
    try center.startMonitoring(activity, during: schedule)
    store.shield.applications = selection.applicationTokens.isEmpty ? nil : selection.applicationTokens
    store.shield.applicationCategories = selection.categoryTokens.isEmpty ? nil : .specific(selection.categoryTokens, except: [])
    UserDefaults.standard.set(end, forKey: endKey)
    return status
  }

  func stopShield() -> [String: Any] {
    store.clearAllSettings()
    UserDefaults.standard.removeObject(forKey: endKey)
    return status
  }

  private var screenTimeAvailable: Bool {
    #if PERSONAL_BUILD
    return false
    #else
    return true
    #endif
  }

  private func clearExpiredShield() {
    guard let end = UserDefaults.standard.object(forKey: endKey) as? Date, end <= Date() else { return }
    store.clearAllSettings()
    UserDefaults.standard.removeObject(forKey: endKey)
  }
}

@available(iOS 16.0, *)
private struct AppPickerView: View {
  @State private var selection: FamilyActivitySelection
  let onDone: (FamilyActivitySelection) -> Void
  let onCancel: () -> Void

  init(initial: FamilyActivitySelection, onDone: @escaping (FamilyActivitySelection) -> Void, onCancel: @escaping () -> Void) {
    _selection = State(initialValue: initial)
    self.onDone = onDone
    self.onCancel = onCancel
  }

  var body: some View {
    NavigationView {
      FamilyActivityPicker(selection: $selection)
        .navigationTitle("Uygulamaları seç")
        .toolbar {
          ToolbarItem(placement: .cancellationAction) { Button("Vazgeç", action: onCancel) }
          ToolbarItem(placement: .confirmationAction) { Button("Kaydet") { onDone(selection) } }
        }
    }
  }
}
