import DeviceActivity
import ManagedSettings

class ThinkingMonitorExtension: DeviceActivityMonitor {
  private let store = ManagedSettingsStore(named: .init("MuzikYokThinking"))

  override func intervalDidEnd(for activity: DeviceActivityName) {
    super.intervalDidEnd(for: activity)
    guard activity.rawValue == "MuzikYokThinking" else { return }
    store.clearAllSettings()
  }
}
