import Foundation
import CoreGraphics
import Accelerate

/// Computes pixel-level differences between consecutive frames
/// to detect meaningful screen changes
struct FrameDiffEngine {

    /// Result of comparing two frames
    struct DiffResult {
        let changeRatio: Double    // 0.0 = identical, 1.0 = completely different
        let timestamp: Date
        let isSignificant: Bool    // exceeds threshold

        var changePercent: String {
            String(format: "%.1f%%", changeRatio * 100)
        }
    }

    private let threshold: Double

    init(threshold: Double = 0.05) { // 5% default
        self.threshold = threshold
    }

    /// Compare two CGImages and return the change ratio
    /// Uses fast pixel sampling for efficiency (not full pixel-by-pixel)
    func compare(_ imageA: CGImage, _ imageB: CGImage) -> DiffResult {
        let now = Date()

        // Ensure same dimensions; if not, consider it a major change
        guard imageA.width == imageB.width && imageA.height == imageB.height else {
            return DiffResult(changeRatio: 1.0, timestamp: now, isSignificant: true)
        }

        let width = imageA.width
        let height = imageA.height

        // Sample a subset of pixels for speed (every 4th pixel in a grid)
        let sampleStep = 4
        let bytesPerPixel = 4
        let bytesPerRow = width * bytesPerPixel

        guard let dataA = imageA.dataProvider?.data,
              let dataB = imageB.dataProvider?.data else {
            return DiffResult(changeRatio: 1.0, timestamp: now, isSignificant: true)
        }

        let ptrA = CFDataGetBytePtr(dataA)
        let ptrB = CFDataGetBytePtr(dataB)

        guard let ptrA = ptrA, let ptrB = ptrB else {
            return DiffResult(changeRatio: 1.0, timestamp: now, isSignificant: true)
        }

        var diffCount = 0
        var totalSamples = 0
        let pixelDiffThreshold: Int = 30 // per-channel difference threshold

        for y in stride(from: 0, to: height, by: sampleStep) {
            for x in stride(from: 0, to: width, by: sampleStep) {
                let offset = y * bytesPerRow + x * bytesPerPixel

                // Compare RGB channels (skip alpha)
                let diffR = abs(Int(ptrA[offset]) - Int(ptrB[offset]))
                let diffG = abs(Int(ptrA[offset + 1]) - Int(ptrB[offset + 1]))
                let diffB = abs(Int(ptrA[offset + 2]) - Int(ptrB[offset + 2]))

                if diffR > pixelDiffThreshold || diffG > pixelDiffThreshold || diffB > pixelDiffThreshold {
                    diffCount += 1
                }
                totalSamples += 1
            }
        }

        guard totalSamples > 0 else {
            return DiffResult(changeRatio: 0, timestamp: now, isSignificant: false)
        }

        let ratio = Double(diffCount) / Double(totalSamples)
        return DiffResult(
            changeRatio: ratio,
            timestamp: now,
            isSignificant: ratio >= threshold
        )
    }

    /// Quick check if an image is mostly a single color (blank/lock screen)
    func isBlankScreen(_ image: CGImage) -> Bool {
        let width = image.width
        let height = image.height

        guard let data = image.dataProvider?.data,
              let ptr = CFDataGetBytePtr(data) else { return false }

        let bytesPerPixel = 4
        let bytesPerRow = width * bytesPerPixel
        let sampleStep = 8

        // Sample the first pixel as reference
        let refR = Int(ptr[0])
        let refG = Int(ptr[1])
        let refB = Int(ptr[2])

        var sameCount = 0
        var totalSamples = 0

        for y in stride(from: 0, to: height, by: sampleStep) {
            for x in stride(from: 0, to: width, by: sampleStep) {
                let offset = y * bytesPerRow + x * bytesPerPixel
                let diffR = abs(Int(ptr[offset]) - refR)
                let diffG = abs(Int(ptr[offset + 1]) - refG)
                let diffB = abs(Int(ptr[offset + 2]) - refB)

                if diffR < 10 && diffG < 10 && diffB < 10 {
                    sameCount += 1
                }
                totalSamples += 1
            }
        }

        // If 95%+ pixels are the same color, it's blank
        return totalSamples > 0 && Double(sameCount) / Double(totalSamples) > 0.95
    }
}
