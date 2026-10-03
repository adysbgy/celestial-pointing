import Foundation

/// Katalog awal (sesuai PRD: 20–50 bintang terang). Bulan/planet menyusul
/// via AstronomyKit (ephemeris). Koordinat J2000, derajat.
public enum Catalogue {
    public static let brightStars: [CelestialObject] = [
        CelestialObject(id: "sirius",     name: "Sirius",     kind: .star, raDeg: 101.28715533, decDeg: -16.71611586, magnitude: -1.46),
        CelestialObject(id: "canopus",    name: "Canopus",    kind: .star, raDeg:  95.98795798, decDeg: -52.69566138, magnitude: -0.74),
        CelestialObject(id: "arcturus",   name: "Arcturus",   kind: .star, raDeg: 213.91530029, decDeg:  19.18240916, magnitude: -0.05),
        CelestialObject(id: "vega",       name: "Vega",       kind: .star, raDeg: 279.23473479, decDeg:  38.78368896, magnitude:  0.03),
        CelestialObject(id: "capella",    name: "Capella",    kind: .star, raDeg:  79.17232794, decDeg:  45.99799147, magnitude:  0.08),
        CelestialObject(id: "rigel",      name: "Rigel",      kind: .star, raDeg:  78.63446707, decDeg:  -8.20163837, magnitude:  0.13),
        CelestialObject(id: "procyon",    name: "Procyon",    kind: .star, raDeg: 114.82549276, decDeg:   5.22499310, magnitude:  0.34),
        CelestialObject(id: "achernar",   name: "Achernar",   kind: .star, raDeg:  24.42852493, decDeg: -57.23675242, magnitude:  0.46),
        CelestialObject(id: "betelgeuse", name: "Betelgeuse", kind: .star, raDeg:  88.79293899, decDeg:   7.40706400, magnitude:  0.50),
        CelestialObject(id: "hadar",      name: "Hadar",      kind: .star, raDeg: 210.95585555, decDeg: -60.37303922, magnitude:  0.61),
        CelestialObject(id: "altair",     name: "Altair",     kind: .star, raDeg: 297.69582729, decDeg:   8.86832120, magnitude:  0.77),
        CelestialObject(id: "acrux",      name: "Acrux",      kind: .star, raDeg: 186.64956339, decDeg: -63.09909235, magnitude:  0.77),
        CelestialObject(id: "aldebaran",  name: "Aldebaran",  kind: .star, raDeg:  68.98016279, decDeg:  16.50930235, magnitude:  0.85),
        CelestialObject(id: "spica",      name: "Spica",      kind: .star, raDeg: 201.29824736, decDeg: -11.16131949, magnitude:  0.98),
        CelestialObject(id: "antares",    name: "Antares",    kind: .star, raDeg: 247.35191542, decDeg: -26.43200266, magnitude:  1.09),
        CelestialObject(id: "pollux",     name: "Pollux",     kind: .star, raDeg: 116.32895875, decDeg:  28.02619889, magnitude:  1.14),
        CelestialObject(id: "fomalhaut",  name: "Fomalhaut",  kind: .star, raDeg: 344.41269272, decDeg: -29.62223699, magnitude:  1.16),
        CelestialObject(id: "deneb",      name: "Deneb",      kind: .star, raDeg: 310.35797975, decDeg:  45.28033815, magnitude:  1.25),
        CelestialObject(id: "regulus",    name: "Regulus",    kind: .star, raDeg: 152.09296202, decDeg:  11.96720878, magnitude:  1.35),
        CelestialObject(id: "castor",     name: "Castor",     kind: .star, raDeg: 113.64947225, decDeg:  31.88827547, magnitude:  1.58),
        CelestialObject(id: "bellatrix",  name: "Bellatrix",  kind: .star, raDeg:  81.28276394, decDeg:   6.34970330, magnitude:  1.64),
        CelestialObject(id: "alioth",     name: "Alioth",     kind: .star, raDeg: 193.50728989, decDeg:  55.95982123, magnitude:  1.76),
        CelestialObject(id: "alnitak",    name: "Alnitak",    kind: .star, raDeg:  85.18969490, decDeg:  -1.94257785, magnitude:  1.77),
        CelestialObject(id: "dubhe",      name: "Dubhe",      kind: .star, raDeg: 165.93196480, decDeg:  61.75103317, magnitude:  1.79),
        CelestialObject(id: "polaris",    name: "Polaris",    kind: .star, raDeg:  37.95456067, decDeg:  89.26410897, magnitude:  1.98)
    ]
}
