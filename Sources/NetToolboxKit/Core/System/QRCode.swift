import Foundation
#if canImport(UIKit)
import UIKit
import CoreImage
#endif

/// Renders a string to a crisp QR code image via CoreImage.
enum QRCode {
    #if canImport(UIKit)
    static func image(from payload: String, scale: CGFloat = 12) -> UIImage? {
        guard !payload.isEmpty, let filter = CIFilter(name: "CIQRCodeGenerator") else { return nil }
        filter.setValue(Data(payload.utf8), forKey: "inputMessage")
        filter.setValue("M", forKey: "inputCorrectionLevel")
        guard let output = filter.outputImage else { return nil }
        let scaled = output.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
        let context = CIContext()
        guard let cgImage = context.createCGImage(scaled, from: scaled.extent) else { return nil }
        return UIImage(cgImage: cgImage)
    }
    #endif
}
