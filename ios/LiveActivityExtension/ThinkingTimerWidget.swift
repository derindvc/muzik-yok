import ActivityKit
import SwiftUI
import WidgetKit

@main
struct ThinkingTimerBundle: WidgetBundle {
  var body: some Widget {
    ThinkingTimerWidget()
  }
}

struct ThinkingTimerWidget: Widget {
  var body: some WidgetConfiguration {
    ActivityConfiguration(for: ThinkingActivityAttributes.self) { context in
      HStack(alignment: .center, spacing: 16) {
        VStack(alignment: .leading, spacing: 4) {
          Text("MÜZİK YOK")
            .font(.caption2.weight(.bold))
            .tracking(1.5)
            .foregroundStyle(Color(red: 0.28, green: 0.89, blue: 0.50))
          Text("Düşünme Modu")
            .font(.headline)
            .foregroundStyle(.white)
        }
        Spacer(minLength: 8)
        Text(timerInterval: context.state.startDate...context.state.endDate, countsDown: true, showsHours: true)
          .font(.system(size: 32, weight: .medium, design: .rounded))
          .monospacedDigit()
          .foregroundStyle(.white)
      }
      .padding(18)
      .activityBackgroundTint(Color(red: 0.04, green: 0.07, blue: 0.05))
      .activitySystemActionForegroundColor(Color(red: 0.28, green: 0.89, blue: 0.50))
    } dynamicIsland: { context in
      DynamicIsland {
        DynamicIslandExpandedRegion(.leading) {
          Text("Düşünme Modu").font(.headline)
        }
        DynamicIslandExpandedRegion(.trailing) {
          Text(timerInterval: context.state.startDate...context.state.endDate, countsDown: true, showsHours: true)
            .monospacedDigit()
        }
      } compactLeading: {
        Image(systemName: "brain.head.profile")
      } compactTrailing: {
        Text(timerInterval: context.state.startDate...context.state.endDate, countsDown: true)
          .monospacedDigit()
      } minimal: {
        Image(systemName: "brain.head.profile")
      }
    }
  }
}
