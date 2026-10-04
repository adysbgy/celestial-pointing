import Foundation
import CelestialEngine

/// Satu kedatangan kunci yang layak dirayakan.
///
/// Token-nya dipakai SwiftUI sebagai `.id()`, jadi animasi hanya diputar
/// sekali per kedatangan. `Int` yang **monoton** dipakai, bukan `Date()` atau
/// `UUID()`, karena keduanya membuat setiap render menghasilkan nilai baru —
/// dan itu justru membuat animasi diputar ulang terus-menerus, bukan sekali.
public struct LockArrival: Equatable, Sendable {

    /// Token unik untuk kedatangan ini. Nilainya selalu naik.
    public let token: Int
    /// Id katalog objek yang baru terkunci.
    public let objectID: String

    public init(token: Int, objectID: String) {
        self.token = token
        self.objectID = objectID
    }
}

/// Gerbang "kunci baru" — satu-satunya sumber keputusan **boleh atau tidak**
/// sebuah kejadian lock dirayakan di layar.
///
/// **Kenapa ini bukan sekadar `state == .lock`.** Widget animasi selalu punya
/// satu pertanyaan yang sama: apakah yang baru saja terjadi adalah **kabar
/// baru**, atau hanya keadaan yang sudah berlaku selama ini? Membandingkan
/// `state == .lock` menjawab "ya" untuk keduanya, dan itu gagal dengan dua
/// cara yang sama-sama terlihat benar di layar:
///
/// 1. **Berulang.** Pada jam sungguhan, `snapshot` ditulis ulang 20 kali per
///    detik. Selama terkunci, `state` tetap `.lock`, jadi sebuah animasi
///    bergantian akan berkedip terus-menerus selama pengguna masih menatap.
/// 2. **Sisa**, yang lebih buruk. Mesin keadaan sengaja mempertahankan
///    `intent` supaya panel tidak berkedip. Ketika pergelangan bergerak dan
///    keadaan kembali `pointing`, `intent` masih berisi objek berkeputusan
///    tinggi dari pandangan sebelumnya. Kalau "ada kunci" dibaca dari
///    `intent`, layar merayakan jawaban yang sudah tidak berlaku.
///
///    Itu kelas false confidence yang dilarang PRD, dalam bentuk paling
///    meyakinkan: animasi membuat pengguna lebih yakin, bukan lebih ragu.
///
/// **Kenapa `answeredObject`, bukan `bestObject`.** Kunci dirayakan bersama
/// **objek yang berlaku sekarang**. `answeredObject` adalah predikat yang sama
/// dengan yang dipakai pesan ke iPhone dan riwayat keyakinan, jadi satu
/// keputusan berlaku di ketiga tempat dan tidak bisa berbeda pendapat.
///
/// **Kenapa gerbang, bukan `onChange`.** Keadaan di app berubah lewat **enam**
/// tempat terpisah (sampel sensor, sensor hilang, alur dihentikan, kalibrasi
/// baru, ambang baru, lokasi baru) dan semuanya mengubah layar. Kalau
/// aturannya hidup di view sebagai `onChange`, tiap pemanggil harus
/// menyalinnya sendiri — dan itu persis cara aturan yang sama mulai berbeda
/// pendapat antar tempat. `PointingEngine` memanggil gerbang ini di **satu**
/// tempat, sehingga tidak ada jalur yang bisa melewatkannya.
public struct LockArrivalGate {

    /// Keadaan pada panggilan terakhir. `nil` = belum pernah melihat
    /// keadaan, jadi apa pun yang berikutnya benar-benar baru.
    private var previous: PointingState?
    /// Kedatangan yang masih berlaku — bertahan selama terkunci.
    private var current: LockArrival?
    private var counter = 0

    public init() {}

    /// Catat keadaan saat ini dan kembalikan kedatangan kunci yang **berlaku**.
    ///
    /// Nilai yang dikembalikan **lengket**: selama masih terkunci, hasilnya
    /// tetap kedatangan yang sama dengan token yang sama. Itu yang membuat
    /// animasi diputar sekali, bukan 20 kali per detik — `id(token)`-nya baru
    /// berubah saat ada kedatangan baru.
    ///
    /// - Returns: kedatangan yang sedang berlaku, atau `nil` bila tidak ada.
    @discardableResult
    public mutating func update(with snapshot: PointingSnapshot) -> LockArrival? {
        let wasLock = previous == .lock
        previous = snapshot.state

        if snapshot.state == .lock, !wasLock {
            // Tanpa objek yang berlaku sekarang tidak ada yang dirayakan:
            // `.lock` tanpa `intent` bisa muncul pada sampel pertama setelah
            // pemulihan sensor, dan merayakannya berarti merayakan benda
            // yang tidak ada.
            if let object = snapshot.answeredObject {
                counter += 1
                current = LockArrival(token: counter, objectID: object.id)
            }
        }

        // Keadaan sudah tidak terkunci: latch dilepas, supaya layar tidak
        // merayakan sesuatu yang sudah tidak berlaku.
        if snapshot.state != .lock {
            current = nil
        }
        return current
    }

    /// Lupakan keadaan yang pernah dilihat.
    ///
    /// Dipakai saat siklus hidup app dimulai ulang, ketika cuplikan lama sudah
    /// dibuang sehingga tidak ada lagi "sebelumnya" yang jujur untuk
    /// dibandingkan. Setelah ini, keadaan berikutnya diperlakukan sebagai
    /// baru — dan kalau keadaan itu sudah `.lock`, itu memang kedatangan
    /// baru bagi pengguna, yang memang baru saja membuka app.
    public mutating func reset() {
        previous = nil
        current = nil
    }
}