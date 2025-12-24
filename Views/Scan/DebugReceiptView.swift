//
//  DebugReceiptView.swift
//  FairShare
//
//  Debug view for OCR pipeline - development builds only
//

import SwiftUI

#if DEBUG

struct DebugReceiptView: View {
    let debugData: OCRDebugData
    @State private var selectedTab = 0
    
    var body: some View {
        VStack(spacing: 0) {
            // Tab selector
            Picker("View", selection: $selectedTab) {
                Text("Raw OCR").tag(0)
                Text("Processed").tag(1)
                Text("Summary").tag(2)
            }
            .pickerStyle(SegmentedPickerStyle())
            .padding()
            
            // Content based on selected tab
            ScrollView {
                switch selectedTab {
                case 0:
                    rawOCRView
                case 1:
                    processedView
                case 2:
                    summaryView
                default:
                    EmptyView()
                }
            }
        }
        .navigationTitle("OCR Debug")
        .navigationBarTitleDisplayMode(.inline)
    }
    
    private var rawOCRView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Raw OCR Observations")
                .font(.headline)
                .padding(.horizontal)
            
            ForEach(Array(debugData.rawObservations.enumerated()), id: \.offset) { index, observation in
                if let topCandidate = observation.topCandidates(1).first {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text("#\(index + 1)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text(topCandidate.string)
                                .font(.body)
                            Spacer()
                            Text(String(format: "%.2f", topCandidate.confidence))
                                .font(.caption)
                                .foregroundColor(confidenceColor(topCandidate.confidence))
                        }
                        
                        Text("Bounds: \(formatRect(observation.boundingBox))")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    .padding()
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(8)
                    .padding(.horizontal)
                }
            }
        }
        .padding(.vertical)
    }
    
    private var processedView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Processed Lines")
                .font(.headline)
                .padding(.horizontal)
            
            ForEach(Array(debugData.processedLines.enumerated()), id: \.offset) { index, line in
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("#\(index + 1)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(line.text)
                            .font(.body)
                        Spacer()
                        Text(String(format: "%.2f", line.confidence))
                            .font(.caption)
                            .foregroundColor(confidenceColor(line.confidence))
                    }
                    
                    if let classification = line.classification {
                        Label(classification.rawValue, systemImage: classificationIcon(classification))
                            .font(.caption)
                            .foregroundColor(classificationColor(classification))
                    }
                    
                    Text("Reason: \(line.classificationReason)")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    
                    if line.excluded, let reason = line.exclusionReason {
                        Text("EXCLUDED: \(reason)")
                            .font(.caption2)
                            .foregroundColor(.red)
                    }
                    
                    Text("Bounds: \(formatRect(line.boundingBox))")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                .padding()
                .background(line.excluded ? Color.red.opacity(0.1) : Color.gray.opacity(0.1))
                .cornerRadius(8)
                .padding(.horizontal)
            }
        }
        .padding(.vertical)
    }
    
    private var summaryView: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Processing Summary")
                .font(.headline)
                .padding(.horizontal)
            
            Group {
                SummaryRow(label: "Source Type", value: debugData.sourceType)
                SummaryRow(label: "Image Resolution", value: "\(Int(debugData.imageResolution.width))×\(Int(debugData.imageResolution.height))")
                SummaryRow(label: "Processing Time", value: String(format: "%.2fs", debugData.processingTime))
                SummaryRow(label: "Raw Observations", value: "\(debugData.rawObservations.count)")
                SummaryRow(label: "Processed Lines", value: "\(debugData.processedLines.count)")
                SummaryRow(label: "Excluded Lines", value: "\(debugData.processedLines.filter { $0.excluded }.count)")
            }
            .padding(.horizontal)
        }
        .padding(.vertical)
    }
    
    private func confidenceColor(_ confidence: Double) -> Color {
        if confidence >= 0.8 {
            return .green
        } else if confidence >= 0.5 {
            return .orange
        } else {
            return .red
        }
    }
    
    private func classificationColor(_ classification: BoundingBoxClassification) -> Color {
        switch classification {
        case .lineItem:
            return .blue
        case .subtotal:
            return .orange
        case .tax:
            return .yellow
        case .service:
            return .purple
        case .total:
            return .green
        }
    }
    
    private func classificationIcon(_ classification: BoundingBoxClassification) -> String {
        switch classification {
        case .lineItem:
            return "list.bullet"
        case .subtotal:
            return "sum"
        case .tax:
            return "percent"
        case .service:
            return "star"
        case .total:
            return "checkmark.circle"
        }
    }
    
    private func formatRect(_ rect: CGRect) -> String {
        return String(format: "(%.2f, %.2f, %.2f, %.2f)", rect.origin.x, rect.origin.y, rect.width, rect.height)
    }
}

struct SummaryRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(label)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .fontWeight(.medium)
        }
        .padding(.vertical, 4)
    }
}

#endif

