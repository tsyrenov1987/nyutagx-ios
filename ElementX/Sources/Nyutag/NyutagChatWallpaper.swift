//
// Нютаг (форк Element X iOS) — фон ленты чата.
//
// SPDX-License-Identifier: AGPL-3.0-only
//

import SwiftUI

/// Мягкий фон с едва заметным узором из значков — как в привычных мессенджерах: пузыри читаются лучше, чем на белом.
/// Узор периодичен (плитка 240 pt), поэтому рисуется одинаково при любом размере экрана и не «плывёт» при повороте.
struct NyutagChatWallpaper: View {
    private static let tile: CGFloat = 240
    private static let symbols = ["bubble.left", "heart", "moon.stars", "sun.max", "music.note", "camera", "leaf",
                                  "mountain.2", "flame", "star", "paperplane", "hands.clap", "gift", "house", "cloud", "phone"]
    /// Значок в плитке: центр, поворот и размер; подобраны вручную, без случайности.
    private struct Glyph {
        let x: CGFloat
        let y: CGFloat
        let angle: Double
        let size: CGFloat
    }
    
    private static let layout: [Glyph] = [
        .init(x: 24, y: 22, angle: -12, size: 22), .init(x: 92, y: 40, angle: 10, size: 20), .init(x: 170, y: 18, angle: -6, size: 22),
        .init(x: 214, y: 70, angle: 16, size: 18), .init(x: 40, y: 92, angle: 8, size: 20), .init(x: 128, y: 104, angle: -14, size: 24),
        .init(x: 196, y: 136, angle: 6, size: 20), .init(x: 22, y: 160, angle: -8, size: 22), .init(x: 84, y: 172, angle: 14, size: 18),
        .init(x: 150, y: 186, angle: -10, size: 22), .init(x: 220, y: 214, angle: 12, size: 18), .init(x: 60, y: 226, angle: -4, size: 20),
        .init(x: 110, y: 60, angle: 20, size: 16), .init(x: 16, y: 116, angle: -18, size: 16), .init(x: 176, y: 84, angle: -20, size: 16),
        .init(x: 130, y: 230, angle: 8, size: 16)
    ]
    
    var body: some View {
        Canvas { context, size in
            let ink = Color(NyutagBrand.wallpaperInk)
            let resolved = Self.symbols.map { name in
                var image = context.resolve(Image(systemName: name))
                image.shading = .color(ink)
                return image
            }
            let columns = Int(ceil(size.width / Self.tile))
            let rows = Int(ceil(size.height / Self.tile))
            for row in 0...rows {
                for column in 0...columns {
                    let origin = CGPoint(x: CGFloat(column) * Self.tile, y: CGFloat(row) * Self.tile)
                    for (index, glyph) in Self.layout.enumerated() {
                        var tileContext = context
                        tileContext.translateBy(x: origin.x + glyph.x, y: origin.y + glyph.y)
                        tileContext.rotate(by: .degrees(glyph.angle))
                        let image = resolved[index % resolved.count]
                        tileContext.draw(image, in: CGRect(x: -glyph.size / 2, y: -glyph.size / 2, width: glyph.size, height: glyph.size))
                    }
                }
            }
        }
        .background(Color(NyutagBrand.wallpaper))
        .accessibilityHidden(true)
    }
}
