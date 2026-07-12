import Foundation

extension String {
    /// Decodes a null-terminated `CChar` buffer as UTF-8 without the
    /// `String(cString: [CChar])` array initializer that the iOS 26 SDK
    /// deprecates. Routes through the (non-deprecated) pointer initializer.
    init(cBuffer buffer: [CChar]) {
        self = buffer.withUnsafeBufferPointer { pointer in
            pointer.baseAddress.map { String(cString: $0) } ?? ""
        }
    }
}
