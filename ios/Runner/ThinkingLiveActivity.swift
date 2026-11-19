import ActivityKit
import Foundation

@available(iOS 16.2, *)
@MainActor
enum ThinkingLiveActivity {
  private static var pending: Task<Void, Never>?

  static var isAvailable: Bool {
    ActivityAuthorizationInfo().areActivitiesEnabled
  }

  static func start(endDate: Date) {
    let previous = pending
    pending = Task {
      await previous?.value
      await endExisting()
      guard isAvailable, endDate > Date() else { return }
      let state = ThinkingActivityAttributes.ContentState(
        startDate: Date(),
        endDate: endDate
      )
      let content = ActivityContent(state: state, staleDate: endDate)
      do {
        _ = try Activity.request(
          attributes: ThinkingActivityAttributes(title: "Düşünme Modu"),
          content: content,
          pushType: nil
        )
      } catch {
        NSLog("MuzikYok Live Activity start failed: %@", error.localizedDescription)
      }
    }
  }

  static func stop() {
    let previous = pending
    pending = Task {
      await previous?.value
      await endExisting()
    }
  }

  private static func endExisting() async {
    for activity in Activity<ThinkingActivityAttributes>.activities {
      await activity.end(nil, dismissalPolicy: .immediate)
    }
  }
}
