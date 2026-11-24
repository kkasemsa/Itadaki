import Foundation

/// Returns fixture data without touching the network. Used by SwiftUI previews,
/// unit tests, and the "sample mode" switch in Settings.
struct MockMenuAnalyzer: MenuAnalyzer {
    var delay: Duration = .zero

    func analyze(_ requests: [PageRequest]) async throws -> [PageAnalysis] {
        let images = requests
        if delay > .zero { try await Task.sleep(for: delay) }
        let page = try Self.fixturePage()
        return images.map { _ in page }
    }

    static func fixturePage() throws -> PageAnalysis {
        try JSONDecoder().decode(PageAnalysis.self, from: Data(fixtureJSON.utf8))
    }

    /// Same shape the Claude analyzer is asked to produce.
    static let fixtureJSON = """
    {
      "dishes": [
        {
          "section_ja": "定食",
          "section_th": "ชุดอาหาร",
          "name_ja": "唐揚げ定食",
          "reading": "からあげていしょく",
          "name_th": "ชุดไก่ทอดคาราอาเกะ",
          "description_th": "ไก่ทอดสไตล์ญี่ปุ่น เสิร์ฟพร้อมข้าว ซุปมิโซะ และผักดอง",
          "options": [],
          "price_yen": 980,
          "tags": ["chicken"],
          "text_bbox": [0.08, 0.12, 0.40, 0.06],
          "photo_bbox": [0.55, 0.08, 0.35, 0.22]
        },
        {
          "section_ja": "刺身",
          "section_th": "ซาชิมิ",
          "name_ja": "刺身盛り合わせ",
          "reading": "さしみもりあわせ",
          "name_th": "ซาชิมิรวม",
          "description_th": "ปลาดิบหลายชนิดหั่นชิ้น จิ้มโชยุกับวาซาบิ ชนิดปลาเปลี่ยนตามวัน",
          "options": [],
          "price_yen": 1580,
          "tags": ["seafood", "raw"],
          "text_bbox": [0.08, 0.36, 0.40, 0.06],
          "photo_bbox": [0.55, 0.33, 0.35, 0.22]
        },
        {
          "section_ja": "一品料理",
          "section_th": "อาหารตามสั่ง",
          "name_ja": "豚キムチ炒め",
          "reading": "ぶたきむちいため",
          "name_th": "หมูผัดกิมจิ",
          "description_th": "หมูสามชั้นผัดกับกิมจิ รสเผ็ดอมเปรี้ยว กินกับข้าวหรือเป็นกับแกล้ม",
          "options": [],
          "price_yen": 780,
          "tags": ["pork", "spicy"],
          "text_bbox": [0.08, 0.60, 0.40, 0.06],
          "photo_bbox": null
        },
        {
          "section_ja": "お飲み物",
          "section_th": "เครื่องดื่ม",
          "name_ja": "生ビール",
          "reading": "なまびーる",
          "name_th": "เบียร์สด",
          "description_th": "เบียร์สดแก้วกลาง เลือกยี่ห้อได้",
          "options": [{"name_ja": "アサヒ", "name_th": "อาซาฮี"}, {"name_ja": "キリン", "name_th": "คิริน"}, {"name_ja": "サッポロ", "name_th": "ซัปโปโร"}],
          "price_yen": 550,
          "tags": ["alcohol"],
          "text_bbox": [0.08, 0.74, 0.40, 0.06],
          "photo_bbox": null
        },
        {
          "section_ja": "",
          "section_th": "",
          "name_ja": "本日のおすすめ",
          "reading": "ほんじつのおすすめ",
          "name_th": "เมนูแนะนำประจำวัน",
          "description_th": "เมนูพิเศษของร้านที่เปลี่ยนทุกวัน ต้องถามพนักงานว่าวันนี้เป็นอะไร",
          "options": [],
          "price_yen": null,
          "tags": [],
          "text_bbox": [0.08, 0.86, 0.40, 0.06],
          "photo_bbox": null
        }
      ],
      "notes_th": "ราคารวมภาษีแล้ว มีค่าที่นั่ง (โอโทชิ) คนละ 330 เยน"
    }
    """
}
