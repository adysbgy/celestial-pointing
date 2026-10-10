import Foundation
import CelestialEngine

/// Teks onboarding & kartu penemuan yang mengikuti desain Figma "Point&Know" (ADR-019).
public enum DesignText {
    /// "Planet • Terlihat sekarang" — jenis benda dan satu keterangan.
    public static func kindLine(_ kind: ObjectKind, _ detail: String) -> String {
        kind.displayName + " • " + detail
    }
    public static var obDiscoverTitle: String { TextLocalization.text(.obDiscoverTitle) }
    public static var obDiscoverBody: String { TextLocalization.text(.obDiscoverBody) }
    public static var obContinue: String { TextLocalization.text(.obContinue) }
    public static var obHowItWorks: String { TextLocalization.text(.obHowItWorks) }
    public static var obWorldTitle: String { TextLocalization.text(.obWorldTitle) }
    public static var obWorldBody: String { TextLocalization.text(.obWorldBody) }
    public static var obWorldTap: String { TextLocalization.text(.obWorldTap) }
    public static var obWorldOffline: String { TextLocalization.text(.obWorldOffline) }
    public static var obWorldSync: String { TextLocalization.text(.obWorldSync) }
    public static var obWorldSetup: String { TextLocalization.text(.obWorldSetup) }
    public static var obWorldSkip: String { TextLocalization.text(.obWorldSkip) }
    public static var obWatchTitle: String { TextLocalization.text(.obWatchTitle) }
    public static var obWatchNotReady: String { TextLocalization.text(.obWatchNotReady) }
    public static var obWatchBody: String { TextLocalization.text(.obWatchBody) }
    public static var obWatchNotReadyBody: String { TextLocalization.text(.obWatchNotReadyBody) }
    public static var obWatchMotion: String { TextLocalization.text(.obWatchMotion) }
    public static var obWatchMotionDetail: String { TextLocalization.text(.obWatchMotionDetail) }
    public static var obWatchCompass: String { TextLocalization.text(.obWatchCompass) }
    public static var obWatchCompassDetail: String { TextLocalization.text(.obWatchCompassDetail) }
    public static var obChipWatch: String { TextLocalization.text(.obChipWatch) }
    public static var obChipConnected: String { TextLocalization.text(.obChipConnected) }
    public static var obChipAppInstalled: String { TextLocalization.text(.obChipAppInstalled) }
    public static var obChipNotPaired: String { TextLocalization.text(.obChipNotPaired) }
    public static var obChipNotInstalled: String { TextLocalization.text(.obChipNotInstalled) }
    public static var obOnDevice: String { TextLocalization.text(.obOnDevice) }
    public static var obLocationTitle: String { TextLocalization.text(.obLocationTitle) }
    public static var obLocationBody: String { TextLocalization.text(.obLocationBody) }
    public static var obLocationPrivacy: String { TextLocalization.text(.obLocationPrivacy) }
    public static var obLocationUse: String { TextLocalization.text(.obLocationUse) }
    public static var obNotNow: String { TextLocalization.text(.obNotNow) }
    public static var obPointTitle: String { TextLocalization.text(.obPointTitle) }
    public static var obPointBody: String { TextLocalization.text(.obPointBody) }
    public static var obPointLeft: String { TextLocalization.text(.obPointLeft) }
    public static var obPointRight: String { TextLocalization.text(.obPointRight) }
    public static var obPointWristNote: String { TextLocalization.text(.obPointWristNote) }
    public static var obPointTry: String { TextLocalization.text(.obPointTry) }
    public static var obLookupTitle: String { TextLocalization.text(.obLookupTitle) }
    public static var obLookupBody: String { TextLocalization.text(.obLookupBody) }
    public static var obLookupHint: String { TextLocalization.text(.obLookupHint) }
    public static var obReady: String { TextLocalization.text(.obReady) }
    public static var obLocked: String { TextLocalization.text(.obLocked) }
    public static var discFirst: String { TextLocalization.text(.discFirst) }
    public static var discAgain: String { TextLocalization.text(.discAgain) }
    public static var discVisibleNow: String { TextLocalization.text(.discVisibleNow) }
    public static var discNotVisibleNow: String { TextLocalization.text(.discNotVisibleNow) }
    public static var discWhatYoullSee: String { TextLocalization.text(.discWhatYoullSee) }
    public static var discEye: String { TextLocalization.text(.discEye) }
    public static var discBinoculars: String { TextLocalization.text(.discBinoculars) }
    public static var discTelescope: String { TextLocalization.text(.discTelescope) }
    public static var discSave: String { TextLocalization.text(.discSave) }
    public static var discSaved: String { TextLocalization.text(.discSaved) }
    public static var discExplore: String { TextLocalization.text(.discExplore) }
    public static var discJournal: String { TextLocalization.text(.discJournal) }
    public static var guideMoonDesc: String { TextLocalization.text(.guideMoonDesc) }
    public static var guideMoonEye: String { TextLocalization.text(.guideMoonEye) }
    public static var guideMoonBino: String { TextLocalization.text(.guideMoonBino) }
    public static var guideMoonScope: String { TextLocalization.text(.guideMoonScope) }
    public static var guideMercuryDesc: String { TextLocalization.text(.guideMercuryDesc) }
    public static var guideMercuryEye: String { TextLocalization.text(.guideMercuryEye) }
    public static var guideMercuryBino: String { TextLocalization.text(.guideMercuryBino) }
    public static var guideMercuryScope: String { TextLocalization.text(.guideMercuryScope) }
    public static var guideVenusDesc: String { TextLocalization.text(.guideVenusDesc) }
    public static var guideVenusEye: String { TextLocalization.text(.guideVenusEye) }
    public static var guideVenusBino: String { TextLocalization.text(.guideVenusBino) }
    public static var guideVenusScope: String { TextLocalization.text(.guideVenusScope) }
    public static var guideMarsDesc: String { TextLocalization.text(.guideMarsDesc) }
    public static var guideMarsEye: String { TextLocalization.text(.guideMarsEye) }
    public static var guideMarsBino: String { TextLocalization.text(.guideMarsBino) }
    public static var guideMarsScope: String { TextLocalization.text(.guideMarsScope) }
    public static var guideJupiterDesc: String { TextLocalization.text(.guideJupiterDesc) }
    public static var guideJupiterEye: String { TextLocalization.text(.guideJupiterEye) }
    public static var guideJupiterBino: String { TextLocalization.text(.guideJupiterBino) }
    public static var guideJupiterScope: String { TextLocalization.text(.guideJupiterScope) }
    public static var guideSaturnDesc: String { TextLocalization.text(.guideSaturnDesc) }
    public static var guideSaturnEye: String { TextLocalization.text(.guideSaturnEye) }
    public static var guideSaturnBino: String { TextLocalization.text(.guideSaturnBino) }
    public static var guideSaturnScope: String { TextLocalization.text(.guideSaturnScope) }
    public static var guideStarDesc: String { TextLocalization.text(.guideStarDesc) }
    public static var guideStarEye: String { TextLocalization.text(.guideStarEye) }
    public static var guideStarBino: String { TextLocalization.text(.guideStarBino) }
    public static var guideStarScope: String { TextLocalization.text(.guideStarScope) }
    public static var guideDeepDesc: String { TextLocalization.text(.guideDeepDesc) }
    public static var guideDeepEye: String { TextLocalization.text(.guideDeepEye) }
    public static var guideDeepBino: String { TextLocalization.text(.guideDeepBino) }
    public static var guideDeepScope: String { TextLocalization.text(.guideDeepScope) }
    public static var tabJournal: String { TextLocalization.text(.tabJournal) }
    public static var obReplay: String { TextLocalization.text(.obReplay) }
    public static var journalEmpty: String { TextLocalization.text(.journalEmpty) }
    public static var discLookUpTitle: String { TextLocalization.text(.discLookUpTitle) }
    public static var discLookUpBody: String { TextLocalization.text(.discLookUpBody) }
    public static var discDetails: String { TextLocalization.text(.discDetails) }
    public static var settingsSky: String { TextLocalization.text(.settingsSky) }
}

/// Isi "Yang akan kamu lihat" per benda (ADR-019). Hanya fakta umum yang
/// benar untuk pengamat biasa; tidak ada angka akurasi yang belum terukur.
public struct ObjectGuideContent: Equatable, Sendable {
    public let description: String
    public let nakedEye: String
    public let binoculars: String
    public let telescope: String

    public static func content(for object: CelestialObject) -> ObjectGuideContent {
        func c(_ d: LocalizedText, _ e: LocalizedText, _ b: LocalizedText, _ t: LocalizedText) -> ObjectGuideContent {
            ObjectGuideContent(description: TextLocalization.text(d), nakedEye: TextLocalization.text(e),
                               binoculars: TextLocalization.text(b), telescope: TextLocalization.text(t))
        }
        switch object.id {
        case "moon": return c(.guideMoonDesc, .guideMoonEye, .guideMoonBino, .guideMoonScope)
        case "mercury": return c(.guideMercuryDesc, .guideMercuryEye, .guideMercuryBino, .guideMercuryScope)
        case "venus": return c(.guideVenusDesc, .guideVenusEye, .guideVenusBino, .guideVenusScope)
        case "mars": return c(.guideMarsDesc, .guideMarsEye, .guideMarsBino, .guideMarsScope)
        case "jupiter": return c(.guideJupiterDesc, .guideJupiterEye, .guideJupiterBino, .guideJupiterScope)
        case "saturn": return c(.guideSaturnDesc, .guideSaturnEye, .guideSaturnBino, .guideSaturnScope)
        default:
            switch object.kind {
            case .deepSky: return c(.guideDeepDesc, .guideDeepEye, .guideDeepBino, .guideDeepScope)
            default: return c(.guideStarDesc, .guideStarEye, .guideStarBino, .guideStarScope)
            }
        }
    }
}

public extension LocalizedText {
    static let obDiscoverTitle = LocalizedText(key: "ob.discover.title", id: "Tunjuk untuk menemukan.")
    static let obDiscoverBody = LocalizedText(key: "ob.discover.body", id: "Tunjuk sesuatu di langit dengan Apple Watch. Point & Know membantu kamu tahu apa itu.")
    static let obContinue = LocalizedText(key: "ob.continue", id: "Lanjut")
    static let obHowItWorks = LocalizedText(key: "ob.howItWorks", id: "Cara kerja menunjuk dengan jam")
    static let obWorldTitle = LocalizedText(key: "ob.world.title", id: "Dari titik cahaya menjadi sebuah dunia.")
    static let obWorldBody = LocalizedText(key: "ob.world.body", id: "Jam mengubah gerakan menunjuk yang alami menjadi penemuan. Angkat pergelangan ke bintang, planet, atau Bulan.")
    static let obWorldTap = LocalizedText(key: "ob.world.tap", id: "Getaran halus")
    static let obWorldOffline = LocalizedText(key: "ob.world.offline", id: "Bekerja offline")
    static let obWorldSync = LocalizedText(key: "ob.world.sync", id: "Sinkron iPhone")
    static let obWorldSetup = LocalizedText(key: "ob.world.setup", id: "Siapkan Apple Watch")
    static let obWorldSkip = LocalizedText(key: "ob.world.skip", id: "Lanjut tanpa jam")
    static let obWatchTitle = LocalizedText(key: "ob.watch.title", id: "Jam kamu siap.")
    static let obWatchNotReady = LocalizedText(key: "ob.watch.notReady", id: "Jam belum tersambung.")
    static let obWatchBody = LocalizedText(key: "ob.watch.body", id: "Kami memakai sensor geraknya untuk memahami ke mana kamu menunjuk.")
    static let obWatchNotReadyBody = LocalizedText(key: "ob.watch.notReadyBody", id: "Pasang Point & Know di jam lewat app Watch di iPhone, lalu buka app-nya di jam.")
    static let obWatchMotion = LocalizedText(key: "ob.watch.motion", id: "Giroskop & Akselerometer")
    static let obWatchMotionDetail = LocalizedText(key: "ob.watch.motionDetail", id: "Gerak 6 sumbu")
    static let obWatchCompass = LocalizedText(key: "ob.watch.compass", id: "Kompas & arah tunjuk")
    static let obWatchCompassDetail = LocalizedText(key: "ob.watch.compassDetail", id: "Dihitung di jam")
    static let obChipWatch = LocalizedText(key: "ob.chip.watch", id: "Apple Watch")
    static let obChipConnected = LocalizedText(key: "ob.chip.connected", id: "Tersambung")
    static let obChipAppInstalled = LocalizedText(key: "ob.chip.appInstalled", id: "App terpasang")
    static let obChipNotPaired = LocalizedText(key: "ob.chip.notPaired", id: "Belum dipasangkan")
    static let obChipNotInstalled = LocalizedText(key: "ob.chip.notInstalled", id: "App belum terpasang")
    static let obOnDevice = LocalizedText(key: "ob.onDevice", id: "DIPROSES DI PERANGKAT")
    static let obLocationTitle = LocalizedText(key: "ob.location.title", id: "Langit bergantung pada tempatmu.")
    static let obLocationBody = LocalizedText(key: "ob.location.body", id: "Lokasimu membantu Point & Know menghitung bintang dan planet yang benar-benar ada di atas cakrawalamu.")
    static let obLocationPrivacy = LocalizedText(key: "ob.location.privacy", id: "Lokasi diproses di perangkat untuk menghitung langit setempat.")
    static let obLocationUse = LocalizedText(key: "ob.location.use", id: "Pakai Lokasi Saya")
    static let obNotNow = LocalizedText(key: "ob.notNow", id: "Nanti saja")
    static let obPointTitle = LocalizedText(key: "ob.point.title", id: "Tunjuk dengan wajar.")
    static let obPointBody = LocalizedText(key: "ob.point.body", id: "Lihat sesuatu di langit, lalu tunjuk dengan jari telunjuk. Biarkan pergelangan rileks.")
    static let obPointLeft = LocalizedText(key: "ob.point.left", id: "Pergelangan kiri")
    static let obPointRight = LocalizedText(key: "ob.point.right", id: "Pergelangan kanan")
    static let obPointWristNote = LocalizedText(key: "ob.point.wristNote", id: "Jam membaca pergelangan dari pengaturan Apple Watch.")
    static let obPointTry = LocalizedText(key: "ob.point.try", id: "Coba")
    static let obLookupTitle = LocalizedText(key: "ob.lookup.title", id: "Lihat ke atas.")
    static let obLookupBody = LocalizedText(key: "ob.lookup.body", id: "Ada yang membuatmu penasaran?")
    static let obLookupHint = LocalizedText(key: "ob.lookup.hint", id: "TUNJUK UNTUK MENGENALI")
    static let obReady = LocalizedText(key: "ob.ready", id: "SIAP")
    static let obLocked = LocalizedText(key: "ob.locked", id: "TERKUNCI")
    static let discFirst = LocalizedText(key: "disc.first", id: "PENEMUAN PERTAMA")
    static let discAgain = LocalizedText(key: "disc.again", id: "DIKONFIRMASI")
    static let discVisibleNow = LocalizedText(key: "disc.visibleNow", id: "Terlihat sekarang")
    static let discNotVisibleNow = LocalizedText(key: "disc.notVisibleNow", id: "Belum terlihat sekarang")
    static let discWhatYoullSee = LocalizedText(key: "disc.whatYoullSee", id: "Yang akan kamu lihat")
    static let discEye = LocalizedText(key: "disc.eye", id: "Mata telanjang")
    static let discBinoculars = LocalizedText(key: "disc.binoculars", id: "Binokuler")
    static let discTelescope = LocalizedText(key: "disc.telescope", id: "Teleskop")
    static let discSave = LocalizedText(key: "disc.save", id: "Simpan Pengamatan")
    static let discSaved = LocalizedText(key: "disc.saved", id: "Tersimpan")
    static let discExplore = LocalizedText(key: "disc.explore", id: "Jelajahi Langit")
    static let discJournal = LocalizedText(key: "disc.journal", id: "Pengamatan tersimpan")
    static let guideMoonDesc = LocalizedText(key: "guide.moon.desc", id: "Satu-satunya satelit alami Bumi, sekitar 384.000 km jauhnya.")
    static let guideMoonEye = LocalizedText(key: "guide.moon.eye", id: "Fase dan bercak gelap (maria)")
    static let guideMoonBino = LocalizedText(key: "guide.moon.bino", id: "Kawah besar di sepanjang batas terang-gelap")
    static let guideMoonScope = LocalizedText(key: "guide.moon.scope", id: "Ribuan kawah, pegunungan, dan alur")
    static let guideMercuryDesc = LocalizedText(key: "guide.mercury.desc", id: "Planet terdekat ke Matahari, selalu rendah di langit senja atau fajar.")
    static let guideMercuryEye = LocalizedText(key: "guide.mercury.eye", id: "Titik terang dekat cakrawala")
    static let guideMercuryBino = LocalizedText(key: "guide.mercury.bino", id: "Lebih mudah ditemukan di langit senja")
    static let guideMercuryScope = LocalizedText(key: "guide.mercury.scope", id: "Fase kecil seperti Bulan")
    static let guideVenusDesc = LocalizedText(key: "guide.venus.desc", id: "Planet paling terang di langit, diselimuti awan tebal.")
    static let guideVenusEye = LocalizedText(key: "guide.venus.eye", id: "Titik sangat terang yang tidak berkedip")
    static let guideVenusBino = LocalizedText(key: "guide.venus.bino", id: "Bentuk sabit atau cembung")
    static let guideVenusScope = LocalizedText(key: "guide.venus.scope", id: "Fase yang jelas, tanpa detail permukaan")
    static let guideMarsDesc = LocalizedText(key: "guide.mars.desc", id: "Planet merah, kira-kira separuh ukuran Bumi.")
    static let guideMarsEye = LocalizedText(key: "guide.mars.eye", id: "Titik oranye kemerahan")
    static let guideMarsBino = LocalizedText(key: "guide.mars.bino", id: "Warnanya lebih jelas")
    static let guideMarsScope = LocalizedText(key: "guide.mars.scope", id: "Tudung es kutub saat Mars dekat")
    static let guideJupiterDesc = LocalizedText(key: "guide.jupiter.desc", id: "Planet terbesar di Tata Surya, tampak sebagai titik terang yang tenang.")
    static let guideJupiterEye = LocalizedText(key: "guide.jupiter.eye", id: "Titik terang yang tenang")
    static let guideJupiterBino = LocalizedText(key: "guide.jupiter.bino", id: "Jupiter dan empat bulan Galileonya")
    static let guideJupiterScope = LocalizedText(key: "guide.jupiter.scope", id: "Pita awan dan Bintik Merah Besar")
    static let guideSaturnDesc = LocalizedText(key: "guide.saturn.desc", id: "Planet bercincin, hampir sepuluh kali lebih jauh dari Matahari dibanding Bumi.")
    static let guideSaturnEye = LocalizedText(key: "guide.saturn.eye", id: "Titik kekuningan yang tenang")
    static let guideSaturnBino = LocalizedText(key: "guide.saturn.bino", id: "Bentuk lonjong karena cincinnya")
    static let guideSaturnScope = LocalizedText(key: "guide.saturn.scope", id: "Cincin dan bulan Titan")
    static let guideStarDesc = LocalizedText(key: "guide.star.desc", id: "Sebuah bintang: matahari lain yang sangat jauh.")
    static let guideStarEye = LocalizedText(key: "guide.star.eye", id: "Titik yang berkelip")
    static let guideStarBino = LocalizedText(key: "guide.star.bino", id: "Warnanya lebih jelas")
    static let guideStarScope = LocalizedText(key: "guide.star.scope", id: "Tetap sebuah titik, karena terlalu jauh")
    static let guideDeepDesc = LocalizedText(key: "guide.deep.desc", id: "Objek langit dalam: gugus bintang, nebula, atau galaksi.")
    static let guideDeepEye = LocalizedText(key: "guide.deep.eye", id: "Bercak samar di langit gelap")
    static let guideDeepBino = LocalizedText(key: "guide.deep.bino", id: "Bentuknya mulai terlihat")
    static let guideDeepScope = LocalizedText(key: "guide.deep.scope", id: "Bintang-bintang atau struktur gas-debunya")
    static let tabJournal = LocalizedText(key: "tab.journal", id: "Jurnal")
    static let obReplay = LocalizedText(key: "ob.replay", id: "Tampilkan perkenalan lagi")
    static let journalEmpty = LocalizedText(key: "journal.empty", id: "Belum ada pengamatan. Simpan dari kartu Penemuan.")
    static let discLookUpTitle = LocalizedText(key: "disc.lookUpTitle", id: "Belum ada penemuan")
    static let discLookUpBody = LocalizedText(key: "disc.lookUpBody", id: "Tunjuk benda di langit dengan jam, lalu tekan \"Ya, itu dia\".")
    static let discDetails = LocalizedText(key: "disc.details", id: "Lihat detail")
    static let settingsSky = LocalizedText(key: "settings.sky", id: "Langit")

    static let designKeys: [LocalizedText] = [
        .obDiscoverTitle, .obDiscoverBody, .obContinue, .obHowItWorks, .obWorldTitle, .obWorldBody, .obWorldTap, .obWorldOffline, .obWorldSync, .obWorldSetup, .obWorldSkip, .obWatchTitle, .obWatchNotReady, .obWatchBody, .obWatchNotReadyBody, .obWatchMotion, .obWatchMotionDetail, .obWatchCompass, .obWatchCompassDetail, .obChipWatch, .obChipConnected, .obChipAppInstalled, .obChipNotPaired, .obChipNotInstalled, .obOnDevice, .obLocationTitle, .obLocationBody, .obLocationPrivacy, .obLocationUse, .obNotNow, .obPointTitle, .obPointBody, .obPointLeft, .obPointRight, .obPointWristNote, .obPointTry, .obLookupTitle, .obLookupBody, .obLookupHint, .obReady, .obLocked, .discFirst, .discAgain, .discVisibleNow, .discNotVisibleNow, .discWhatYoullSee, .discEye, .discBinoculars, .discTelescope, .discSave, .discSaved, .discExplore, .discJournal, .guideMoonDesc, .guideMoonEye, .guideMoonBino, .guideMoonScope, .guideMercuryDesc, .guideMercuryEye, .guideMercuryBino, .guideMercuryScope, .guideVenusDesc, .guideVenusEye, .guideVenusBino, .guideVenusScope, .guideMarsDesc, .guideMarsEye, .guideMarsBino, .guideMarsScope, .guideJupiterDesc, .guideJupiterEye, .guideJupiterBino, .guideJupiterScope, .guideSaturnDesc, .guideSaturnEye, .guideSaturnBino, .guideSaturnScope, .guideStarDesc, .guideStarEye, .guideStarBino, .guideStarScope, .guideDeepDesc, .guideDeepEye, .guideDeepBino, .guideDeepScope, .tabJournal, .obReplay, .journalEmpty, .discLookUpTitle, .discLookUpBody, .discDetails, .settingsSky,
    ]
}
