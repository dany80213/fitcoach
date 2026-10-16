import SwiftUI
import ImageIO
import UniformTypeIdentifiers

/// Gestione della foto profilo senza dipendere da UIKit/AppKit (funziona su iOS e macOS).
enum AvatarImage {
    /// Riduce la foto a max 640 px e la ricomprime in JPEG, così il profilo resta leggero.
    static func downscaledJPEG(from data: Data, maxPixel: Int = 640) -> Data? {
        guard let src = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }
        let opts: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixel,
        ]
        guard let cg = CGImageSourceCreateThumbnailAtIndex(src, 0, opts as CFDictionary) else { return nil }
        let out = NSMutableData()
        guard let dest = CGImageDestinationCreateWithData(out, UTType.jpeg.identifier as CFString, 1, nil) else { return nil }
        CGImageDestinationAddImage(dest, cg, [kCGImageDestinationLossyCompressionQuality: 0.8] as CFDictionary)
        return CGImageDestinationFinalize(dest) ? out as Data : nil
    }

    static func image(from data: Data) -> Image? {
        guard let src = CGImageSourceCreateWithData(data as CFData, nil),
              let cg = CGImageSourceCreateImageAtIndex(src, 0, nil) else { return nil }
        return Image(decorative: cg, scale: 1)
    }
}

/// Foto profilo rotonda; senza foto mostra un segnaposto o le iniziali.
struct ProfileAvatar: View {
    let data: Data?
    var name: String = ""
    var size: CGFloat = 96

    var body: some View {
        Group {
            if let data, let image = AvatarImage.image(from: data) {
                image.resizable().scaledToFill()
            } else if let initial = name.first {
                Text(String(initial).uppercased()).font(.system(size: size * 0.42, weight: .semibold))
            } else {
                Image(systemName: "person.fill").font(.system(size: size * 0.45)).foregroundStyle(.secondary)
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .glassEffect(.regular, in: .circle)
    }
}
