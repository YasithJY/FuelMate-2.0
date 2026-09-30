import Foundation
import UIKit
import Vision

// MARK: - Scanned Receipt Data Result
public struct ScannedReceiptData: Identifiable {
    public let id = UUID()
    public var totalCost: Double?
    public var volume: Double?
    public var stationName: String?
    public var fuelGrade: String?
    public var rawText: String
    
    public init(
        totalCost: Double? = nil,
        volume: Double? = nil,
        stationName: String? = nil,
        fuelGrade: String? = nil,
        rawText: String = ""
    ) {
        self.totalCost = totalCost
        self.volume = volume
        self.stationName = stationName
        self.fuelGrade = fuelGrade
        self.rawText = rawText
    }
}

// MARK: - On-Device Vision Receipt OCR Service
public final class ReceiptScannerService {
    public static let shared = ReceiptScannerService()
    
    public init() {}
    
    /// Recognizes text from a receipt image and parses fuel stop metrics
    public func scanReceipt(from image: UIImage) async throws -> ScannedReceiptData {
        guard let cgImage = image.cgImage else {
            throw ReceiptScannerError.invalidImage
        }
        
        let recognizedStrings = try await performVisionOCR(on: cgImage)
        let fullText = recognizedStrings.joined(separator: "\n")
        
        return parseReceiptContent(lines: recognizedStrings, rawText: fullText)
    }
    
    // MARK: - Vision OCR Execution
    private func performVisionOCR(on cgImage: CGImage) async throws -> [String] {
        return try await withCheckedThrowingContinuation { continuation in
            let request = VNRecognizeTextRequest { request, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                
                guard let observations = request.results as? [VNRecognizedTextObservation] else {
                    continuation.resume(returning: [])
                    return
                }
                
                let recognizedLines = observations.compactMap { observation in
                    observation.topCandidates(1).first?.string
                }
                
                continuation.resume(returning: recognizedLines)
            }
            
            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true
            request.recognitionLanguages = ["en-US"]
            
            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            do {
                try handler.perform([request])
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }
    
    // MARK: - Heuristic & Regex Parsing
    private func parseReceiptContent(lines: [String], rawText: String) -> ScannedReceiptData {
        var detectedStation: String? = nil
        var detectedGrade: String? = nil
        var detectedTotal: Double? = nil
        var detectedVolume: Double? = nil
        
        let uppercaseText = rawText.uppercased()
        
        // 1. Station Brand Matching (Prioritize Sri Lankan Brands)
        if uppercaseText.contains("CEYPETCO") || uppercaseText.contains("CEYLON PETROLEUM") {
            detectedStation = "Ceypetco"
        } else if uppercaseText.contains("LANKA IOC") || uppercaseText.contains("LIOC") || uppercaseText.contains("IOC") {
            detectedStation = "Lanka IOC"
        } else if uppercaseText.contains("SINOPEC") {
            detectedStation = "Sinopec"
        } else if uppercaseText.contains("SHELL") || uppercaseText.contains("RM PARKS") {
            detectedStation = "Shell / RM Parks"
        } else if uppercaseText.contains("CHEVRON") || uppercaseText.contains("CALTEX") {
            detectedStation = "Chevron"
        }
        
        // 2. Fuel Grade Detection
        if uppercaseText.contains("92") {
            detectedGrade = "Petrol 92 Octane"
        } else if uppercaseText.contains("95") {
            detectedGrade = "Petrol 95 Octane"
        } else if uppercaseText.contains("SUPER DIESEL") || uppercaseText.contains("EURO 4") {
            detectedGrade = "Super Diesel (Euro 4)"
        } else if uppercaseText.contains("DIESEL") || uppercaseText.contains("AUTO DIESEL") {
            detectedGrade = "Auto Diesel"
        } else if uppercaseText.contains("KEROSENE") {
            detectedGrade = "Kerosene"
        }
        
        // 3. Line-by-Line Metric Extraction
        var candidateTotals: [Double] = []
        var candidateVolumes: [Double] = []
        
        for line in lines {
            let upperLine = line.uppercased().trimmingCharacters(in: .whitespacesAndNewlines)
            
            // Check for Total Cost keywords
            let isTotalLine = upperLine.contains("TOTAL") ||
                              upperLine.contains("AMOUNT") ||
                              upperLine.contains("NET") ||
                              upperLine.contains("RS.") ||
                              upperLine.contains("RS ") ||
                              upperLine.contains("LKR") ||
                              upperLine.contains("DUE")
            
            // Check for Volume keywords
            let isVolumeLine = upperLine.contains("VOL") ||
                               upperLine.contains("VOLUME") ||
                               upperLine.contains("QTY") ||
                               upperLine.contains("QUANTITY") ||
                               upperLine.contains("LTR") ||
                               upperLine.contains("LITRE") ||
                               upperLine.contains("LITERS")
            
            // Extract numbers from line
            let numbers = extractNumbers(from: line)
            
            if isTotalLine {
                if let maxNum = numbers.max() {
                    candidateTotals.append(maxNum)
                }
            }
            
            if isVolumeLine {
                for num in numbers {
                    // Reasonable single fill-up volume range: 1.0 to 120.0 Liters
                    if num >= 1.0 && num <= 120.0 {
                        candidateVolumes.append(num)
                    }
                }
            }
        }
        
        // If line-by-line found specific totals, pick the most confident (usually the largest total amount)
        if let bestTotal = candidateTotals.max() {
            detectedTotal = bestTotal
        } else {
            // Fallback: look for standard currency patterns like Rs. 4,500.00 or 4500.00
            let allNumbers = extractNumbers(from: rawText)
            // Filter realistic fuel amounts (e.g. 500 to 50,000 Rs)
            let realisticFuelAmounts = allNumbers.filter { $0 >= 500.0 && $0 <= 75000.0 }
            if let maxAmt = realisticFuelAmounts.max() {
                detectedTotal = maxAmt
            }
        }
        
        // Volume determination
        if let bestVol = candidateVolumes.first {
            detectedVolume = bestVol
        } else {
            // Regex for patterns like "14.50 L" or "14.50LTR"
            if let regexVolume = matchRegex(pattern: #"(\d{1,3}(?:\.\d{1,3})?)\s*(?:L|LTR|LITRES|LTRS)\b"#, in: uppercaseText) {
                detectedVolume = regexVolume
            }
        }
        
        // If both total and volume were not directly found together, but total and typical price exist:
        // E.g. if we have total 6,220 and fuel grade 92 (~311 Rs/L)
        if detectedTotal != nil && detectedVolume == nil {
            if let total = detectedTotal, total > 0 {
                // If there was any number between 5 and 90 in the raw text, it might be the volume
                let allNumbers = extractNumbers(from: rawText)
                if let volCandidate = allNumbers.first(where: { $0 >= 3.0 && $0 <= 80.0 && $0 != detectedTotal }) {
                    detectedVolume = volCandidate
                }
            }
        }
        
        return ScannedReceiptData(
            totalCost: detectedTotal,
            volume: detectedVolume,
            stationName: detectedStation,
            fuelGrade: detectedGrade,
            rawText: rawText
        )
    }
    
    // MARK: - Regex & Number Extraction Helpers
    private func extractNumbers(from string: String) -> [Double] {
        let pattern = #"[0-9]+(?:,[0-9]{3})*(?:\.[0-9]{1,3})?"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
        
        let nsString = string as NSString
        let matches = regex.matches(in: string, range: NSRange(location: 0, length: nsString.length))
        
        return matches.compactMap { match in
            let matchString = nsString.substring(with: match.range).replacingOccurrences(of: ",", with: "")
            return Double(matchString)
        }
    }
    
    private func matchRegex(pattern: String, in text: String) -> Double? {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) else { return nil }
        let nsText = text as NSString
        guard let match = regex.firstMatch(in: text, range: NSRange(location: 0, length: nsText.length)) else { return nil }
        if match.numberOfRanges > 1 {
            let capturedString = nsText.substring(with: match.range(at: 1)).replacingOccurrences(of: ",", with: "")
            return Double(capturedString)
        }
        return nil
    }
}

// MARK: - Errors
public enum ReceiptScannerError: LocalizedError {
    case invalidImage
    case ocrFailed(String)
    
    public var errorDescription: String? {
        switch self {
        case .invalidImage:
            return "Unable to process the selected image. Please try a clearer fuel receipt."
        case .ocrFailed(let msg):
            return "OCR Scanning failed: \(msg)"
        }
    }
}
