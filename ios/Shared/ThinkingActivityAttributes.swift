import ActivityKit
import Foundation

@available(iOS 16.1, *)
struct ThinkingActivityAttributes: ActivityAttributes {
  struct ContentState: Codable, Hashable {
    var startDate: Date
    var endDate: Date
  }

  var title: String
}
