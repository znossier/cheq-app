//
//  ReceiptStructureAnalyzer.swift
//  Cheq
//
//  Receipt structure analysis for improved OCR parsing
//

import Foundation
import Vision

struct ReceiptZone {
    let type: ZoneType
    let yRange: ClosedRange<CGFloat> // Normalized Y coordinates (0.0 = bottom, 1.0 = top in Vision)
    
    enum ZoneType {
        case header
        case items
        case footer
    }
}

struct ColumnAlignment {
    let priceColumnX: CGFloat // Normalized X coordinate for price column
    let priceColumnWidth: CGFloat // Width of price column
    let confidence: Double
}

class ReceiptStructureAnalyzer {
    
    /// Analyze receipt structure and identify zones (header, items, footer)
    static func analyzeZones(from observations: [VNRecognizedTextObservation], imageSize: CGSize) -> [ReceiptZone] {
        guard !observations.isEmpty else { return [] }
        
        // Get Y positions of all observations (Vision uses bottom-left origin)
        let yPositions = observations.map { $0.boundingBox.minY }.sorted()
        
        guard let minY = yPositions.first,
              let maxY = yPositions.last else {
            return []
        }
        
        let height = maxY - minY
        
        // Define zones based on Y position
        // Header: top 30% (minY + 0.7*height to maxY)
        // Items: middle 40% (minY + 0.3*height to minY + 0.7*height)
        // Footer: bottom 30% (minY to minY + 0.3*height)
        
        let headerStart = minY + 0.7 * height
        let itemsStart = minY + 0.3 * height
        let itemsEnd = minY + 0.7 * height
        
        var zones: [ReceiptZone] = []
        
        if headerStart < maxY {
            zones.append(ReceiptZone(
                type: .header,
                yRange: headerStart...maxY
            ))
        }
        
        if itemsStart < itemsEnd {
            zones.append(ReceiptZone(
                type: .items,
                yRange: itemsStart...itemsEnd
            ))
        }
        
        if minY < itemsStart {
            zones.append(ReceiptZone(
                type: .footer,
                yRange: minY...itemsStart
            ))
        }
        
        return zones
    }
    
    /// Detect price column alignment by analyzing X positions of price-like text
    static func detectPriceColumn(from observations: [VNRecognizedTextObservation], imageSize: CGSize) -> ColumnAlignment? {
        // Extract observations that likely contain prices
        var pricePositions: [CGFloat] = []
        
        for observation in observations {
            guard let topCandidate = observation.topCandidates(1).first else { continue }
            let text = topCandidate.string
            
            // Check if text contains a price pattern
            let pricePattern = #"[\$]?(\d{1,3}(?:[,\s]\d{3})*(?:\.\d{2})?)"#
            if let regex = try? NSRegularExpression(pattern: pricePattern),
               regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)) != nil {
                // This observation likely contains a price
                // Use the right edge of the bounding box as price position
                let normalizedX = observation.boundingBox.maxX
                pricePositions.append(normalizedX)
            }
        }
        
        guard !pricePositions.isEmpty else { return nil }
        
        // Find the most common X position (price column)
        // Group positions within 5% of image width
        let tolerance = 0.05
        var groupedPositions: [CGFloat: Int] = [:]
        
        for position in pricePositions {
            // Find existing group within tolerance
            var foundGroup: CGFloat? = nil
            for groupPosition in groupedPositions.keys {
                if abs(position - groupPosition) < tolerance {
                    foundGroup = groupPosition
                    break
                }
            }
            
            if let group = foundGroup {
                groupedPositions[group] = (groupedPositions[group] ?? 0) + 1
            } else {
                groupedPositions[position] = 1
            }
        }
        
        // Find the group with most positions (most likely price column)
        guard let bestGroup = groupedPositions.max(by: { $0.value < $1.value }) else {
            return nil
        }
        
        // Calculate average X position for this group
        let groupPositions = pricePositions.filter { abs($0 - bestGroup.key) < tolerance }
        let avgX = groupPositions.reduce(0, +) / CGFloat(groupPositions.count)
        
        // Calculate column width (standard deviation of positions in group)
        let variance = groupPositions.map { pow($0 - avgX, 2) }.reduce(0, +) / CGFloat(groupPositions.count)
        let stdDev = sqrt(variance)
        let columnWidth = max(stdDev * 2, 0.02) // Minimum 2% width
        
        // Confidence based on how many prices align
        let confidence = min(1.0, Double(bestGroup.value) / Double(pricePositions.count))
        
        return ColumnAlignment(
            priceColumnX: avgX,
            priceColumnWidth: columnWidth,
            confidence: confidence
        )
    }
    
    /// Check if an observation's price is aligned with the detected price column
    static func isPriceAligned(_ observation: VNRecognizedTextObservation, columnAlignment: ColumnAlignment) -> Bool {
        let observationX = observation.boundingBox.maxX
        let distance = abs(observationX - columnAlignment.priceColumnX)
        return distance <= columnAlignment.priceColumnWidth
    }
    
    /// Group multi-line items more intelligently based on structure
    static func groupMultiLineItems(
        lines: [(text: String, observation: VNRecognizedTextObservation, confidence: Double)],
        imageSize: CGSize,
        priceColumn: ColumnAlignment?
    ) -> [(text: String, observation: VNRecognizedTextObservation, confidence: Double)] {
        var groupedLines: [(text: String, observation: VNRecognizedTextObservation, confidence: Double)] = []
        var processedIndices = Set<Int>()
        
        // Vertical proximity threshold: 3% of receipt height
        let proximityThreshold = imageSize.height * 0.03
        
        for i in 0..<lines.count {
            if processedIndices.contains(i) {
                continue
            }
            
            let (currentText, currentObs, currentConf) = lines[i]
            let currentRect = VNImageRectForNormalizedRect(
                currentObs.boundingBox,
                Int(imageSize.width),
                Int(imageSize.height)
            )
            
            // Check if current line has text but no price
            let hasPrice = hasPriceInLine(currentText)
            let hasText = currentText.rangeOfCharacter(from: CharacterSet.letters) != nil
            
            // If line has text but no price, check next line
            if hasText && !hasPrice && i + 1 < lines.count {
                let (nextText, nextObs, nextConf) = lines[i + 1]
                let nextRect = VNImageRectForNormalizedRect(
                    nextObs.boundingBox,
                    Int(imageSize.width),
                    Int(imageSize.height)
                )
                
                // Check vertical proximity
                let verticalDistance = abs(currentRect.maxY - nextRect.minY)
                
                if verticalDistance <= proximityThreshold {
                    let nextHasPrice = hasPriceInLine(nextText)
                    
                    // If next line has price, check alignment if we have price column info
                    var shouldMerge = true
                    if let priceColumn = priceColumn, nextHasPrice {
                        // Only merge if price is aligned with price column
                        shouldMerge = isPriceAligned(nextObs, columnAlignment: priceColumn)
                    }
                    
                    if shouldMerge && nextHasPrice {
                        // Merge: combine text
                        let combinedText = "\(currentText) \(nextText)".trimmingCharacters(in: .whitespaces)
                        let combinedConfidence = max(currentConf, nextConf)
                        
                        groupedLines.append((combinedText, currentObs, combinedConfidence))
                        processedIndices.insert(i)
                        processedIndices.insert(i + 1)
                        continue
                    }
                }
            }
            
            // No grouping, add line as-is
            groupedLines.append((currentText, currentObs, currentConf))
            processedIndices.insert(i)
        }
        
        return groupedLines
    }
    
    /// Check if a line contains a price
    private static func hasPriceInLine(_ text: String) -> Bool {
        let pricePattern = #"[\$]?(\d{1,3}(?:[,\s]\d{3})*(?:\.\d{2})?)"#
        if let regex = try? NSRegularExpression(pattern: pricePattern) {
            return regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)) != nil
        }
        return false
    }
}

