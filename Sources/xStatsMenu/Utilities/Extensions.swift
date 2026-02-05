import SwiftUI
import AppKit

extension View {
    func snapshot() -> NSImage {
        let hosting = NSHostingController(rootView: self)
        
        // Let SwiftUI calculate the intrinsic size
        let targetSize = hosting.view.intrinsicContentSize
        let width = max(targetSize.width, 60)
        let height = max(targetSize.height, 22)
        
        hosting.view.frame = NSRect(x: 0, y: 0, width: width, height: height)

        guard let bitmapRep = hosting.view.bitmapImageRepForCachingDisplay(in: hosting.view.bounds) else {
            // Return a placeholder image if caching fails
            let image = NSImage(size: NSSize(width: 60, height: 22))
            return image
        }
        
        hosting.view.cacheDisplay(in: hosting.view.bounds, to: bitmapRep)

        let image = NSImage(size: hosting.view.bounds.size)
        image.addRepresentation(bitmapRep)
        
        // Make it template for dark/light mode support
        image.isTemplate = false

        return image
    }
    
    func snapshotWithSize(width: CGFloat, height: CGFloat) -> NSImage {
        let hosting = NSHostingController(rootView: self)
        hosting.view.frame = NSRect(x: 0, y: 0, width: width, height: height)

        guard let bitmapRep = hosting.view.bitmapImageRepForCachingDisplay(in: hosting.view.bounds) else {
            let image = NSImage(size: NSSize(width: width, height: height))
            return image
        }
        
        hosting.view.cacheDisplay(in: hosting.view.bounds, to: bitmapRep)

        let image = NSImage(size: hosting.view.bounds.size)
        image.addRepresentation(bitmapRep)
        image.isTemplate = false

        return image
    }
}

extension Double {
    func formattedBytes() -> String {
        let kb = 1024.0
        let mb = kb * 1024.0
        let gb = mb * 1024.0
        let tb = gb * 1024.0

        if self >= tb {
            return String(format: "%.2f TB", self / tb)
        } else if self >= gb {
            return String(format: "%.2f GB", self / gb)
        } else if self >= mb {
            return String(format: "%.2f MB", self / mb)
        } else if self >= kb {
            return String(format: "%.2f KB", self / kb)
        } else {
            return String(format: "%.0f B", self)
        }
    }

    func formattedSpeed() -> String {
        return self.formattedBytes() + "/s"
    }
}

extension UInt64 {
    func formattedBytes() -> String {
        Double(self).formattedBytes()
    }
}

extension Int {
    func formattedTime() -> String {
        if self < 0 {
            return "Calculating..."
        }

        let hours = self / 60
        let minutes = self % 60

        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }
}
