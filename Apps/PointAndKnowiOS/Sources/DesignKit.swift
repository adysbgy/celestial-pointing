import SwiftUI
import CelestialEngine
import PointingKit

/// Komponen desain iPhone mengikuti Figma "Point&Know" + HIG (ADR-019).
///
/// Kontrol bawaan Apple dipakai di mana pun bisa (tombol `.borderedProminent`
/// berbentuk kapsul, ukuran `.large`, Dynamic Type), supaya app terasa
/// seperti app Apple: hanya gaya visualnya yang mengikuti Figma — latar hitam
/// pekat, visual besar di atas, judul tebal, label data monospace.
enum DK {
    /// Biru sistem (mode gelap #0A84FF), sama seperti tombol di Figma.
    static let accent = Color.blue
    static let secondaryText = Color.white.opacity(0.62)
    static let card = Color.white.opacity(0.07)
    static let hairline = Color.white.opacity(0.12)
}

/// Tombol utama: kapsul biru selebar layar.
struct PrimaryButton: View {
    let title: String
    var systemImage: String? = nil
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Group {
                if let systemImage {
                    Label(title, systemImage: systemImage)
                } else {
                    Text(title)
                }
            }
            .font(.headline)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 4)
        }
        .buttonStyle(.borderedProminent)
        .buttonBorderShape(.capsule)
        .controlSize(.large)
        .tint(DK.accent)
    }
}

/// Tautan teks di bawah tombol utama.
struct SecondaryLink: View {
    let title: String
    let action: () -> Void

    var body: some View {
        Button(title, action: action)
            .font(.subheadline)
            .foregroundStyle(DK.secondaryText)
            .buttonStyle(.plain)
            .padding(.vertical, 6)
    }
}

/// Label data kecil bergaya monospace huruf besar ("AZ 142° · ALT 34°").
struct MonoCaption: View {
    let text: String
    var color: Color = DK.secondaryText

    var body: some View {
        Text(verbatim: text)
            .font(.caption2.monospaced().weight(.medium))
            .tracking(1.2)
            .foregroundStyle(color)
    }
}

/// Chip status: titik berwarna + teks ("● PENEMUAN PERTAMA").
struct StatusChip: View {
    let text: String
    var dot: Color = .green

    var body: some View {
        HStack(spacing: 6) {
            Circle().fill(dot).frame(width: 6, height: 6)
            Text(verbatim: text)
                .font(.caption2.monospaced().weight(.semibold))
                .tracking(1)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(Capsule().fill(DK.card))
        .overlay(Capsule().stroke(DK.hairline, lineWidth: 0.5))
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Visual pahlawan (digambar app, tanpa foto)

/// Generator acak deterministik: langit yang sama setiap kali digambar.
private struct SeededRandom {
    private var state: UInt64
    init(seed: UInt64) { state = seed &* 0x9E3779B97F4A7C15 }
    mutating func next() -> Double {
        state = state &* 6364136223846793005 &+ 1442695040888963407
        return Double(state >> 11) / Double(1 << 53)
    }
}

/// Langit berbintang dengan cahaya galaksi samar.
struct StarfieldBackground: View {
    var seed: UInt64 = 7
    var count = 220

    var body: some View {
        Canvas { context, size in
            var rng = SeededRandom(seed: seed)
            // Pita Bima Sakti: elips buram diagonal.
            context.drawLayer { layer in
                layer.addFilter(.blur(radius: 40))
                let band = Path(ellipseIn: CGRect(x: -size.width * 0.2, y: size.height * 0.15,
                                                  width: size.width * 1.4, height: size.height * 0.28))
                layer.rotate(by: .degrees(-24))
                layer.fill(band, with: .color(.white.opacity(0.07)))
            }
            for _ in 0..<count {
                let x = rng.next() * size.width
                let y = rng.next() * size.height
                let m = rng.next()
                let r = 0.4 + m * m * 1.6
                let alpha = 0.25 + m * 0.75
                context.fill(Path(ellipseIn: CGRect(x: x - r, y: y - r, width: r * 2, height: r * 2)),
                             with: .color(.white.opacity(alpha)))
            }
        }
        .background(Color.black)
        .accessibilityHidden(true)
    }
}

/// Bintik bercahaya: satu titik cahaya dengan pendar.
struct GlowingPoint: View {
    var diameter: CGFloat = 14

    var body: some View {
        ZStack {
            Circle().fill(RadialGradient(colors: [.white.opacity(0.55), .clear], center: .center,
                                         startRadius: 0, endRadius: diameter * 3.5))
                .frame(width: diameter * 7, height: diameter * 7)
            Circle().fill(.white).frame(width: diameter * 0.5, height: diameter * 0.5)
                .shadow(color: .white, radius: diameter * 0.6)
        }
        .accessibilityHidden(true)
    }
}

/// Bidikan + label data di tengah langit (layar "Tunjuk untuk menemukan").
struct ReticleOverlay: View {
    let label: String
    let coordinates: String

    var body: some View {
        VStack(spacing: 10) {
            ZStack {
                Circle().stroke(.white.opacity(0.85), lineWidth: 1.2).frame(width: 64, height: 64)
                ForEach(0..<4) { i in
                    Capsule().fill(.white.opacity(0.85)).frame(width: 1.2, height: 10)
                        .offset(y: -40).rotationEffect(.degrees(Double(i) * 90))
                }
                GlowingPoint(diameter: 10)
            }
            .frame(width: 100, height: 100)
            Text(verbatim: label)
                .font(.caption2.monospaced().weight(.semibold))
                .padding(.horizontal, 10).padding(.vertical, 5)
                .background(Capsule().fill(.black.opacity(0.55)))
                .overlay(Capsule().stroke(.white.opacity(0.25), lineWidth: 0.5))
            MonoCaption(text: coordinates, color: .white.opacity(0.75))
        }
        .accessibilityElement(children: .combine)
    }
}

/// Cakrawala Bumi dari angkasa (layar lokasi).
struct EarthLimbHero: View {
    var body: some View {
        ZStack {
            StarfieldBackground(seed: 11, count: 140)
            Canvas { context, size in
                let r = size.width * 1.6
                let center = CGPoint(x: size.width * 0.5, y: size.height * 0.62 + r)
                let planet = Path(ellipseIn: CGRect(x: center.x - r, y: center.y - r, width: r * 2, height: r * 2))
                // Pendar atmosfer: beberapa cincin biru memudar.
                for i in 0..<6 {
                    let grow = CGFloat(i) * 5
                    let ring = Path(ellipseIn: CGRect(x: center.x - r - grow, y: center.y - r - grow,
                                                      width: (r + grow) * 2, height: (r + grow) * 2))
                    context.stroke(ring, with: .color(.blue.opacity(0.32 - Double(i) * 0.05)), lineWidth: 6)
                }
                context.fill(planet, with: .linearGradient(
                    Gradient(colors: [Color.blue.opacity(0.35), .black]),
                    startPoint: CGPoint(x: size.width / 2, y: size.height * 0.6),
                    endPoint: CGPoint(x: size.width / 2, y: size.height)))
                // Lampu kota di sisi malam.
                var rng = SeededRandom(seed: 3)
                for _ in 0..<70 {
                    let x = rng.next() * size.width
                    let y = size.height * (0.72 + rng.next() * 0.28)
                    let s = 0.8 + rng.next() * 1.4
                    context.fill(Path(ellipseIn: CGRect(x: x, y: y, width: s, height: s)),
                                 with: .color(.orange.opacity(0.35 + rng.next() * 0.4)))
                }
            }
        }
        .accessibilityHidden(true)
    }
}

/// Tangan menunjuk (layar "Tunjuk dengan wajar"). Dicerminkan untuk
/// pergelangan kanan.
struct PointingHandHero: View {
    var rightWrist = false

    var body: some View {
        ZStack {
            StarfieldBackground(seed: 23, count: 160)
            GlowingPoint(diameter: 10)
                .offset(x: rightWrist ? -70 : 70, y: -70)
            Image(systemName: "hand.point.up.left.fill")
                .font(.system(.largeTitle))
                .imageScale(.large)
                .scaleEffect(2.6)
                .foregroundStyle(.white.opacity(0.9), .white.opacity(0.4))
                .rotationEffect(.degrees(rightWrist ? -20 : 20))
                .scaleEffect(x: rightWrist ? -1 : 1, y: 1)
                .offset(y: 40)
        }
        .accessibilityHidden(true)
    }
}

/// Mockup Apple Watch yang menampilkan benda terkunci (layar 2 & 3).
struct WatchMockup<Content: View>: View {
    @ViewBuilder let content: () -> Content

    var body: some View {
        ZStack(alignment: .trailing) {
            RoundedRectangle(cornerRadius: 46, style: .continuous)
                .fill(Color(white: 0.09))
                .frame(width: 196, height: 236)
                .overlay(RoundedRectangle(cornerRadius: 46, style: .continuous)
                    .stroke(Color(white: 0.28), lineWidth: 5))
            Capsule().fill(Color(white: 0.3)).frame(width: 9, height: 34).offset(x: 7, y: -40)
            RoundedRectangle(cornerRadius: 36, style: .continuous)
                .fill(.black)
                .frame(width: 172, height: 212)
                .overlay(content().padding(12))
                .padding(.trailing, 12)
        }
        .accessibilityElement(children: .combine)
    }
}
