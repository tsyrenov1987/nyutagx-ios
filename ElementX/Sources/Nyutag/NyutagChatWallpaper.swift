//
// Нютаг (форк Element X iOS) — фон ленты чата.
//
// SPDX-License-Identifier: AGPL-3.0-only
//

import Compound
import SwiftUI

/// Варианты фона чатов (выбор в настройках, хранится на устройстве; те же цвета, что на Android).
enum NyutagWallpaperStyle: String, CaseIterable, Identifiable {
    case sky, steppe, sand, dusk, plain
    
    static let storageKey = "nyutag.chatWallpaper"
    
    var id: Self { self }
    
    var title: String {
        switch self {
        case .sky: NyutagL10n.wallpaperSky
        case .steppe: NyutagL10n.wallpaperSteppe
        case .sand: NyutagL10n.wallpaperSand
        case .dusk: NyutagL10n.wallpaperDusk
        case .plain: NyutagL10n.wallpaperPlain
        }
    }
    
    /// nil — обычный фон, без узора.
    var background: UIColor? {
        switch self {
        case .sky: NyutagBrand.wallpaper
        case .steppe: Self.color(light: 0xE7F0E2, dark: 0x0F1610)
        case .sand: Self.color(light: 0xF3EADB, dark: 0x1A150F)
        case .dusk: Self.color(light: 0xECE7F5, dark: 0x15111D)
        case .plain: nil
        }
    }
    
    var ink: UIColor? {
        switch self {
        case .sky: NyutagBrand.wallpaperInk
        case .steppe: Self.color(light: 0x3F7A35, dark: 0x6DBE5F, alpha: 0.10)
        case .sand: Self.color(light: 0x9A6B25, dark: 0xD9A227, alpha: 0.10)
        case .dusk: Self.color(light: 0x6A4AA5, dark: 0x9C7BE0, alpha: 0.11)
        case .plain: nil
        }
    }
    
    private static func color(light: UInt32, dark: UInt32, alpha: CGFloat = 1) -> UIColor {
        UIColor { $0.userInterfaceStyle == .dark ? UIColor(rgb: dark, alpha: alpha) : UIColor(rgb: light, alpha: alpha) }
    }
}

/// Мягкий фон с едва заметным узором из значков — как в привычных мессенджерах: пузыри читаются лучше, чем на белом.
/// Узор периодичен (плитка 240 pt), поэтому рисуется одинаково при любом размере экрана и не «плывёт» при повороте.
struct NyutagChatWallpaper: View {
    /// Явный вариант (превью в настройках); nil — выбранный пользователем.
    var style: NyutagWallpaperStyle?
    /// Масштаб узора: в маленьких превью значки мельче.
    var scale: CGFloat = 1
    
    @AppStorage(NyutagWallpaperStyle.storageKey) private var storedStyle: NyutagWallpaperStyle = .sky
    
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
        let style = style ?? storedStyle
        if let background = style.background, let ink = style.ink {
            pattern(ink: Color(ink))
                .background(Color(background))
                .accessibilityHidden(true)
        } else {
            Color.clear
        }
    }
    
    private func pattern(ink: Color) -> some View {
        Canvas { context, size in
            let tile = Self.tile * scale
            let resolved = Self.symbols.map { name in
                var image = context.resolve(Image(systemName: name))
                image.shading = .color(ink)
                return image
            }
            let columns = Int(ceil(size.width / tile))
            let rows = Int(ceil(size.height / tile))
            for row in 0...rows {
                for column in 0...columns {
                    let origin = CGPoint(x: CGFloat(column) * tile, y: CGFloat(row) * tile)
                    for (index, glyph) in Self.layout.enumerated() {
                        var tileContext = context
                        tileContext.translateBy(x: origin.x + glyph.x * scale, y: origin.y + glyph.y * scale)
                        tileContext.rotate(by: .degrees(glyph.angle))
                        let image = resolved[index % resolved.count]
                        let side = glyph.size * scale
                        tileContext.draw(image, in: CGRect(x: -side / 2, y: -side / 2, width: side, height: side))
                    }
                }
            }
        }
    }
}

/// Плитки-превью фона в настройках: тап — выбрать.
struct NyutagWallpaperPicker: View {
    @AppStorage(NyutagWallpaperStyle.storageKey) private var selected: NyutagWallpaperStyle = .sky
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(NyutagWallpaperStyle.allCases) { style in
                    let isSelected = style == selected
                    Button {
                        selected = style
                    } label: {
                        VStack(spacing: 4) {
                            NyutagChatWallpaper(style: style, scale: 0.5)
                                .frame(width: 64, height: 96)
                                .background(Color.compound.bgCanvasDefault)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                                .overlay {
                                    RoundedRectangle(cornerRadius: 12)
                                        .strokeBorder(isSelected ? Color(NyutagBrand.blue) : .compound.borderInteractiveSecondary,
                                                      lineWidth: isSelected ? 2 : 1)
                                }
                                .overlay {
                                    if isSelected {
                                        CompoundIcon(\.checkCircleSolid)
                                            .foregroundStyle(Color(NyutagBrand.blue))
                                    }
                                }
                            Text(style.title)
                                .font(.compound.bodySM)
                                .foregroundStyle(isSelected ? .compound.textPrimary : .compound.textSecondary)
                        }
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(isSelected ? .isSelected : [])
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
    }
}
