//
//  ReceiptBoundingBoxOverlay.swift
//  Cheq
//
//  Bounding box overlay for receipt detection (CamScanner-style)
//

import SwiftUI

struct ReceiptBoundingBoxOverlay: View {
    let boundingRect: CGRect?
    let state: ScanningState
    let viewSize: CGSize
    
    @State private var animationPhase: CGFloat = 0
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                if let rect = boundingRect, shouldShowOverlay {
                    // Semi-transparent overlay outside the rectangle
                    overlayMask(rect: rect, in: geometry.size)
                        .transition(.opacity)
                    
                    // Bounding box border with animation
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(borderColor, lineWidth: borderWidth)
                        .frame(width: rect.width, height: rect.height)
                        .position(x: rect.midX, y: rect.midY)
                        .overlay(
                            // Corner indicators
                            cornerIndicators(rect: rect)
                        )
                        .transition(.opacity.combined(with: .scale(scale: 0.95)))
                }
            }
        }
        .animation(.easeInOut(duration: 0.3), value: boundingRect)
        .animation(.easeInOut(duration: 0.3), value: state)
        .onChange(of: state) { _, _ in
            // Reset animation when state changes
            animationPhase = 0
            if shouldShowOverlay {
                startAnimation()
            }
        }
        .onChange(of: boundingRect) { _, _ in
            if shouldShowOverlay {
                startAnimation()
            }
        }
        .onAppear {
            if shouldShowOverlay {
                startAnimation()
            }
        }
    }
    
    private var shouldShowOverlay: Bool {
        state == .receiptCandidateDetected || state == .stableReceiptConfirmed
    }
    
    private var borderColor: Color {
        switch state {
        case .receiptCandidateDetected:
            return .orange
        case .stableReceiptConfirmed:
            // Animated green color (slightly pulsing)
            return Color.green.opacity(0.8 + sin(animationPhase * .pi * 2) * 0.2)
        default:
            return .clear
        }
    }
    
    private var borderWidth: CGFloat {
        // Animated border width for stable state
        if state == .stableReceiptConfirmed {
            return 3 + sin(animationPhase * .pi * 2) * 1
        }
        return 3
    }
    
    /// Create a mask that covers everything except the bounding rectangle
    private func overlayMask(rect: CGRect, in size: CGSize) -> some View {
        ZStack {
            // Full overlay
            Rectangle()
                .fill(Color.black.opacity(0.4))
                .frame(width: size.width, height: size.height)
            
            // Cut out the rectangle area
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.clear)
                .frame(width: rect.width, height: rect.height)
                .position(x: rect.midX, y: rect.midY)
                .blendMode(.destinationOut)
        }
        .compositingGroup()
    }
    
    /// Corner indicators (like CamScanner)
    @ViewBuilder
    private func cornerIndicators(rect: CGRect) -> some View {
        let cornerLength: CGFloat = 20
        let cornerWidth: CGFloat = 3
        
        Group {
            // Top-left corner
            cornerIndicator(
                position: CGPoint(x: rect.minX, y: rect.minY),
                cornerLength: cornerLength,
                cornerWidth: cornerWidth,
                corner: .topLeft
            )
            
            // Top-right corner
            cornerIndicator(
                position: CGPoint(x: rect.maxX, y: rect.minY),
                cornerLength: cornerLength,
                cornerWidth: cornerWidth,
                corner: .topRight
            )
            
            // Bottom-left corner
            cornerIndicator(
                position: CGPoint(x: rect.minX, y: rect.maxY),
                cornerLength: cornerLength,
                cornerWidth: cornerWidth,
                corner: .bottomLeft
            )
            
            // Bottom-right corner
            cornerIndicator(
                position: CGPoint(x: rect.maxX, y: rect.maxY),
                cornerLength: cornerLength,
                cornerWidth: cornerWidth,
                corner: .bottomRight
            )
        }
    }
    
    @ViewBuilder
    private func cornerIndicator(
        position: CGPoint,
        cornerLength: CGFloat,
        cornerWidth: CGFloat,
        corner: CornerPosition
    ) -> some View {
        Path { path in
            switch corner {
            case .topLeft:
                // Horizontal line
                path.move(to: CGPoint(x: position.x, y: position.y))
                path.addLine(to: CGPoint(x: position.x + cornerLength, y: position.y))
                // Vertical line
                path.move(to: CGPoint(x: position.x, y: position.y))
                path.addLine(to: CGPoint(x: position.x, y: position.y + cornerLength))
                
            case .topRight:
                // Horizontal line
                path.move(to: CGPoint(x: position.x, y: position.y))
                path.addLine(to: CGPoint(x: position.x - cornerLength, y: position.y))
                // Vertical line
                path.move(to: CGPoint(x: position.x, y: position.y))
                path.addLine(to: CGPoint(x: position.x, y: position.y + cornerLength))
                
            case .bottomLeft:
                // Horizontal line
                path.move(to: CGPoint(x: position.x, y: position.y))
                path.addLine(to: CGPoint(x: position.x + cornerLength, y: position.y))
                // Vertical line
                path.move(to: CGPoint(x: position.x, y: position.y))
                path.addLine(to: CGPoint(x: position.x, y: position.y - cornerLength))
                
            case .bottomRight:
                // Horizontal line
                path.move(to: CGPoint(x: position.x, y: position.y))
                path.addLine(to: CGPoint(x: position.x - cornerLength, y: position.y))
                // Vertical line
                path.move(to: CGPoint(x: position.x, y: position.y))
                path.addLine(to: CGPoint(x: position.x, y: position.y - cornerLength))
            }
        }
        .stroke(borderColor, lineWidth: cornerWidth)
        .position(position)
    }
    
    private func startAnimation() {
        // Only animate if we have a bounding rect and are in a state that should show overlay
        guard shouldShowOverlay else { return }
        
        withAnimation(.linear(duration: 2.0).repeatForever(autoreverses: false)) {
            animationPhase = 1.0
        }
    }
    
    private enum CornerPosition {
        case topLeft
        case topRight
        case bottomLeft
        case bottomRight
    }
}

