//
//  ExportService.swift
//  Cheq
//
//  Service for exporting receipts to CSV format
//

import Foundation

class ExportService {
    static let shared = ExportService()
    
    private init() {}
    
    /// Exports receipts to CSV format and returns the file URL
    /// - Parameters:
    ///   - receipts: Array of receipts to export
    ///   - userId: User ID for file naming
    /// - Returns: URL to the temporary CSV file, or nil if export fails
    func exportReceiptsToCSV(_ receipts: [Receipt], userId: String) -> URL? {
        guard !receipts.isEmpty else {
            return nil
        }
        
        // Create CSV content
        var csvContent = "Date,Total,Subtotal,VAT %,Service %,Items Count,People Count\n"
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        
        for receipt in receipts {
            let dateString = dateFormatter.string(from: receipt.timestamp)
            let total = receipt.total
            let subtotal = receipt.subtotal
            let vatPercentage = receipt.vatPercentage
            let servicePercentage = receipt.servicePercentage
            let itemsCount = receipt.items.count
            let peopleCount = receipt.people.count
            
            // Format values (remove currency symbols for CSV)
            let totalString = String(format: "%.2f", total.doubleValue)
            let subtotalString = String(format: "%.2f", subtotal.doubleValue)
            let vatString = String(format: "%.2f", vatPercentage.doubleValue)
            let serviceString = String(format: "%.2f", servicePercentage.doubleValue)
            
            csvContent += "\(dateString),\(totalString),\(subtotalString),\(vatString),\(serviceString),\(itemsCount),\(peopleCount)\n"
        }
        
        // Create temporary file
        let fileName = "cheq_receipts_\(userId)_\(Date().timeIntervalSince1970).csv"
        let tempDir = FileManager.default.temporaryDirectory
        let fileURL = tempDir.appendingPathComponent(fileName)
        
        // Write CSV content to file
        do {
            try csvContent.write(to: fileURL, atomically: true, encoding: .utf8)
            return fileURL
        } catch {
            print("Error writing CSV file: \(error)")
            return nil
        }
    }
}

