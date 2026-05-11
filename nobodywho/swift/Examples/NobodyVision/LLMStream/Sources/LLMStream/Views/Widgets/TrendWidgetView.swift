import SwiftUI
import Charts

struct TrendWidgetView: View {
    let widget: TrendWidget

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let title = widget.riskScenarioName {
                Text(title)
                    .font(.headline)
            }

            if let data = widget.trendData, !data.isEmpty {
                Chart(data, id: \.timestamp) { point in
                    if let timestamp = point.timestamp, let eventLikelihood = point.eventLikelihood {
                        LineMark(
                            x: .value("Time", timestamp),
                            y: .value("Likelihood", eventLikelihood)
                        )
                    }
                }
                .frame(height: 200)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(uiColor: .secondarySystemBackground))
        .cornerRadius(12)
    }
}
