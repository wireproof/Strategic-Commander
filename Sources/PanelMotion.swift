import CoreGraphics

// Pure geometry shared by the live drag and the snap at its end.
enum PanelMotion {
    static func height(level: Int, translation: CGFloat, heights: [CGFloat]) -> CGFloat {
        min(heights[2], max(heights[0], heights[level] - translation))
    }

    static func targetLevel(level: Int, predictedTranslation: CGFloat, heights: [CGFloat]) -> Int {
        let target = heights[level] - predictedTranslation
        return heights.indices.min(by: { abs(heights[$0] - target) < abs(heights[$1] - target) }) ?? level
    }
}
