//
//  OCRService.swift
//  Cheq
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
        let _ = try await processImageUnified(image, sourceType: "live")
        
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
        print("[OCRService] Processing image - Source: \(sourceType), Size: \(imageSize.width)x\(imageSize.height), Orientation: \(image.imageOrientation.rawValue)")
        
        // Step 1: Detect receipt rectangle for cropping
        var receiptRect: CGRect? = nil
        do {
            let rectangles = try await detectRectangles(in: image)
            if let bestRect = rectangles.first {
                receiptRect = bestRect
                print("[OCRService] Detected receipt rectangle: \(bestRect)")
            }
        } catch {
            print("[OCRService] Rectangle detection failed, processing full image: \(error.localizedDescription)")
        }
        
        // Step 2: Preprocess image for better OCR accuracy
        let preprocessingService = ImagePreprocessingService.shared
        let preprocessedImage: UIImage
        if let processed = preprocessingService.preprocessForOCR(image, receiptRect: receiptRect) {
            preprocessedImage = processed
            print("[OCRService] Image preprocessing completed")
        } else {
            // Fallback to original image if preprocessing fails
            preprocessedImage = image
            print("[OCRService] Preprocessing failed, using original image")
        }
        
        guard let processedCGImage = preprocessedImage.cgImage else {
            throw OCRError.invalidImage
        }
        
        // Use preprocessed image size for OCR
        let processedImageSize = CGSize(width: processedCGImage.width, height: processedCGImage.height)
        
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
                
                // Filter observations by confidence threshold (0.7 = 70%)
                let minConfidence: Float = 0.7
                let filteredObservations = observations.filter { observation in
                    guard let topCandidate = observation.topCandidates(1).first else {
                        return false
                    }
                    return topCandidate.confidence >= minConfidence
                }
                
                print("[OCRService] Found \(observations.count) text observations (filtered to \(filteredObservations.count) with confidence >= \(minConfidence)) in \(String(format: "%.2f", processingTime))s")
                
                let (parsedResult, boundingBoxes, debugData) = self.parseReceipt(from: filteredObservations, imageSize: processedImageSize, processingTime: processingTime, sourceType: sourceType)
                var finalResult = parsedResult
                finalResult.sourceImage = image
                finalResult.boundingBoxes = boundingBoxes
                #if DEBUG
                if let debugData = debugData as? OCRDebugData {
                    finalResult.debugData = debugData
                }
                #endif
                continuation.resume(returning: finalResult)
            }
            
            // Unified configuration - always the same regardless of source
            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true
            
            // Add custom word list for common receipt terms to improve recognition
            let receiptWords = [
                "subtotal", "total", "tax", "vat", "service", "tip", "gratuity",
                "amount", "due", "paid", "change", "cash", "card", "credit",
                "discount", "refund", "receipt", "invoice", "bill",
                "quantity", "qty", "each", "price", "item", "items"
            ]
            request.customWords = receiptWords
            
            // Set minimum text height for better accuracy (filter out very small text)
            request.minimumTextHeight = 0.01 // 1% of image height
            
            // Do NOT use regionOfInterest - process full image (already cropped in preprocessing)
            
            // Handle orientation correctly (preprocessed image should already be oriented correctly)
            var handlerOptions: [VNImageOption: Any] = [:]
            handlerOptions[.ciContext] = CIContext()
            
            let handler = VNImageRequestHandler(cgImage: processedCGImage, orientation: .up, options: handlerOptions)
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
    /// Hard-excludes if score > 0.7 (stricter threshold for better accuracy)
    private func isExcludedLine(_ text: String, normalizedY: CGFloat, receiptHeight: CGFloat) -> (excluded: Bool, exclusionScore: Double, reason: String?) {
        var exclusionScore = 0.0
        var reason: String? = nil
        
        let trimmedText = text.trimmingCharacters(in: .whitespaces)
        let lowercased = trimmedText.lowercased()
        
        // Position-based exclusion: top 30% and bottom 30% are metadata zones
        // Vision uses bottom-left origin, so:
        // - minY > 0.7 means top 30% (header zone)
        // - minY < 0.3 means bottom 30% (footer zone, but we want totals from footer)
        // Only exclude top 30% as hard exclusion, bottom 30% gets penalty but not hard exclusion
        if normalizedY > 0.7 {
            exclusionScore = 1.0
            reason = "In top 30% of receipt (header/metadata region)"
            return (true, exclusionScore, reason)
        }
        
        // HARD EXCLUSION: Date patterns - always exclude lines that are primarily dates
        let datePattern = #"\d{1,2}[/-]\d{1,2}[/-]\d{2,4}"#
        if let regex = try? NSRegularExpression(pattern: datePattern),
           let match = regex.firstMatch(in: trimmedText, range: NSRange(trimmedText.startIndex..., in: trimmedText)) {
            let dateText = String(trimmedText[Range(match.range, in: trimmedText)!])
            // If date is the main content (at least 50% of line), hard exclude
            if trimmedText.count <= dateText.count * 2 {
                exclusionScore = 1.0
                reason = "Line is primarily a date pattern"
                return (true, exclusionScore, reason)
            }
        }
        
        // HARD EXCLUSION: Table number patterns - always exclude
        let tablePattern = #"(?i)(table|tab|tbl)\s*:?\s*\d+"#
        if let regex = try? NSRegularExpression(pattern: tablePattern),
           regex.firstMatch(in: trimmedText, range: NSRange(trimmedText.startIndex..., in: trimmedText)) != nil {
            exclusionScore = 1.0
            reason = "Contains table number pattern"
            return (true, exclusionScore, reason)
        }
        
        // HARD EXCLUSION: Order number patterns - always exclude
        let orderPattern = #"(?i)(order|ord)\s*:?\s*\d+"#
        if let regex = try? NSRegularExpression(pattern: orderPattern),
           regex.firstMatch(in: trimmedText, range: NSRange(trimmedText.startIndex..., in: trimmedText)) != nil {
            exclusionScore = 1.0
            reason = "Contains order number pattern"
            return (true, exclusionScore, reason)
        }
        
        // HARD EXCLUSION: Lines with only numbers and separators (e.g., "11", "20/03/", "73290")
        let onlyNumbersPattern = #"^[\d\s/:\-\.]+$"#
        if let regex = try? NSRegularExpression(pattern: onlyNumbersPattern),
           regex.firstMatch(in: trimmedText, range: NSRange(trimmedText.startIndex..., in: trimmedText)) != nil {
            // Check if it's a reasonable price format (has decimal point or is reasonable length)
            let hasDecimal = trimmedText.contains(".") || trimmedText.contains(",")
            let isReasonablePrice = hasDecimal && trimmedText.count <= 15
            if !isReasonablePrice {
                exclusionScore = 1.0
                reason = "Line contains only numbers and separators (likely metadata)"
                return (true, exclusionScore, reason)
            }
        }
        
        // Restaurant name keywords - exclude if prominent
        let restaurantKeywords = ["restaurant", "cafe", "bar", "grill", "bistro", "diner", "eatery", "kitchen"]
        if restaurantKeywords.contains(where: lowercased.contains) {
            let words = lowercased.components(separatedBy: .whitespaces)
            if words.first(where: { restaurantKeywords.contains($0) }) != nil {
                exclusionScore = max(exclusionScore, 0.8)
                reason = "Contains prominent restaurant name keyword"
            }
        }
        
        // Waiter/server keywords
        let serverKeywords = ["waiter", "server", "cashier", "served by", "server:", "cashier:", "waiter:"]
        if serverKeywords.contains(where: lowercased.contains) {
            exclusionScore = max(exclusionScore, 0.8)
            reason = "Contains waiter/server keyword"
        }
        
        // Time patterns - exclude if entire line is time
        let timePattern = #"\d{1,2}:\d{2}(:\d{2})?\s*(AM|PM|am|pm)?"#
        if let regex = try? NSRegularExpression(pattern: timePattern),
           let match = regex.firstMatch(in: trimmedText, range: NSRange(trimmedText.startIndex..., in: trimmedText)) {
            let timeText = String(trimmedText[Range(match.range, in: trimmedText)!])
            if trimmedText.count <= timeText.count + 3 {
                exclusionScore = max(exclusionScore, 0.9)
                reason = "Line is primarily a time"
            }
        }
        
        // Invoice/receipt number patterns
        let invoicePatterns = ["invoice", "receipt", "bill #", "receipt #", "invoice #", "order #", "order number", "reference"]
        if invoicePatterns.contains(where: lowercased.contains) {
            exclusionScore = max(exclusionScore, 0.8)
            reason = "Contains invoice/receipt number pattern"
        }
        
        // Phone numbers
        let phonePattern = #"[\d\s\-\(\)]{10,}"#
        if let regex = try? NSRegularExpression(pattern: phonePattern),
           let match = regex.firstMatch(in: trimmedText, range: NSRange(trimmedText.startIndex..., in: trimmedText)),
           let range = Range(match.range, in: trimmedText) {
            let phoneText = String(trimmedText[range]).replacingOccurrences(of: "[^0-9]", with: "", options: .regularExpression)
            if phoneText.count >= 10 {
                exclusionScore = max(exclusionScore, 0.9)
                reason = "Contains phone number"
            }
        }
        
        // Tax ID patterns
        let taxIdPatterns = ["tax id", "ein", "tax number", "tax id:", "vat number"]
        if taxIdPatterns.contains(where: lowercased.contains) {
            exclusionScore = max(exclusionScore, 0.8)
            reason = "Contains tax ID pattern"
        }
        
        // Hard-exclude if score > 0.7 (stricter threshold)
        let excluded = exclusionScore > 0.7
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
        
        // CRITICAL: Require BOTH alphabetic text AND price (not just one)
        let hasLetters = text.rangeOfCharacter(from: CharacterSet.letters) != nil
        let pricePresent = hasPriceInLine(text)
        
        // Count alphabetic characters (minimum 3 required)
        let alphabeticCount = text.filter { $0.isLetter }.count
        
        // 1. Contains sufficient alphabetic text (minimum 3 characters) - +0.2
        if alphabeticCount >= 3 {
            score += 0.2
            scoreBreakdown["alphabetic_text"] = 0.2
            reasons.append("Contains sufficient alphabetic text (\(alphabeticCount) chars) (+0.2)")
        } else if hasLetters {
            score += 0.05 // Partial credit for some letters
            scoreBreakdown["alphabetic_text"] = 0.05
            reasons.append("Contains some alphabetic text (\(alphabeticCount) chars, need 3) (+0.05)")
        } else {
            reasons.append("No alphabetic text")
        }
        
        // 2. Price present (critical) - +0.3
        if pricePresent {
            score += 0.3
            scoreBreakdown["price_present"] = 0.3
            reasons.append("Price detected (+0.3)")
        } else {
            reasons.append("No price detected")
        }
        
        // REQUIREMENT: Must have both alphabetic text (>=3 chars) AND price to proceed
        if alphabeticCount < 3 || !pricePresent {
            reasons.append("FAILED: Requires both >=3 alphabetic chars AND price")
            return (0.0, reasons, scoreBreakdown)
        }
        
        // 3. Price alignment (X position > 0.7 of receipt width for right-aligned prices) - +0.15
        // boundingBox is already in image coordinates (top-left origin)
        let normalizedX = boundingBox.midX / imageSize.width
        if normalizedX > 0.7 {
            score += 0.15
            scoreBreakdown["price_alignment"] = 0.15
            reasons.append("Price aligned right (>70%) (+0.15)")
        } else if normalizedX > 0.6 {
            score += 0.08 // Partial credit
            scoreBreakdown["price_alignment"] = 0.08
            reasons.append("Price somewhat aligned right (60-70%) (+0.08)")
        } else {
            reasons.append("Price not aligned right (X: \(String(format: "%.2f", normalizedX)))")
        }
        
        // 4. Position between header (top 30%) and totals (bottom 30%) - +0.15
        // boundingBox is in image coordinates (top-left origin)
        // Y=0 is top, Y=imageSize.height is bottom
        let normalizedY = boundingBox.minY / imageSize.height
        // Valid range: between 30% from top and 70% from top (middle 40% zone)
        let positionScore = (normalizedY > 0.3 && normalizedY < 0.7) ? 0.15 : 0.0
        score += positionScore
        scoreBreakdown["position"] = positionScore
        if positionScore > 0 {
            reasons.append("In valid position range (30%-70%) (+0.15)")
        } else {
            reasons.append("Outside valid position range (Y: \(String(format: "%.2f", normalizedY)))")
        }
        
        // 5. No excluded keywords (bonus, not penalty) - +0.1
        // Exclusion score is passed in (0.0 = no exclusion, 1.0 = fully excluded)
        let exclusionPenalty = exclusionScore * 0.4 // Increased penalty
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
            // Price sanity check: between $0.01 and $10,000
            if price >= 0.01 && price <= 10000 {
                if let total = total {
                    if price < total * 2 {
                        score += 0.15
                        scoreBreakdown["price_magnitude"] = 0.15
                        reasons.append("Price is reasonable and < 2x total (+0.15)")
                    } else {
                        reasons.append("Price magnitude suspicious (price: \(price), total: \(total))")
                    }
                } else {
                    score += 0.1
                    scoreBreakdown["price_magnitude"] = 0.1
                    reasons.append("Price exists in valid range, no total for validation (+0.1)")
                }
            } else {
                reasons.append("Price out of valid range (0.01-10000): \(price)")
            }
        } else {
            reasons.append("Could not extract price")
        }
        
        // 7. Confidence score - +0.05
        if confidence > 0.7 {
            score += 0.05
            scoreBreakdown["confidence"] = 0.05
            reasons.append("High confidence (>0.7) (+0.05)")
        } else if confidence > 0.5 {
            score += 0.02
            scoreBreakdown["confidence"] = 0.02
            reasons.append("Medium confidence (0.5-0.7) (+0.02)")
        } else {
            reasons.append("Low confidence (<0.5)")
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
        
        // Analyze receipt structure: detect zones and price column alignment
        // Note: zones are detected but not currently used - reserved for future enhancements
        let _ = ReceiptStructureAnalyzer.analyzeZones(from: observations, imageSize: imageSize)
        let priceColumn = ReceiptStructureAnalyzer.detectPriceColumn(from: observations, imageSize: imageSize)
        
        if let priceColumn = priceColumn {
            print("[OCRService] Detected price column at X: \(String(format: "%.2f", priceColumn.priceColumnX)), confidence: \(String(format: "%.2f", priceColumn.confidence))")
        }
        
        // Phase 3: Multi-line grouping - group item name and price on separate lines
        // Use ReceiptStructureAnalyzer for better grouping
        lines = ReceiptStructureAnalyzer.groupMultiLineItems(
            lines: lines,
            imageSize: imageSize,
            priceColumn: priceColumn
        )
        
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
        for (line, _, _) in lines {
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
            
            // Additional validation: Check price column alignment if available
            var priceColumnPenalty = 0.0
            if let priceColumn = priceColumn {
                let isAligned = ReceiptStructureAnalyzer.isPriceAligned(observation, columnAlignment: priceColumn)
                if !isAligned && hasPriceInLine(line) {
                    // Price not aligned with detected column - apply penalty
                    priceColumnPenalty = 0.2
                }
            }
            
            // Line item qualification with scoring
            // Increased threshold to 0.5 for stricter validation
            let (itemScore, scoreReasons, scoreBreakdown) = scoreLineItem(line, boundingBox: imageRect, imageSize: imageSize, total: total, confidence: confidence, exclusionScore: exclusionScore)
            
            // Apply price column alignment penalty
            let finalScore = itemScore - priceColumnPenalty
            
            // Stricter threshold: require score >= 0.5 (was 0.4)
            let isUncertain = finalScore >= 0.45 && finalScore < 0.5
            let isAccepted = finalScore >= 0.5
            
            if isAccepted || isUncertain {
                // Try to parse as line item
                if let item = parseItem(from: line) {
                    items.append(item)
                    classification = .lineItem
                    let uncertaintyNote = isUncertain ? " [UNCERTAIN]" : ""
                    let alignmentNote = priceColumnPenalty > 0 ? " [PRICE_MISALIGNED]" : ""
                    classificationReason = "Line item (score: \(String(format: "%.2f", finalScore)))\(uncertaintyNote)\(alignmentNote) - \(scoreReasons.joined(separator: ", "))"
                    
                    boundingBoxes.append(BoundingBox(
                        rectangle: imageRect,
                        text: line,
                        classification: .lineItem
                    ))
                } else {
                    classificationReason = "Failed to parse as item despite score \(String(format: "%.2f", finalScore)): \(scoreReasons.joined(separator: ", "))"
                }
            } else {
                let alignmentNote = priceColumnPenalty > 0 ? " (price misaligned)" : ""
                classificationReason = "Low line item score (\(String(format: "%.2f", finalScore)))\(alignmentNote): \(scoreReasons.joined(separator: ", "))"
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
        
        // POST-PROCESSING VALIDATION
        
        // 1. Item count validation: If <2 items extracted, likely parsing failure
        if items.count < 2 {
            print("[OCRService] WARNING: Only \(items.count) item(s) extracted - possible parsing failure")
        }
        
        // 2. Price range validation: All prices should be within reasonable range
        var validItems: [ReceiptItem] = []
        for item in items {
            if item.unitPrice >= 0.01 && item.unitPrice <= 10000 && item.quantity >= 1 && item.quantity <= 999 {
                validItems.append(item)
            } else {
                print("[OCRService] WARNING: Removed invalid item: \(item.name) (price: \(item.unitPrice), qty: \(item.quantity))")
            }
        }
        items = validItems
        
        // 3. Metadata cleanup: Remove any items that match known metadata patterns
        let metadataPatterns = [
            #"(?i)(table|tab|tbl)\s*:?\s*\d+"#,
            #"(?i)(order|ord)\s*:?\s*\d+"#,
            #"\d{1,2}[/-]\d{1,2}[/-]\d{2,4}"#,
            #"^\d+$"# // Only numbers
        ]
        
        validItems = []
        for item in items {
            var isMetadata = false
            for pattern in metadataPatterns {
                if let regex = try? NSRegularExpression(pattern: pattern),
                   regex.firstMatch(in: item.name, range: NSRange(item.name.startIndex..., in: item.name)) != nil {
                    isMetadata = true
                    break
                }
            }
            
            // Also check if name has <3 alphabetic characters (likely not a real item)
            let alphabeticCount = item.name.filter { $0.isLetter }.count
            if alphabeticCount < 3 {
                isMetadata = true
            }
            
            if !isMetadata {
                validItems.append(item)
            } else {
                print("[OCRService] WARNING: Removed metadata item: \(item.name)")
            }
        }
        items = validItems
        
        // 4. If subtotal not found, calculate from items
        if subtotal == nil {
            subtotal = items.reduce(Decimal(0)) { $0 + $1.totalPrice }
        }
        
        // 5. Total consistency validation: Extracted total should match calculated total within 2%
        var validatedTotal = total
        var totalConfidence: Double = 1.0
        
        if let subtotal = subtotal, let extractedTotal = total {
            var calculatedTotal = subtotal
            
            // Add tax if present
            if let vatPercentage = vatPercentage {
                calculatedTotal += subtotal * vatPercentage / 100
            }
            
            // Add service if present
            if let servicePercentage = servicePercentage {
                calculatedTotal += subtotal * servicePercentage / 100
            }
            
            // Check if totals match (allow 2% tolerance for rounding and OCR errors)
            let difference = abs((calculatedTotal - extractedTotal).doubleValue)
            let tolerance = (extractedTotal * 0.02).doubleValue // 2% tolerance
            
            if difference > tolerance {
                print("[OCRService] WARNING: Totals don't match! Calculated: \(calculatedTotal), Found: \(extractedTotal), Difference: \(difference)")
                
                // If difference is significant (>5%), use calculated total instead
                let fivePercentThreshold = (extractedTotal * 0.05).doubleValue
                if difference > fivePercentThreshold {
                    print("[OCRService] Using calculated total instead of extracted total (difference >5%)")
                    validatedTotal = calculatedTotal
                    totalConfidence = 0.7 // Lower confidence when we override
                } else {
                    totalConfidence = 0.8 // Medium confidence when close but not exact
                }
            } else {
                totalConfidence = 0.95 // High confidence when totals match
            }
        } else if let subtotal = subtotal {
            // No extracted total, use calculated total
            var calculatedTotal = subtotal
            if let vatPercentage = vatPercentage {
                calculatedTotal += subtotal * vatPercentage / 100
            }
            if let servicePercentage = servicePercentage {
                calculatedTotal += subtotal * servicePercentage / 100
            }
            validatedTotal = calculatedTotal
            totalConfidence = 0.85 // Medium-high confidence for calculated total
        }
        
        // 6. Overall confidence calculation
        let itemCountScore = min(1.0, Double(items.count) / 5.0) // Prefer 5+ items
        let overallConfidence = (itemCountScore * 0.3) + (totalConfidence * 0.4) + (Double(validItems.count) / Double(max(items.count, 1)) * 0.3)
        
        print("[OCRService] Post-processing validation complete:")
        print("  - Items: \(items.count) (valid: \(validItems.count))")
        print("  - Total confidence: \(String(format: "%.2f", overallConfidence))")
        print("  - Total: \(validatedTotal?.description ?? "nil") (confidence: \(String(format: "%.2f", totalConfidence)))")
        
        let result = OCRResult(
            items: items,
            subtotal: subtotal,
            vatPercentage: vatPercentage,
            servicePercentage: servicePercentage,
            total: validatedTotal,
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
                let priceStr = String(trimmed[range]).replacingOccurrences(of: "[$,\\s]", with: "", options: .regularExpression)
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
                    let priceStr = String(trimmed[range]).replacingOccurrences(of: "\\s", with: "", options: .regularExpression).replacingOccurrences(of: ",", with: ".")
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
        
        // STRICT VALIDATION: Require minimum 3 alphabetic characters in item name
        let alphabeticCount = name.filter { $0.isLetter }.count
        guard alphabeticCount >= 3 else {
            return nil // Reject items with less than 3 alphabetic characters
        }
        
        guard !name.isEmpty else { return nil }
        
        // STRICT VALIDATION: Quantity must be between 1-999
        guard quantity >= 1 && quantity <= 999 else {
            return nil
        }
        
        // STRICT VALIDATION: Price sanity checks
        // Unit price must be between $0.01 and $10,000
        let unitPrice = price / Decimal(quantity)
        guard unitPrice >= 0.01 && unitPrice <= 10000 else {
            return nil
        }
        
        // STRICT VALIDATION: Reject if price matches common metadata patterns
        // Check if price looks like a table number, order number, or date
        // Table numbers are typically 1-200, order numbers can be larger
        // If price is a round number < 200 and name is suspicious, reject
        // Check if price is a whole number by comparing with its rounded value
        let priceDouble = price.doubleValue
        if price < 200 && priceDouble.truncatingRemainder(dividingBy: 1) == 0 {
            let suspiciousPatterns = ["table", "order", "seat", "tab", "ord"]
            let lowercasedName = name.lowercased()
            if suspiciousPatterns.contains(where: lowercasedName.contains) {
                return nil // Likely metadata, not an item
            }
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
            let amountStr = String(line[range]).replacingOccurrences(of: "[,\\s]", with: "", options: .regularExpression)
            if let amount = Decimal(string: amountStr), amount > 0 {
                return amount
            }
        }
        
        // Pattern 2: European format "25,50"
        let pattern2 = #"(\d{1,3}(?:\s\d{3})*(?:,\d{2})?)"#
        if let regex = try? NSRegularExpression(pattern: pattern2),
           let match = regex.firstMatch(in: line, range: NSRange(line.startIndex..., in: line)),
           let range = Range(match.range(at: 1), in: line) {
            let amountStr = String(line[range]).replacingOccurrences(of: "\\s", with: "", options: .regularExpression).replacingOccurrences(of: ",", with: ".")
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
                    let amountStr = String(text[range]).replacingOccurrences(of: "[,\\s]", with: "", options: .regularExpression)
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
                    let amountStr = String(text[range]).replacingOccurrences(of: "\\s", with: "", options: .regularExpression).replacingOccurrences(of: ",", with: ".")
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

