import Foundation

/// One record of a seismic station's ground motion as stations stream it and archives serve it: miniSEED 2, the
/// data-only form of SEED 2.4 (FDSN, https://www.fdsn.org/pdf/SEEDManual_V2.4.pdf), a 48-byte header, blockette
/// 1000, and samples compressed as Steim1 or Steim2 differences. Seismograph draws them (docs/seismograph.md).
struct SeismicRecord: Sendable, Equatable {
    /// NET.STA.LOC.CHA, as "NL.HGN.02.LHZ".
    var id: String
    /// The first sample's moment in seconds since 1970 (UTC), and the samples a second.
    var start: Double, rate: Double
    /// The ground's velocity in the station's counts.
    var samples: [Int32]
}

/// Reads miniSEED 2 records: big-endian, as every station and archive the research tried sends them; Steim1,
/// Steim2 or plain 32-bit integers. Checked against the research's reader, itself checked against 346 records'
/// own check values (docs/seismograph/research-method.md, §1).
enum MiniSEED {
    /// Every record in `data`, in the order they come; a record it can't read is skipped.
    static func records(_ data: Data) -> [SeismicRecord] {
        let b = [UInt8](data)
        func u16(_ i: Int) -> Int { Int(b[i]) << 8 | Int(b[i + 1]) }
        func i16(_ i: Int) -> Int { Int(Int16(bitPattern: UInt16(u16(i)))) }
        var out: [SeismicRecord] = [], p = 0
        while p + 64 <= b.count {
            var encoding = 11, length = 512, q = u16(p + 46)
            while q > 0, q < length, p + q + 7 < b.count { // the blockettes, for 1000's encoding and record length
                if u16(p + q) == 1000 { (encoding, length) = (Int(b[p + q + 4]), 1 << Int(b[p + q + 6])) }
                let next = u16(p + q + 2)
                q = next > q ? next : 0
            }
            defer { p += length }
            guard length >= 128, p + length <= b.count else { break }
            func text(_ from: Int, _ count: Int) -> String {
                String(decoding: b[(p + from)..<(p + from + count)], as: UTF8.self).trimmingCharacters(in: .whitespaces)
            }
            let count = u16(p + 30), factor = Double(i16(p + 32)), multiplier = Double(i16(p + 34)), offset = u16(p + 44)
            guard count > 0, factor != 0, multiplier != 0, offset >= 48, offset < length else { continue }
            let rate = (factor > 0 ? factor : -1 / factor) * (multiplier > 0 ? multiplier : -1 / multiplier)
            let start = Double(epochDays(year: u16(p + 20)) + u16(p + 22) - 1) * 86400 + Double(b[p + 24]) * 3600 + Double(b[p + 25]) * 60
                + Double(b[p + 26]) + Double(u16(p + 28)) / 10000
            let body = Array(b[(p + offset)..<(p + length)])
            let samples: [Int32]?
            switch encoding {
            case 10, 11: samples = steim(body, count: count, two: encoding == 11)
            case 3 where body.count >= count * 4: samples = (0..<count).map { i in Int32(bitPattern: UInt32(body[i * 4]) << 24 | UInt32(body[i * 4 + 1]) << 16 | UInt32(body[i * 4 + 2]) << 8 | UInt32(body[i * 4 + 3])) }
            default: samples = nil
            }
            guard let samples else { continue }
            out.append(SeismicRecord(id: [text(18, 2), text(8, 5), text(13, 2), text(15, 3)].joined(separator: "."), start: start, rate: rate, samples: samples))
        }
        return out
    }

    /// Days from 1 January 1970 to 1 January of `year`, by the Gregorian calendar.
    static func epochDays(year: Int) -> Int {
        let y = year - 1
        return 365 * (y - 1969) + (y / 4 - 492) - (y / 100 - 19) + (y / 400 - 4)
    }

    /// Steim1 or Steim2: frames of 16 big-endian words, the first a nibble of two bits for each of the other 15,
    /// saying how differences are packed in it. The first frame's words 1 and 2 hold the first and last samples.
    private static func steim(_ body: [UInt8], count: Int, two: Bool) -> [Int32]? {
        func word(_ i: Int) -> UInt32 { UInt32(body[i * 4]) << 24 | UInt32(body[i * 4 + 1]) << 16 | UInt32(body[i * 4 + 2]) << 8 | UInt32(body[i * 4 + 3]) }
        func signed(_ v: UInt32, _ shift: UInt32, _ bits: UInt32) -> Int32 {
            let m = UInt32(1) << (bits - 1), x = (v >> shift) & (bits == 32 ? ~0 : (UInt32(1) << bits) - 1)
            return Int32(bitPattern: (x ^ m) &- m)
        }
        var diffs: [Int32] = [], first: Int32?
        diffs.reserveCapacity(count)
        frames: for f in 0..<(body.count / 64) {
            let control = word(f * 16)
            for i in 1..<16 {
                let v = word(f * 16 + i), c = (control >> UInt32(30 - 2 * i)) & 3
                if f == 0, i == 1 { first = Int32(bitPattern: v); continue }
                if f == 0, i == 2 { continue }
                switch (c, two, v >> 30) {
                case (0, _, _): continue
                case (1, _, _): diffs += [24, 16, 8, 0].map { signed(v, $0, 8) }
                case (2, false, _): diffs += [signed(v, 16, 16), signed(v, 0, 16)]
                case (3, false, _): diffs.append(Int32(bitPattern: v))
                case (2, true, 1): diffs.append(signed(v, 0, 30))
                case (2, true, 2): diffs += [signed(v, 15, 15), signed(v, 0, 15)]
                case (2, true, 3): diffs += [20, 10, 0].map { signed(v, $0, 10) }
                case (3, true, 0): diffs += [24, 18, 12, 6, 0].map { signed(v, $0, 6) }
                case (3, true, 1): diffs += [25, 20, 15, 10, 5, 0].map { signed(v, $0, 5) }
                case (3, true, 2): diffs += [24, 20, 16, 12, 8, 4, 0].map { signed(v, $0, 4) }
                default: return nil
                }
            }
            if diffs.count >= count { break frames }
        }
        guard let first, diffs.count >= count else { return nil }
        var out = [Int32](repeating: first, count: count)
        for i in 1..<count { out[i] = out[i - 1] &+ diffs[i] }
        return out
    }
}

/// A station's ground motion, a sample a second, from `start` (whole seconds since 1970, UTC): the counts as they
/// came, a gap where nothing did. Seismograph's sheets are cut from it, filtered and scaled (`trace`).
struct Ground: Sendable {
    static let gap = Int32.min
    var start = 0, counts: [Int32] = []

    /// Lays a record's samples in, a gap left before it if it comes after what is held; a record at another rate
    /// than one a second is left out.
    // ponytail: 1 Hz (LHZ) only; Short period's 40 a second would want its own buffer, or decimating, if it's built
    mutating func add(_ record: SeismicRecord) {
        guard record.rate == 1, !record.samples.isEmpty else { return }
        let first = Int(record.start.rounded())
        if counts.isEmpty { start = first }
        if first < start {
            counts.insert(contentsOf: repeatElement(Self.gap, count: start - first), at: 0)
            start = first
        }
        let at = first - start, end = at + record.samples.count
        if end > counts.count { counts += repeatElement(Self.gap, count: end - counts.count) }
        counts.replaceSubrange(at..<end, with: record.samples)
    }

    /// Keeps the seconds from `from` on.
    mutating func trim(before from: Int) {
        guard from > start else { return }
        counts.removeFirst(min(from - start, counts.count))
        start = from
    }

    /// The moment just after the last sample held, in seconds since 1970.
    var end: Int { start + counts.count }

    /// The long-period band, 0.02 to 0.1 Hz (periods of 10 to 50 s), in which quakes from anywhere on Earth come
    /// through as trains of slow waves and the ocean's microseism doesn't fill the line (research-method.md, §3):
    /// a fourth-order Butterworth high-pass and low-pass, two biquads each (RBJ's cookbook, bilinear), run forward
    /// only, as a real instrument's filter does. After every gap, and at the start, each section begins at its own
    /// steady state for the first sample, so no step rings. In rows of the sheet: a row's spacing is 13 times the
    /// median minute RMS of the last day held, divided by `sensitivity`. NaN where there was a gap.
    func trace(sensitivity: Double) -> [Float] {
        typealias Section = (b: SIMD3<Double>, a: SIMD2<Double>, high: Bool)
        let sections: [Section] = [(0.02, true), (0.1, false)].flatMap { f, high in
            [0.5412, 1.3066].map { q -> Section in
                let w = 2 * Double.pi * f, c = cos(w), alpha = sin(w) / (2 * q), a0 = 1 + alpha
                let b = high ? SIMD3((1 + c) / 2, -(1 + c), (1 + c) / 2) : SIMD3((1 - c) / 2, 1 - c, (1 - c) / 2)
                return (b / a0, SIMD2(-2 * c / a0, (1 - alpha) / a0), high)
            }
        }
        var out = [Float](repeating: .nan, count: counts.count)
        var state = [SIMD4<Double>](repeating: .zero, count: sections.count) // x1, x2, y1, y2
        var restarted = true, quiet: [Double] = [], settled = 0, minute = 0.0, filled = 0
        for (i, count) in counts.enumerated() {
            guard count != Self.gap else { restarted = true; continue }
            var x = Double(count)
            if restarted { // a high-pass at rest on a constant input puts out nothing, and so does all after it
                for s in sections.indices { state[s] = sections[s].high ? SIMD4(x, x, 0, 0) : .zero }
                (restarted, settled) = (false, i + 3600)
            }
            for s in sections.indices {
                let (b, a, _) = sections[s], st = state[s]
                let y = b.x * x + b.y * st.x + b.z * st.y - a.x * st.z - a.y * st.w
                state[s] = SIMD4(x, st.x, y, st.z)
                x = y
            }
            out[i] = Float(x)
            // the noise, a minute at a time, once the filter has settled an hour after a start, over the last day
            if i >= settled, i >= counts.count - 86400 {
                minute += x * x
                filled += 1
                if filled == 60 { quiet.append((minute / 60).squareRoot()); (minute, filled) = (0, 0) }
            } else { (minute, filled) = (0, 0) }
        }
        quiet.sort()
        let median = quiet.isEmpty ? 1 : max(quiet[quiet.count / 2], 1e-9)
        let scale = Float(sensitivity / (13 * median))
        for i in out.indices { out[i] *= scale }
        return out
    }
}
