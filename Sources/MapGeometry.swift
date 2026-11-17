import CoreGraphics

enum MapGeometry {
    // Preserve the world point under the first pinch location as scale changes.
    static func zoomOffset(startOffset: CGSize, startZoom: CGFloat, newZoom: CGFloat, anchor: CGPoint, center: CGPoint) -> CGSize {
        let ratio = newZoom / max(0.001, startZoom)
        return CGSize(width: startOffset.width + (1 - ratio) * (anchor.x - center.x - startOffset.width),
                      height: startOffset.height + (1 - ratio) * (anchor.y - center.y - startOffset.height))
    }
}
