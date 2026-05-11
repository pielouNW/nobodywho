import SwiftUI
import Foundation

struct ContainerWidgetView: View {
    let container: ContainerWidget

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(alignment: .top, spacing: 10) {
                    ForEach(container.widgets) { widget in
                        WidgetView(widget: widget.value)
                            .containerRelativeFrame(.horizontal, count: 1, spacing: 10, alignment: .trailing)
                    }
                }
                .scrollTargetLayout()
                .id("content")
                .animation(.default, value: container.widgets.last)
            }
            .scrollTargetBehavior(.viewAligned)
            .onChange(of: container.widgets.last) {
                withAnimation(.linear(duration: 0.2)) {
                    proxy.scrollTo("content", anchor: .trailing)
                }
            }
        }
        .scrollClipDisabled()
        .safeAreaPadding(.horizontal)
    }
}
