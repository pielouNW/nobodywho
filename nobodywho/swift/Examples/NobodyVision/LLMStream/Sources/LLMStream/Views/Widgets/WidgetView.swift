import SwiftUI
import Foundation

struct WidgetView: View {
    var widget: Widget

    var body: some View {
        switch widget {
        case .trend(let trend):
            TrendWidgetView(widget: trend)
        }
    }
}
