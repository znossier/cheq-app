//
//  ReceiptPreviewView.swift
//  Cheq
//
//  Preview component showing frozen receipt image with highlighted bounding boxes
//

import SwiftUI

struct ReceiptPreviewView: View {
    let image: UIImage
    let boundingBoxes: [BoundingBox]
    let ocrResult: OCRResult
    let onConfirm: () -> Void
    let onRetry: () -> Void
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Receipt image with bounding boxes
                GeometryReader { geometry in
                    let imageSize = image.size
                    let displaySize = geometry.size
                    let scaleX = displaySize.width / imageSize.width
                    let scaleY = displaySize.height / imageSize.height
                    let scale = min(scaleX, scaleY) // Maintain aspect ratio
                    let scaledWidth = imageSize.width * scale
                    let scaledHeight = imageSize.height * scale
                    let offsetX = (displaySize.width - scaledWidth) / 2
                    let offsetY = (displaySize.height - scaledHeight) / 2
                    
                    ZStack {
                        Image(uiImage: image)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                        
                        // Overlay bounding boxes
                        ForEach(boundingBoxes) { box in
                            Rectangle()
                                .stroke(boxColor(for: box.classification), lineWidth: 2)
                                .frame(
                                    width: box.rectangle.width * scale,
                                    height: box.rectangle.height * scale
                                )
                                .position(
                                    x: offsetX + box.rectangle.midX * scale,
                                    y: offsetY + box.rectangle.midY * scale
                                )
                        }
                    }
                }
                .frame(height: 400)
                .padding()
                
                // Parsed values summary
                VStack(alignment: .leading, spacing: 12) {
                    Text("Extracted Information")
                        .font(.headline)
                        .padding(.horizontal)
                    
                    if !ocrResult.items.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Items (\(ocrResult.items.count))")
                                .font(.subheadline)
                                .foregroundColor(.appTextSecondary)
                            
                            ForEach(Array(ocrResult.items.prefix(5))) { item in
                                HStack {
                                    Text(item.name)
                                    Spacer()
                                    Text(item.totalPrice.formatted(currency: StorageService.shared.loadCurrency()))
                                }
                                .font(.caption)
                            }
                            
                            if ocrResult.items.count > 5 {
                                Text("... and \(ocrResult.items.count - 5) more")
                                    .font(.caption)
                                    .foregroundColor(.appTextSecondary)
                            }
                        }
                        .padding(.horizontal)
                    }
                    
                    if let subtotal = ocrResult.subtotal {
                        HStack {
                            Text("Subtotal:")
                            Spacer()
                            Text(subtotal.formatted(currency: StorageService.shared.loadCurrency()))
                        }
                        .padding(.horizontal)
                    }
                    
                    if let total = ocrResult.total {
                        HStack {
                            Text("Total:")
                                .fontWeight(.bold)
                            Spacer()
                            Text(total.formatted(currency: StorageService.shared.loadCurrency()))
                                .fontWeight(.bold)
                        }
                        .padding(.horizontal)
                    }
                }
                
                // Action buttons
                HStack(spacing: 16) {
                    Button(action: onRetry) {
                        Text("Retry")
                            .font(.headline)
                            .foregroundColor(.appPrimary)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.appPrimary.opacity(0.1))
                            .cornerRadius(12)
                    }
                    
                    Button(action: onConfirm) {
                        Text("Confirm")
                            .font(.headline)
                            .foregroundColor(.appButtonTextOnMint)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.appPrimary)
                            .cornerRadius(12)
                    }
                }
                .padding(.horizontal)
                .padding(.bottom)
            }
        }
    }
    
    private func boxColor(for classification: BoundingBoxClassification) -> Color {
        switch classification {
        case .lineItem:
            return .appPrimary
        case .subtotal:
            return .orange
        case .tax:
            return .yellow
        case .service:
            return .purple
        case .total:
            return .appMint
        }
    }
}

