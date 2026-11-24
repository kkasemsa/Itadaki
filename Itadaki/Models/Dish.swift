import Foundation

/// A rectangle in normalized image coordinates (0–1, origin top-left).
struct NormalizedRect: Equatable, Hashable, Sendable {
    var x: Double
    var y: Double
    var width: Double
    var height: Double

    init(x: Double, y: Double, width: Double, height: Double) {
        self.x = x
        self.y = y
        self.width = width
        self.height = height
    }

    /// Builds a rect from the API's `[x, y, w, h]` array, clamped to the image.
    /// Returns nil when the array is malformed or the box is empty after clamping.
    init?(array: [Double]) {
        guard array.count == 4, array.allSatisfy({ $0.isFinite }) else { return nil }
        let minX = min(max(array[0], 0), 1)
        let minY = min(max(array[1], 0), 1)
        let maxX = min(max(array[0] + array[2], 0), 1)
        let maxY = min(max(array[1] + array[3], 0), 1)
        guard maxX > minX, maxY > minY else { return nil }
        self.init(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
    }
}

enum DishTag: String, CaseIterable, Sendable {
    case pork, beef, chicken, seafood, raw, spicy, alcohol, vegetarian

    var labelTH: String {
        switch self {
        case .pork: return "หมู"
        case .beef: return "เนื้อวัว"
        case .chicken: return "ไก่"
        case .seafood: return "ซีฟู้ด"
        case .raw: return "ของดิบ"
        case .spicy: return "เผ็ด"
        case .alcohol: return "แอลกอฮอล์"
        case .vegetarian: return "มังสวิรัติ"
        }
    }
}

/// One choice within a dish, such as a filling, flavour or size.
struct DishOption: Equatable, Hashable, Sendable, Codable {
    var nameJA: String
    var nameTH: String

    private enum CodingKeys: String, CodingKey {
        case nameJA = "name_ja"
        case nameTH = "name_th"
    }
}

struct Dish: Identifiable, Equatable, Sendable {
    let id: UUID
    var nameJA: String
    var reading: String
    var nameTH: String
    var descriptionTH: String
    var priceYen: Int?
    var tags: [DishTag]
    var textBBox: NormalizedRect?
    var photoBBox: NormalizedRect?
    /// Menu heading this dish is printed under, as printed and in Thai. Empty when none.
    var sectionJA: String
    var sectionTH: String
    /// Choices the menu lists for this dish (fillings, flavours…), each translated.
    var options: [DishOption]

    init(
        id: UUID = UUID(),
        nameJA: String,
        reading: String = "",
        nameTH: String,
        descriptionTH: String = "",
        priceYen: Int? = nil,
        tags: [DishTag] = [],
        textBBox: NormalizedRect? = nil,
        photoBBox: NormalizedRect? = nil,
        sectionJA: String = "",
        sectionTH: String = "",
        options: [DishOption] = []
    ) {
        self.id = id
        self.nameJA = nameJA
        self.reading = reading
        self.nameTH = nameTH
        self.descriptionTH = descriptionTH
        self.priceYen = priceYen
        self.tags = tags
        self.textBBox = textBBox
        self.photoBBox = photoBBox
        self.sectionJA = sectionJA
        self.sectionTH = sectionTH
        self.options = options
    }
}

extension Dish: Codable {
    private enum CodingKeys: String, CodingKey {
        /// Not part of the analyzer's output; written when a menu is saved to history
        /// so a reloaded dish keeps its identity.
        case id
        case nameJA = "name_ja"
        case reading
        case nameTH = "name_th"
        case descriptionTH = "description_th"
        case priceYen = "price_yen"
        case tags
        case textBBox = "text_bbox"
        case photoBBox = "photo_bbox"
        case sectionJA = "section_ja"
        case sectionTH = "section_th"
        case options
    }

    /// Names are required; everything else degrades gracefully so one sloppy field
    /// does not throw away a whole page.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let nameJA = try c.decode(String.self, forKey: .nameJA)
        let nameTH = try c.decode(String.self, forKey: .nameTH)
        guard !nameTH.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw DecodingError.dataCorruptedError(
                forKey: .nameTH, in: c, debugDescription: "name_th must not be empty")
        }

        var price: Int?
        if let value = try? c.decodeIfPresent(Int.self, forKey: .priceYen) {
            price = value
        } else if let value = try? c.decodeIfPresent(Double.self, forKey: .priceYen), value.isFinite {
            price = Int(value.rounded())
        }
        if let value = price, value < 0 { price = nil }

        let rawTags = (try? c.decodeIfPresent([String].self, forKey: .tags)) ?? []
        var tags: [DishTag] = []
        for raw in rawTags {
            if let tag = DishTag(rawValue: raw.lowercased()), !tags.contains(tag) { tags.append(tag) }
        }

        func bbox(_ key: CodingKeys) -> NormalizedRect? {
            guard let array = try? c.decodeIfPresent([Double].self, forKey: key) else { return nil }
            return NormalizedRect(array: array)
        }

        func text(_ key: CodingKeys) -> String {
            ((try? c.decodeIfPresent(String.self, forKey: key)) ?? "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
        }

        self.init(
            id: (try? c.decodeIfPresent(UUID.self, forKey: .id)) ?? UUID(),
            nameJA: nameJA,
            reading: (try? c.decodeIfPresent(String.self, forKey: .reading)) ?? "",
            nameTH: nameTH,
            descriptionTH: (try? c.decodeIfPresent(String.self, forKey: .descriptionTH)) ?? "",
            priceYen: price,
            tags: tags,
            textBBox: bbox(.textBBox),
            photoBBox: bbox(.photoBBox),
            sectionJA: text(.sectionJA),
            sectionTH: text(.sectionTH),
            options: ((try? c.decodeIfPresent([DishOption].self, forKey: .options)) ?? [])
                .filter { !$0.nameJA.isEmpty || !$0.nameTH.isEmpty }
        )
    }
}

extension Dish {
    /// Writes the same shape the analyzer produces, plus `id`.
    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(sectionJA, forKey: .sectionJA)
        try c.encode(sectionTH, forKey: .sectionTH)
        try c.encode(nameJA, forKey: .nameJA)
        try c.encode(reading, forKey: .reading)
        try c.encode(nameTH, forKey: .nameTH)
        try c.encode(descriptionTH, forKey: .descriptionTH)
        try c.encode(priceYen, forKey: .priceYen)
        try c.encode(tags.map(\.rawValue), forKey: .tags)
        try c.encode(textBBox?.array, forKey: .textBBox)
        try c.encode(photoBBox?.array, forKey: .photoBBox)
        try c.encode(options, forKey: .options)
    }
}

extension NormalizedRect {
    /// `[x, y, w, h]`, the form used in JSON.
    var array: [Double] { [x, y, width, height] }
}

/// The analyzer's result for one menu page.
struct PageAnalysis: Equatable, Sendable, Decodable {
    var dishes: [Dish]
    var notesTH: String

    init(dishes: [Dish], notesTH: String = "") {
        self.dishes = dishes
        self.notesTH = notesTH
    }

    private enum CodingKeys: String, CodingKey {
        case dishes
        case notesTH = "notes_th"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        dishes = try c.decode([Dish].self, forKey: .dishes)
        notesTH = ((try? c.decodeIfPresent(String.self, forKey: .notesTH)) ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
