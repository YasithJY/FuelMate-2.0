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
    
    /// Recognizes text from a thermal receipt image using Apple's Vision framework and extracts fuel stop metrics
    public func scanReceipt(from image: UIImage) async throws -> ScannedReceiptData {
        guard let cgImage = image.cgImage else {
            throw ReceiptScannerError.invalidImage
        }
        
        let recognizedStrings = try await performVisionOCR(on: cgImage)
        let fullText = recognizedStrings.joined(separator: "\n")
        
        return parseThermalReceipt(lines: recognizedStrings, rawText: fullText)
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
            
            // Fast & accurate recognition level for thermal receipts
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
    
    // MARK: - Thermal Receipt Parsing Engine
    private func parseThermalReceipt(lines: [String], rawText: String) -> ScannedReceiptData {
        var detectedStation: String? = nil
        var detectedGrade: String? = nil
        var detectedTotal: Double? = nil
        var detectedVolume: Double? = nil
        
        let uppercaseText = rawText.uppercased()
        
        // 1. Station Brand Matching (Prioritize Sri Lankan Brands)
        if uppercaseText.contains("CEYPETCO") || uppercaseText.contains("CEYLON PETROLEUM") || uppercaseText.contains("CPC") {
            detectedStation = "Ceypetco"
        } else if uppercaseText.contains("LANKA IOC") || uppercaseText.contains("LIOC") || uppercaseText.contains("IOC") || uppercaseText.contains("INDIAN OIL") {
            detectedStation = "Lanka IOC"
        } else if uppercaseText.contains("SINOPEC") {
            detectedStation = "Sinopec"
        } else if uppercaseText.contains("SHELL") || uppercaseText.contains("RM PARKS") {
            detectedStation = "Shell / RM Parks"
        } else if uppercaseText.contains("CALTEX") || uppercaseText.contains("CHEVRON") {
            detectedStation = "Chevron"
        }
        
        // 2. Fuel Grade Detection (Exact Sri Lankan Varieties)
        if uppercaseText.contains("XTRAPREMIUM") || uppercaseText.contains("EXTRA PREMIUM") {
            detectedGrade = "Petrol XtraPremium Euro 3"
        } else if uppercaseText.contains("95") {
            if detectedStation == "Lanka IOC" || uppercaseText.contains("PREMIUM") {
                detectedGrade = "Petrol Octane 95 (Premium)"
            } else {
                detectedGrade = "Petrol Octane 95 (Euro 4)"
            }
        } else if uppercaseText.contains("92") || uppercaseText.contains("PETROL") {
            detectedGrade = "Petrol Octane 92"
        } else if uppercaseText.contains("SUPER DIESEL") || uppercaseText.contains("4 STAR") || uppercaseText.contains("EURO 4") {
            detectedGrade = "Lanka Super Diesel 4 Star (Euro 4)"
        } else if uppercaseText.contains("DIESEL") || uppercaseText.contains("AUTO DIESEL") {
            detectedGrade = "Lanka Auto Diesel"
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
                              upperLine.contains("DUE") ||
                              upperLine.contains("PAID") ||
                              upperLine.contains("CASH") ||
                              upperLine.contains("CARD")
            
            // Check for Volume keywords
            let isVolumeLine = upperLine.contains("VOL") ||
                               upperLine.contains("VOLUME") ||
                               upperLine.contains("QTY") ||
                               upperLine.contains("QUANTITY") ||
                               upperLine.contains("LTR") ||
                               upperLine.contains("LITRE") ||
                               upperLine.contains("LITERS") ||
                               upperLine.contains(" LITRE")
            
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
        
        // Select Total Cost
        if let bestTotal = candidateTotals.max() {
            detectedTotal = bestTotal
        } else {
            // Fallback: look for standard currency patterns like Rs. 4,500.00 or 4500.00
            let allNumbers = extractNumbers(from: rawText)
            let realisticFuelAmounts = allNumbers.filter { $0 >= 500.0 && $0 <= 80000.0 }
            if let maxAmt = realisticFuelAmounts.max() {
                detectedTotal = maxAmt
            }
        }
        
        // Select Volume (Liters)
        if let bestVol = candidateVolumes.first {
            detectedVolume = bestVol
        } else {
            // Regex for patterns like "18.50 L" or "18.50LTR" or "18.50 Litres"
            if let regexVolume = matchRegex(pattern: #"(\d{1,3}(?:\.\d{1,3})?)\s*(?:L|LTR|LITRES|LTRS)\b"#, in: uppercaseText) {
                detectedVolume = regexVolume
            }
        }
        
        // Heuristic fallback if volume is missing but total and estimated rate exist
        if detectedTotal != nil && detectedVolume == nil {
            let allNumbers = extractNumbers(from: rawText)
            if let volCandidate = allNumbers.first(where: { $0 >= 3.0 && $0 <= 90.0 && $0 != detectedTotal }) {
                detectedVolume = volCandidate
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

// MARK: - Scanner Errors
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
