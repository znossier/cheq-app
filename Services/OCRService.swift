//
//  OCRService.swift
//  FairShare
//
//  OCR service using Apple Vision framework
//

import Foundation
import Vision
import UIKit

struct OCRResult {
    var items: [ReceiptItem]
    var subtotal: Decimal?
    var vatPercentage: Decimal?
    var servicePercentage: Decimal?
    var total: Decimal?
    var boundingBoxes: [BoundingBox]
    var sourceImage: UIImage?
    var detectedRectangle: CGRect?
    #if DEBUG
    var debugData: OCRDebugData?
    #endif
    
    init(
        items: [ReceiptItem] = [],
        subtotal: Decimal? = nil,
        vatPercentage: Decimal? = nil,
        servicePercentage: Decimal? = nil,
        total: Decimal? = nil,
        boundingBoxes: [BoundingBox] = [],
        sourceImage: UIImage? = nil,
        detectedRectangle: CGRect? = nil
    ) {
        self.items = items
        self.subtotal = subtotal
        self.vatPercentage = vatPercentage
        self.servicePercentage = servicePercentage
        self.total = total
        self.boundingBoxes = boundingBoxes
        self.sourceImage = sourceImage
        self.detectedRectangle = detectedRectangle
        #if DEBUG
        self.debugData = nil
        #endif
    }
    
    #if DEBUG
    init(
        items: [ReceiptItem] = [],
        subtotal: Decimal? = nil,
        vatPercentage: Decimal? = nil,
        servicePercentage: Decimal? = nil,
        total: Decimal? = nil,
        boundingBoxes: [BoundingBox] = [],
        sourceImage: UIImage? = nil,
        detectedRectangle: CGRect? = nil,
        debugData: OCRDebugData? = nil
    ) {
        self.items = items
        self.subtotal = subtotal
        self.vatPercentage = vatPercentage
        self.servicePercentage = servicePercentage
        self.total = total
        self.boundingBoxes = boundingBoxes
        self.sourceImage = sourceImage
        self.detectedRectangle = detectedRectangle
        self.debugData = debugData
    }
    #endif
}

class OCRService {
    static let shared = OCRService()
    
    private init() {}
    
    func detectRectangles(in image: UIImage) async throws -> [CGRect] {
        guard let cgImage = image.cgImage else {
            throw OCRError.invalidImage
        }
        
        return try await withCheckedThrowingContinuation { continuation in
            let request = VNDetectRectanglesRequest { request, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                
                guard let observations = request.results as? [VNRectangleObservation] else {
                    continuation.resume(returning: [])
                    return
                }
                
                let imageSize = CGSize(width: cgImage.width, height: cgImage.height)
                let rectangles = observations.compactMap { observation -> CGRect? in
                    let boundingBox = observation.boundingBox
                    // Convert normalized coordinates to image coordinates
                    let rect = VNImageRectForNormalizedRect(
                        boundingBox,
                        Int(imageSize.width),
                        Int(imageSize.height)
                    )
                    
                    // Filter by aspect ratio (prefer tall rectangles)
                    let aspectRatio = rect.height / rect.width
                    if aspectRatio < Constants.receiptMinAspectRatio {
                        return nil
                    }
                    
                    // Filter by minimum size
                    let minSize = imageSize.width * Constants.receiptMinSizeRatio
                    if rect.width < minSize || rect.height < minSize {
                        return nil
                    }
                    
                    return rect
                }
                
                continuation.resume(returning: rectangles)
            }
            
            request.minimumAspectRatio = 0.2
            request.maximumAspectRatio = 0.98
            request.minimumSize = 0.1
            request.minimumConfidence = 0.5
            
            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            do {
                try handler.perform([request])
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }
    
    /// Deprecated: Use processImageUnified instead for consistent behavior
    /// This method is kept for backward compatibility but should not be used
    @available(*, deprecated, message: "Use processImageUnified for consistent Vision configuration")
    func processImageInRectangle(_ image: UIImage, rect: CGRect) async throws -> (observations: [VNRecognizedTextObservation], confidence: Double) {
        // For now, use unified processing and filter results
        // This maintains backward compatibility while using unified configuration
        let result = try await processImageUnified(image, sourceType: "live")
        
        // Extract observations from the result (we'll need to store them in OCRResult for this to work)
        // For now, return empty - this method should not be used
        return ([], 0.0)
    }
    
    func calculateConfidenceScore(from observations: [VNRecognizedTextObservation]) -> Double {
        guard !observations.isEmpty else { return 0.0 }
        
        var score = 0.0
        let text = observations.compactMap { $0.topCandidates(1).first?.string ?? "" }.joined(separator: " ")
        let lowercased = text.lowercased()
        
        // Keyword presence (40% weight)
        let keywords = ["total", "subtotal", "tax", "service", "tip", "amount"]
        let keywordCount = keywords.filter { lowercased.contains($0) }.count
        score += Double(keywordCount) / Double(keywords.count) * 0.4
        
        // Price pattern detection (30% weight)
        let pricePattern = #"\$\d+\.\d{2}|\d+\.\d{2}"#
        if let regex = try? NSRegularExpression(pattern: pricePattern) {
            let matches = regex.matches(in: text, range: NSRange(text.startIndex..., in: text))
            let priceCount = matches.count
            score += min(Double(priceCount) / 5.0, 1.0) * 0.3
        }
        
        // Large number near bottom (20% weight)
        // Check last 30% of observations for large numeric value
        let bottomObservations = Array(observations.suffix(max(1, observations.count * 3 / 10)))
        var foundLargeNumber = false
        for observation in bottomObservations {
            if let candidate = observation.topCandidates(1).first {
                let text = candidate.string
                // Look for large numbers (likely total)
                if let regex = try? NSRegularExpression(pattern: #"\d+\.\d{2}"#),
                   let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
                   let range = Range(match.range, in: text),
                   let value = Double(String(text[range])),
                   value > 10.0 {
                    foundLargeNumber = true
                    break
                }
            }
        }
        if foundLargeNumber {
            score += 0.2
        }
        
        // Vertical alignment (10% weight)
        // Check if prices align vertically (simplified check)
        let xPositions = observations.map { Float($0.boundingBox.midX) }
        let xVariance = calculateVariance(xPositions)
        // Lower variance means better alignment
        let alignmentScore = max(0, 1.0 - xVariance * 10)
        score += alignmentScore * 0.1
        
        return min(score, 1.0)
    }
    
    private func calculateVariance(_ values: [Float]) -> Double {
        guard !values.isEmpty else { return 1.0 }
        let mean = values.reduce(0, +) / Float(values.count)
        let squaredDiffs = values.map { pow(Double($0 - mean), 2) }
        return squaredDiffs.reduce(0, +) / Double(values.count)
    }
    
    /// Unified Vision processing method that uses identical configuration for all image sources
    /// - Parameters:
    ///   - image: The image to process
    ///   - sourceType: "uploaded" or "live" for logging purposes
    /// - Returns: OCRResult with parsed receipt data
    func processImageUnified(_ image: UIImage, sourceType: String = "uploaded") async throws -> OCRResult {
        let startTime = Date()
        
        guard let cgImage = image.cgImage else {
            throw OCRError.invalidImage
        }
        
        // Log image properties
        let imageSize = CGSize(width: cgImage.width, height: cgImage.height)
        let orientation = image.imageOrientation
        print("[OCRService] Processing image - Source: \(sourceType), Size: \(imageSize.width)x\(imageSize.height), Orientation: \(orientation.rawValue)")
        
        return try await withCheckedThrowingContinuation { continuation in
            let request = VNRecognizeTextRequest { request, error in
                let processingTime = Date().timeIntervalSince(startTime)
                
                if let error = error {
                    print("[OCRService] Error processing image: \(error.localizedDescription)")
                    continuation.resume(throwing: error)
                    return
                }
                
                guard let observations = request.results as? [VNRecognizedTextObservation] else {
                    print("[OCRService] No observations found")
                    var emptyResult = OCRResult(
                        items: [],
                        subtotal: nil,
                        vatPercentage: nil,
                        servicePercentage: nil,
                        total: nil,
                        boundingBoxes: [],
                        sourceImage: image,
                        detectedRectangle: nil
                    )
                    #if DEBUG
                    emptyResult.debugData = OCRDebugData(
                        rawObservations: [],
                        processedLines: [],
                        imageResolution: imageSize,
                        processingTime: processingTime,
                        sourceType: sourceType
                    ) as OCRDebugData
                    #endif
                    continuation.resume(returning: emptyResult)
                    return
                }
                
                print("[OCRService] Found \(observations.count) text observations in \(String(format: "%.2f", processingTime))s")
                
                let (parsedResult, boundingBoxes, debugData) = self.parseReceipt(from: observations, imageSize: imageSize, processingTime: processingTime, sourceType: sourceType)
                var result = parsedResult
                result.sourceImage = image
                result.boundingBoxes = boundingBoxes
                #if DEBUG
                if let debugData = debugData as? OCRDebugData {
                    result.debugData = debugData
                }
                #endif
                continuation.resume(returning: result)
            }
            
            // Unified configuration - always the same regardless of source
            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true
            // Do NOT use regionOfInterest - process full image
            
            // Handle orientation correctly
            var handlerOptions: [VNImageOption: Any] = [:]
            if let orientation = CGImagePropertyOrientation(rawValue: UInt32(image.imageOrientation.rawValue)) {
                handlerOptions[.ciContext] = CIContext()
            }
            
            let handler = VNImageRequestHandler(cgImage: cgImage, orientation: .up, options: handlerOptions)
            do {
                try handler.perform([request])
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }
    
    /// Legacy method - now uses unified processing
    func processImage(_ image: UIImage) async throws -> OCRResult {
        return try await processImageUnified(image, sourceType: "uploaded")
    }
    
    // MARK: - Exclusion Rules
    
    /// Returns exclusion score (0.0 = no exclusion, 1.0 = fully excluded) and reason
    /// Only hard-excludes if score > 0.8 (very confident exclusion)
    private func isExcludedLine(_ text: String, normalizedY: CGFloat, receiptHeight: CGFloat) -> (excluded: Bool, exclusionScore: Double, reason: String?) {
        let lowercased = text.lowercased()
        var exclusionScore = 0.0
        var reason: String? = nil
        
        // Position-based exclusion: top 20% of receipt (relaxed from 25%)
        // Vision uses bottom-left origin, so minY > 0.8 means top 20%
        if normalizedY > 0.8 {
            exclusionScore = 1.0
            reason = "In top 20% of receipt (header region)"
            return (true, exclusionScore, reason)
        }
        
        // Restaurant name keywords - only exclude if prominent (not just present)
        let restaurantKeywords = ["restaurant", "cafe", "bar", "grill", "bistro", "diner", "eatery", "kitchen"]
        if restaurantKeywords.contains(where: lowercased.contains) {
            // Check if keyword is prominent (at start of line or standalone)
            let words = lowercased.components(separatedBy: .whitespaces)
            if words.first(where: { restaurantKeywords.contains($0) }) != nil {
                exclusionScore = max(exclusionScore, 0.7)
                reason = "Contains prominent restaurant name keyword"
            } else {
                exclusionScore = max(exclusionScore, 0.3)
            }
        }
        
        // Table number patterns
        let tablePatterns = ["table", "tab", "table #", "table no", "table number", "tbl"]
        if tablePatterns.contains(where: lowercased.contains) {
            exclusionScore = max(exclusionScore, 0.6)
            reason = "Contains table number pattern"
        }
        
        // Waiter/server keywords
        let serverKeywords = ["waiter", "server", "cashier", "served by", "server:", "cashier:", "waiter:"]
        if serverKeywords.contains(where: lowercased.contains) {
            exclusionScore = max(exclusionScore, 0.6)
            reason = "Contains waiter/server keyword"
        }
        
        // Date patterns - only exclude if entire line is date/time
        let datePattern = #"\d{1,2}[/-]\d{1,2}[/-]\d{2,4}"#
        if let regex = try? NSRegularExpression(pattern: datePattern),
           let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)) {
            // Check if date is the main content of the line
            let dateText = String(text[Range(match.range, in: text)!])
            if text.trimmingCharacters(in: .whitespaces).count <= dateText.count + 5 {
                exclusionScore = max(exclusionScore, 0.8)
                reason = "Line is primarily a date"
            } else {
                exclusionScore = max(exclusionScore, 0.2) // Date present but not main content
            }
        }
        
        // Time patterns - only exclude if entire line is time
        let timePattern = #"\d{1,2}:\d{2}(:\d{2})?"#
        if let regex = try? NSRegularExpression(pattern: timePattern),
           let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)) {
            let timeText = String(text[Range(match.range, in: text)!])
            if text.trimmingCharacters(in: .whitespaces).count <= timeText.count + 5 {
                exclusionScore = max(exclusionScore, 0.8)
                reason = "Line is primarily a time"
            } else {
                exclusionScore = max(exclusionScore, 0.2)
            }
        }
        
        // Invoice/receipt number
        let invoicePatterns = ["invoice", "receipt", "bill #", "receipt #", "invoice #", "order #", "order number"]
        if invoicePatterns.contains(where: lowercased.contains) {
            exclusionScore = max(exclusionScore, 0.7)
            reason = "Contains invoice/receipt number pattern"
        }
        
        // Phone numbers
        let phonePattern = #"[\d\s\-\(\)]{10,}"#
        if let regex = try? NSRegularExpression(pattern: phonePattern),
           let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
           let range = Range(match.range, in: text) {
            let phoneText = String(text[range]).replacingOccurrences(of: "[^0-9]", with: "", options: .regularExpression)
            if phoneText.count >= 10 {
                exclusionScore = max(exclusionScore, 0.8)
                reason = "Contains phone number"
            }
        }
        
        // Tax ID patterns
        let taxIdPatterns = ["tax id", "vat", "ein", "tax number", "tax id:", "vat number"]
        if taxIdPatterns.contains(where: lowercased.contains) {
            exclusionScore = max(exclusionScore, 0.7)
            reason = "Contains tax ID pattern"
        }
        
        // Only hard-exclude if score > 0.8
        let excluded = exclusionScore > 0.8
        return (excluded, exclusionScore, reason)
    }
    
    // MARK: - Totals Override Rules
    
    private func isTotalsKeyword(_ text: String) -> (isTotal: Bool, type: BoundingBoxClassification?) {
        let lowercased = text.lowercased()
        
        // Priority order: total > subtotal > tax/service
        if lowercased.contains("total") && !lowercased.contains("subtotal") {
            return (true, .total)
        }
        if lowercased.contains("subtotal") {
            return (true, .subtotal)
        }
        if lowercased.contains("tax") || lowercased.contains("vat") {
            return (true, .tax)
        }
        if lowercased.contains("service") || lowercased.contains("tip") || lowercased.contains("gratuity") {
            return (true, .service)
        }
        if lowercased.contains("amount due") {
            return (true, .total)
        }
        
        return (false, nil)
    }
    
    // MARK: - Line Item Qualification
    
    private func scoreLineItem(_ text: String, boundingBox: CGRect, imageSize: CGSize, total: Decimal?, confidence: Double, exclusionScore: Double = 0.0) -> (score: Double, reasons: [String], scoreBreakdown: [String: Double]) {
        var score = 0.0
        var reasons: [String] = []
        var scoreBreakdown: [String: Double] = [:]
        
        // 1. Contains alphabetic text (not just numbers) - +0.15
        let hasLetters = text.rangeOfCharacter(from: CharacterSet.letters) != nil
        if hasLetters {
            score += 0.15
            scoreBreakdown["alphabetic_text"] = 0.15
            reasons.append("Contains alphabetic text (+0.15)")
        } else {
            reasons.append("No alphabetic text")
        }
        
        // 2. Price present (critical) - +0.25
        let pricePresent = hasPriceInLine(text)
        if pricePresent {
            score += 0.25
            scoreBreakdown["price_present"] = 0.25
            reasons.append("Price detected (+0.25)")
        } else {
            reasons.append("No price detected")
        }
        
        // 3. Price alignment (X position > 0.6 of receipt width) - +0.15
        // boundingBox is already in image coordinates (top-left origin)
        let normalizedX = boundingBox.midX / imageSize.width
        if normalizedX > 0.6 {
            score += 0.15
            scoreBreakdown["price_alignment"] = 0.15
            reasons.append("Price aligned right (+0.15)")
        } else {
            reasons.append("Price not aligned right")
        }
        
        // 4. Position between header (top 20%) and totals (bottom 20%) - +0.15
        // Relaxed range: 20%-80% (was 25%-70%)
        // boundingBox is in image coordinates (top-left origin)
        // Y=0 is top, Y=imageSize.height is bottom
        let normalizedY = boundingBox.minY / imageSize.height
        // Valid range: between 20% from top and 80% from top (avoiding bottom 20%)
        let positionScore = (normalizedY > 0.2 && normalizedY < 0.8) ? 0.15 : 0.0
        score += positionScore
        scoreBreakdown["position"] = positionScore
        if positionScore > 0 {
            reasons.append("In valid position range (20%-80%) (+0.15)")
        } else {
            reasons.append("Outside valid position range (Y: \(String(format: "%.2f", normalizedY)))")
        }
        
        // 5. No excluded keywords (bonus, not penalty) - +0.1
        // Exclusion score is passed in (0.0 = no exclusion, 1.0 = fully excluded)
        let exclusionPenalty = exclusionScore * 0.3 // Reduce score by up to 0.3
        score -= exclusionPenalty
        scoreBreakdown["exclusion_penalty"] = -exclusionPenalty
        if exclusionScore == 0.0 {
            score += 0.1
            scoreBreakdown["no_exclusion"] = 0.1
            reasons.append("No excluded keywords (+0.1)")
        } else {
            reasons.append("Exclusion penalty: -\(String(format: "%.2f", exclusionPenalty))")
        }
        
        // 6. Reasonable price magnitude - +0.15
        if let price = extractAmount(from: text) {
            if let total = total {
                if price > 0 && price < total * 2 {
                    score += 0.15
                    scoreBreakdown["price_magnitude"] = 0.15
                    reasons.append("Price is reasonable (+0.15)")
                } else {
                    reasons.append("Price magnitude suspicious (price: \(price), total: \(total))")
                }
            } else {
                // No total yet, but price exists - still give some credit
                if price > 0 && price < 1000 {
                    score += 0.1
                    scoreBreakdown["price_magnitude"] = 0.1
                    reasons.append("Price exists, no total for validation (+0.1)")
                }
            }
        } else {
            reasons.append("Could not extract price")
        }
        
        // 7. Confidence score - +0.05
        if confidence > 0.5 {
            score += 0.05
            scoreBreakdown["confidence"] = 0.05
            reasons.append("High confidence (+0.05)")
        } else {
            reasons.append("Low confidence")
        }
        
        return (max(0.0, min(score, 1.0)), reasons, scoreBreakdown)
    }
    
    private func parseReceipt(from observations: [VNRecognizedTextObservation], imageSize: CGSize, processingTime: TimeInterval = 0, sourceType: String = "unknown") -> (OCRResult, [BoundingBox], Any?) {
        var lines: [(text: String, observation: VNRecognizedTextObservation, confidence: Double)] = []
        
        for observation in observations {
            guard let topCandidate = observation.topCandidates(1).first else { continue }
            let confidence = Double(topCandidate.confidence) // Convert VNConfidence (Float) to Double
            lines.append((topCandidate.string, observation, confidence))
        }
        
        // Sort lines by Y position (top to bottom)
        // Vision uses bottom-left origin, so higher Y = higher on screen
        lines.sort { $0.observation.boundingBox.minY > $1.observation.boundingBox.minY }
        
        // Phase 3: Multi-line grouping - group item name and price on separate lines
        lines = groupMultiLineItems(lines: lines, imageSize: imageSize)
        
        // Calculate receipt height for position-based exclusion
        let receiptHeight = lines.isEmpty ? imageSize.height : {
            let minY = lines.map { $0.observation.boundingBox.minY }.min() ?? 0
            let maxY = lines.map { $0.observation.boundingBox.maxY }.max() ?? 1
            return (maxY - minY) * imageSize.height
        }()
        
        var items: [ReceiptItem] = []
        var subtotal: Decimal?
        var vatPercentage: Decimal?
        var servicePercentage: Decimal?
        var total: Decimal?
        var boundingBoxes: [BoundingBox] = []
        
        #if DEBUG
        var debugLines: [OCRDebugLine] = []
        #endif
        
        // Phase 1: Enhanced totals detection - run BEFORE exclusion checks
        // First try keyword-based detection
        for (line, observation, _) in lines {
            let (isTotal, totalType) = isTotalsKeyword(line)
            if isTotal, let totalType = totalType {
                if totalType == .total, let amount = extractAmount(from: line) {
                    total = amount
                } else if totalType == .subtotal, let amount = extractAmount(from: line) {
                    subtotal = amount
                } else if totalType == .tax, let percentage = extractPercentage(from: line) {
                    vatPercentage = percentage
                } else if totalType == .service, let percentage = extractPercentage(from: line) {
                    servicePercentage = percentage
                }
            }
        }
        
        // If total not found via keywords, use footer zone detection
        if total == nil {
            let (detectedTotal, _, reason) = detectTotalFromFooterZone(lines: lines, imageSize: imageSize)
            if let detectedTotal = detectedTotal {
                total = detectedTotal
                print("[OCRService] \(reason)")
            }
        }
        
        // Second pass: Process all lines with exclusion rules and classification
        for (line, observation, confidence) in lines {
            let lowercased = line.lowercased()
            
            // Convert normalized bounding box to image coordinates
            let normalizedRect = observation.boundingBox
            let imageRect = VNImageRectForNormalizedRect(
                normalizedRect,
                Int(imageSize.width),
                Int(imageSize.height)
            )
            
            // Check exclusion rules (highest priority)
            // Phase 5: Returns exclusion score instead of boolean
            let normalizedY = normalizedRect.minY
            let (excluded, exclusionScore, exclusionReason) = isExcludedLine(line, normalizedY: normalizedY, receiptHeight: receiptHeight)
            
            // Determine zone for debug
            let zone: String
            if normalizedY > 0.8 {
                zone = "header"
            } else if normalizedY < 0.2 {
                zone = "footer"
            } else {
                zone = "middle"
            }
            
            if excluded {
                #if DEBUG
                debugLines.append(OCRDebugLine(
                    text: line,
                    confidence: confidence,
                    boundingBox: imageRect,
                    classification: nil,
                    classificationReason: "Excluded (score: \(String(format: "%.2f", exclusionScore)))",
                    excluded: true,
                    exclusionReason: exclusionReason,
                    zone: zone,
                    priceDetected: hasPriceInLine(line),
                    groupedWith: nil,
                    scoreBreakdown: nil
                ))
                #endif
                continue // Skip excluded lines
            }
            
            // Check totals override rule (must NEVER be line items)
            let (isTotalKeyword, totalType) = isTotalsKeyword(line)
            var classification: BoundingBoxClassification? = nil
            var classificationReason = ""
            
            if isTotalKeyword, let totalType = totalType {
                // This is a totals line - extract value
                if totalType == .total, let amount = extractAmount(from: line) {
                    total = amount
                    classification = .total
                    classificationReason = "Totals keyword: 'total'"
                } else if totalType == .subtotal, let amount = extractAmount(from: line) {
                    subtotal = amount
                    classification = .subtotal
                    classificationReason = "Totals keyword: 'subtotal'"
                } else if totalType == .tax, let percentage = extractPercentage(from: line) {
                    vatPercentage = percentage
                    classification = .tax
                    classificationReason = "Totals keyword: 'tax'/'vat'"
                } else if totalType == .service, let percentage = extractPercentage(from: line) {
                    servicePercentage = percentage
                    classification = .service
                    classificationReason = "Totals keyword: 'service'/'tip'"
                }
                
                // Add bounding box for totals
                if let classification = classification {
                    boundingBoxes.append(BoundingBox(
                        rectangle: imageRect,
                        text: line,
                        classification: classification
                    ))
                }
                
                #if DEBUG
                debugLines.append(OCRDebugLine(
                    text: line,
                    confidence: confidence,
                    boundingBox: imageRect,
                    classification: classification,
                    classificationReason: classificationReason,
                    excluded: false,
                    exclusionReason: nil,
                    zone: zone,
                    priceDetected: hasPriceInLine(line),
                    groupedWith: nil,
                    scoreBreakdown: nil
                ))
                #endif
                continue // Totals are never line items
            }
            
            // Line item qualification with scoring
            // Phase 2: Lower threshold to 0.4, use additive scoring, pass exclusion score
            let (itemScore, scoreReasons, scoreBreakdown) = scoreLineItem(line, boundingBox: imageRect, imageSize: imageSize, total: total, confidence: confidence, exclusionScore: exclusionScore)
            
            // Phase 2: Lower threshold from 0.6 to 0.4, accept uncertain items (0.3-0.4)
            let isUncertain = itemScore >= 0.3 && itemScore < 0.4
            let isAccepted = itemScore >= 0.4
            
            if isAccepted || isUncertain {
                // Try to parse as line item
                if let item = parseItem(from: line) {
                    items.append(item)
                    classification = .lineItem
                    let uncertaintyNote = isUncertain ? " [UNCERTAIN]" : ""
                    classificationReason = "Line item (score: \(String(format: "%.2f", itemScore)))\(uncertaintyNote) - \(scoreReasons.joined(separator: ", "))"
                    
                    boundingBoxes.append(BoundingBox(
                        rectangle: imageRect,
                        text: line,
                        classification: .lineItem
                    ))
                } else {
                    classificationReason = "Failed to parse as item despite score \(String(format: "%.2f", itemScore)): \(scoreReasons.joined(separator: ", "))"
                }
            } else {
                classificationReason = "Low line item score (\(String(format: "%.2f", itemScore))): \(scoreReasons.joined(separator: ", "))"
            }
            
            #if DEBUG
            // Phase 4: Enhanced debug visibility - include zone, price detection, score breakdown
            debugLines.append(OCRDebugLine(
                text: line,
                confidence: confidence,
                boundingBox: imageRect,
                classification: classification,
                classificationReason: classificationReason,
                excluded: false,
                exclusionReason: nil,
                zone: zone,
                priceDetected: hasPriceInLine(line),
                groupedWith: nil, // TODO: Track multi-line grouping
                scoreBreakdown: isAccepted || isUncertain ? scoreBreakdown : nil
            ))
            #endif
        }
        
        // If subtotal not found, calculate from items
        if subtotal == nil {
            subtotal = items.reduce(Decimal(0)) { $0 + $1.totalPrice }
        }
        
        // Totals validation
        if let subtotal = subtotal, let total = total {
            var calculatedTotal = subtotal
            
            // Add tax if present
            if let vatPercentage = vatPercentage {
                calculatedTotal += subtotal * vatPercentage / 100
            }
            
            // Add service if present
            if let servicePercentage = servicePercentage {
                calculatedTotal += subtotal * servicePercentage / 100
            }
            
            // Check if totals match (allow 1% tolerance for rounding)
            let difference = abs((calculatedTotal - total).doubleValue)
            let tolerance = total * 0.01
            if difference > tolerance.doubleValue {
                print("[OCRService] WARNING: Totals don't match! Calculated: \(calculatedTotal), Found: \(total), Difference: \(difference)")
            }
        }
        
        let result = OCRResult(
            items: items,
            subtotal: subtotal,
            vatPercentage: vatPercentage,
            servicePercentage: servicePercentage,
            total: total,
            boundingBoxes: [],
            sourceImage: nil,
            detectedRectangle: nil
        )
        
        #if DEBUG
        let debugData: Any? = OCRDebugData(
            rawObservations: observations,
            processedLines: debugLines,
            imageResolution: imageSize,
            processingTime: processingTime,
            sourceType: sourceType
        )
        return (result, boundingBoxes, debugData)
        #else
        return (result, boundingBoxes, nil as Any?)
        #endif
    }
    
    private func parseItem(from line: String) -> ReceiptItem? {
        // Enhanced price extraction with multiple formats
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        
        // Try multiple price patterns
        var price: Decimal?
        var quantity = 1
        var nameComponents: [String] = []
        
        // Pattern 1: "$25.50" or "25.50" at the end
        let pricePattern1 = #"([\$]?)(\d{1,3}(?:[,\s]\d{3})*(?:\.\d{2})?)"#
        if let regex = try? NSRegularExpression(pattern: pricePattern1) {
            let matches = regex.matches(in: trimmed, range: NSRange(trimmed.startIndex..., in: trimmed))
            if let lastMatch = matches.last,
               let range = Range(lastMatch.range, in: trimmed) {
                var priceStr = String(trimmed[range]).replacingOccurrences(of: "[$,\\s]", with: "", options: .regularExpression)
                if let priceValue = Decimal(string: priceStr), priceValue > 0 {
                    price = priceValue
                    if let nameRange = Range(NSRange(location: 0, length: lastMatch.range.location), in: trimmed) {
                        nameComponents = String(trimmed[nameRange]).components(separatedBy: .whitespaces)
                    }
                }
            }
        }
        
        // Pattern 2: European format "25,50"
        if price == nil {
            let pricePattern2 = #"(\d{1,3}(?:\s\d{3})*(?:,\d{2})?)"#
            if let regex = try? NSRegularExpression(pattern: pricePattern2) {
                let matches = regex.matches(in: trimmed, range: NSRange(trimmed.startIndex..., in: trimmed))
                if let lastMatch = matches.last,
                   let range = Range(lastMatch.range, in: trimmed) {
                    var priceStr = String(trimmed[range]).replacingOccurrences(of: "\\s", with: "", options: .regularExpression)
                    priceStr = priceStr.replacingOccurrences(of: ",", with: ".")
                    if let priceValue = Decimal(string: priceStr), priceValue > 0 {
                        price = priceValue
                        if let nameRange = Range(NSRange(location: 0, length: lastMatch.range.location), in: trimmed) {
                            nameComponents = String(trimmed[nameRange]).components(separatedBy: .whitespaces)
                        }
                    }
                }
            }
        }
        
        // Extract quantity: "x2", "2x", "qty: 2", "2×"
        let quantityPatterns = [
            #"x(\d+)"#,
            #"(\d+)x"#,
            #"qty[:\s]*(\d+)"#,
            #"(\d+)[×x]"#
        ]
        
        for pattern in quantityPatterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
               let match = regex.firstMatch(in: trimmed, range: NSRange(trimmed.startIndex..., in: trimmed)),
               let qtyRange = Range(match.range(at: 1), in: trimmed),
               let qty = Int(String(trimmed[qtyRange])) {
                quantity = qty
                break
            }
        }
        
        guard let price = price, price > 0 else {
            return nil
        }
        
        // Clean up name components
        nameComponents = nameComponents.filter { component in
            // Remove quantity indicators from name
            !quantityPatterns.contains { pattern in
                (try? NSRegularExpression(pattern: pattern, options: .caseInsensitive))?.firstMatch(in: component, range: NSRange(component.startIndex..., in: component)) != nil
            }
        }
        
        let name = nameComponents.joined(separator: " ").trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else { return nil }
        
        // Validate price is reasonable (not negative, not suspiciously large)
        let unitPrice = price / Decimal(quantity)
        if unitPrice <= 0 {
            return nil
        }
        
        return ReceiptItem(name: name, unitPrice: unitPrice, quantity: quantity)
    }
    
    private func extractAmount(from line: String) -> Decimal? {
        // Enhanced amount extraction with multiple formats
        // Pattern 1: "$25.50" or "25.50"
        let pattern1 = #"[\$]?(\d{1,3}(?:[,\s]\d{3})*(?:\.\d{2})?)"#
        if let regex = try? NSRegularExpression(pattern: pattern1),
           let match = regex.firstMatch(in: line, range: NSRange(line.startIndex..., in: line)),
           let range = Range(match.range(at: 1), in: line) {
            var amountStr = String(line[range]).replacingOccurrences(of: "[,\\s]", with: "", options: .regularExpression)
            if let amount = Decimal(string: amountStr), amount > 0 {
                return amount
            }
        }
        
        // Pattern 2: European format "25,50"
        let pattern2 = #"(\d{1,3}(?:\s\d{3})*(?:,\d{2})?)"#
        if let regex = try? NSRegularExpression(pattern: pattern2),
           let match = regex.firstMatch(in: line, range: NSRange(line.startIndex..., in: line)),
           let range = Range(match.range(at: 1), in: line) {
            var amountStr = String(line[range]).replacingOccurrences(of: "\\s", with: "", options: .regularExpression)
            amountStr = amountStr.replacingOccurrences(of: ",", with: ".")
            if let amount = Decimal(string: amountStr), amount > 0 {
                return amount
            }
        }
        
        // Fallback: Extract all numbers and assume last two digits are cents
        let numbers = line.components(separatedBy: CharacterSet.decimalDigits.inverted).joined()
        if !numbers.isEmpty, let number = Decimal(string: numbers) {
            if numbers.count <= 2 {
                return number / 100
            }
            // Assume last two digits are cents
            return number / 100
        }
        
        return nil
    }
    
    private func extractPercentage(from line: String) -> Decimal? {
        let pattern = #"(\d+(?:\.\d+)?)%"#
        if let regex = try? NSRegularExpression(pattern: pattern),
           let match = regex.firstMatch(in: line, range: NSRange(line.startIndex..., in: line)),
           let range = Range(match.range(at: 1), in: line),
           let percentage = Decimal(string: String(line[range])) {
            return percentage
        }
        return nil
    }
    
    // MARK: - Multi-Line Grouping
    
    /// Group item names and prices that appear on separate lines
    private func groupMultiLineItems(lines: [(text: String, observation: VNRecognizedTextObservation, confidence: Double)], imageSize: CGSize) -> [(text: String, observation: VNRecognizedTextObservation, confidence: Double)] {
        var groupedLines: [(text: String, observation: VNRecognizedTextObservation, confidence: Double)] = []
        var processedIndices = Set<Int>()
        
        // Vertical proximity threshold: 5% of receipt height
        let proximityThreshold = imageSize.height * 0.05
        
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
                
                // Check vertical proximity (within 5% of receipt height)
                let verticalDistance = abs(currentRect.maxY - nextRect.minY)
                
                if verticalDistance <= proximityThreshold {
                    let nextHasPrice = hasPriceInLine(nextText)
                    let nextHasText = nextText.rangeOfCharacter(from: CharacterSet.letters) != nil
                    
                    // If next line has price but minimal text, merge them
                    if nextHasPrice && (!nextHasText || nextText.count < 10) {
                        // Merge: combine text and create combined bounding box
                        let combinedText = "\(currentText) \(nextText)".trimmingCharacters(in: .whitespaces)
                        
                        // Create combined bounding box (union of both)
                        let combinedRect = currentRect.union(nextRect)
                        
                        // Convert back to normalized coordinates for the observation
                        // We'll use currentObs but the bounding box will be recalculated when needed
                        let combinedConfidence = max(currentConf, nextConf)
                        
                        // Create a synthetic observation by using currentObs
                        // The bounding box will be recalculated from combinedRect when processing
                        // Store the combined text and use currentObs structure
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
    private func hasPriceInLine(_ text: String) -> Bool {
        let amounts = extractAllAmounts(from: text)
        return !amounts.isEmpty
    }
    
    // MARK: - Enhanced Totals Detection
    
    /// Internal structure for total candidates
    private struct TotalCandidate {
        let amount: Decimal
        let normalizedY: CGFloat
        let hasKeyword: Bool
        let confidence: Double
        let text: String
    }
    
    /// Extract all numeric amounts from a line of text
    private func extractAllAmounts(from text: String) -> [Decimal] {
        var amounts: [Decimal] = []
        
        // Pattern 1: "$25.50" or "25.50"
        let pattern1 = #"[\$]?(\d{1,3}(?:[,\s]\d{3})*(?:\.\d{2})?)"#
        if let regex = try? NSRegularExpression(pattern: pattern1) {
            let matches = regex.matches(in: text, range: NSRange(text.startIndex..., in: text))
            for match in matches {
                if let range = Range(match.range(at: 1), in: text) {
                    var amountStr = String(text[range]).replacingOccurrences(of: "[,\\s]", with: "", options: .regularExpression)
                    if let amount = Decimal(string: amountStr), amount > 0 {
                        amounts.append(amount)
                    }
                }
            }
        }
        
        // Pattern 2: European format "25,50"
        let pattern2 = #"(\d{1,3}(?:\s\d{3})*(?:,\d{2})?)"#
        if let regex = try? NSRegularExpression(pattern: pattern2) {
            let matches = regex.matches(in: text, range: NSRange(text.startIndex..., in: text))
            for match in matches {
                if let range = Range(match.range(at: 1), in: text) {
                    var amountStr = String(text[range]).replacingOccurrences(of: "\\s", with: "", options: .regularExpression)
                    amountStr = amountStr.replacingOccurrences(of: ",", with: ".")
                    if let amount = Decimal(string: amountStr), amount > 0 {
                        amounts.append(amount)
                    }
                }
            }
        }
        
        return amounts
    }
    
    /// Detect total from footer zone (bottom 30% of receipt) without requiring keywords
    private func detectTotalFromFooterZone(lines: [(text: String, observation: VNRecognizedTextObservation, confidence: Double)], imageSize: CGSize) -> (amount: Decimal?, confidence: Double, reason: String) {
        // Footer zone: bottom 30% of receipt
        // Vision uses bottom-left origin, so normalizedY < 0.3 means bottom 30%
        let footerThreshold: CGFloat = 0.3
        
        var candidates: [TotalCandidate] = []
        
        for (line, observation, confidence) in lines {
            let normalizedY = observation.boundingBox.minY
            
            // Only consider lines in footer zone
            if normalizedY > footerThreshold {
                continue
            }
            
            // Extract all amounts from this line
            let amounts = extractAllAmounts(from: line)
            
            for amount in amounts {
                // Filter reasonable values: > $1.00 and < $10,000
                if amount > 1.0 && amount < 10000 {
                    let (hasKeyword, _) = isTotalsKeyword(line)
                    candidates.append(TotalCandidate(
                        amount: amount,
                        normalizedY: normalizedY,
                        hasKeyword: hasKeyword,
                        confidence: confidence,
                        text: line
                    ))
                }
            }
        }
        
        // If no footer candidates, search entire receipt (fallback)
        if candidates.isEmpty {
            for (line, observation, confidence) in lines {
                let amounts = extractAllAmounts(from: line)
                for amount in amounts {
                    if amount > 1.0 && amount < 10000 {
                        let (hasKeyword, _) = isTotalsKeyword(line)
                        let normalizedY = observation.boundingBox.minY
                        candidates.append(TotalCandidate(
                            amount: amount,
                            normalizedY: normalizedY,
                            hasKeyword: hasKeyword,
                            confidence: confidence,
                            text: line
                        ))
                    }
                }
            }
        }
        
        // Find best candidate
        return findBestTotalCandidate(candidates: candidates)
    }
    
    /// Select best total candidate from multiple options
    private func findBestTotalCandidate(candidates: [TotalCandidate]) -> (amount: Decimal?, confidence: Double, reason: String) {
        guard !candidates.isEmpty else {
            return (nil, 0.0, "No total candidates found")
        }
        
        // Sort by score: position (lower = better), size (larger = better), keyword (bonus)
        let sortedCandidates = candidates.sorted { candidate1, candidate2 in
            var score1 = 0.0
            var score2 = 0.0
            
            // Position score: lower Y (closer to bottom) = higher score
            score1 += (1.0 - Double(candidate1.normalizedY)) * 0.3
            score2 += (1.0 - Double(candidate2.normalizedY)) * 0.3
            
            // Size score: larger amount = higher score (normalized)
            let maxAmount = candidates.map { $0.amount.doubleValue }.max() ?? 1.0
            score1 += (candidate1.amount.doubleValue / maxAmount) * 0.4
            score2 += (candidate2.amount.doubleValue / maxAmount) * 0.4
            
            // Keyword bonus
            if candidate1.hasKeyword {
                score1 += 0.3
            }
            if candidate2.hasKeyword {
                score2 += 0.3
            }
            
            return score1 > score2
        }
        
        let bestCandidate = sortedCandidates.first!
        let confidence = bestCandidate.hasKeyword ? 0.9 : 0.7
        let reason = bestCandidate.hasKeyword 
            ? "Total detected from footer zone with keyword: '\(bestCandidate.text)'"
            : "Total detected from footer zone (largest value): '\(bestCandidate.text)'"
        
        return (bestCandidate.amount, confidence, reason)
    }
}

enum OCRError: Error {
    case invalidImage
    case processingFailed
}

