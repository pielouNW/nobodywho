//
//  TypingIndicator.swift
//  ValkyrieUI
//

import SwiftUI

/// Animated dot-dot-dot typing indicator
public struct TypingIndicator: View {
    @State private var dotCount = 0
    private let timer = Timer.publish(every: 0.5, on: .main, in: .common).autoconnect()

    public init() {}

    public var body: some View {
        HStack(spacing: 3) {
            ForEach(0..<3) { index in
                Circle()
                    .fill(Color.gray)
                    .frame(width: 5, height: 5)
                    .opacity(index < dotCount ? 1.0 : 0.3)
            }
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 4)
        .onReceive(timer) { _ in
            dotCount = (dotCount % 3) + 1
        }
    }
}
