//
//  LoadingSpinner.swift
//  Transnap
//
//  Created by Codex on 2026/4/15.
//

import SwiftUI

struct LoadingSpinner: View {
    var size: CGFloat = 16
    var lineWidth: CGFloat = 1.8
    var tint: Color = .secondary

    @State private var isAnimating = false

    var body: some View {
        Circle()
            .trim(from: 0.18, to: 0.92)
            .stroke(tint, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
            .frame(width: size, height: size)
            .rotationEffect(.degrees(isAnimating ? 360 : 0))
            .animation(.linear(duration: 0.9).repeatForever(autoreverses: false), value: isAnimating)
            .onAppear {
                isAnimating = true
            }
    }
}
