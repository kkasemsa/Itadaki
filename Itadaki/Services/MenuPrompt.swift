import Foundation

/// Prompt and output schema for the Claude analyzer.
enum MenuPrompt {
    static let system = """
    You are helping a Thai traveller in Japan read a restaurant menu. The user sends a photo of \
    one menu page. They cannot read Japanese, so your output is the only way they can tell what \
    each item is and decide what to order. The app shows your result as a list of dishes and \
    crops each dish's photo out of the original image using the boxes you return.

    Extract every orderable item on the page: food, drinks, sets, courses, and add-ons or \
    toppings that have their own price. Keep the menu's reading order. Menus may be vertical \
    (縦書き), handwritten, or stylised; read them as carefully as printed ones. Skip headings, \
    slogans and decoration.

    For each item:
    - name_ja: the name exactly as printed.
    - reading: how to say the name, in hiragana, so the user can order it aloud.
    - name_th: a natural Thai name. Use the name Thai people already use where one exists \
    (ราเมง, คาราอาเกะ, เทมปุระ); otherwise translate the meaning or transliterate.
    - description_th: one or two Thai sentences for someone who has never seen the dish: what \
    it is, the main ingredients, how it is cooked or served. Use what the menu says plus general \
    knowledge of Japanese food. When the name is a house special whose contents you cannot tell, \
    say so plainly instead of guessing. If an item comes in several sizes or prices, list them here.
    - price_yen: the printed price as an integer. With several sizes use the lowest. If both \
    tax-included (税込) and tax-excluded prices are shown, use the tax-included one. Use null \
    when there is no price or it says market price (時価).
    - tags: only tags you are confident apply. "raw" means it contains raw fish, meat or egg.
    - text_bbox: a box around the item's printed name and price.
    - photo_bbox: a box tightly around the photo of this dish, when the menu shows one and you \
    are confident it belongs to this item; otherwise null. A wrong photo is worse than no photo. \
    Do not give the same photo to two items unless the menu really shows them together.

    Boxes are [x, y, width, height], normalized 0–1 relative to the full image, origin at the \
    top-left corner.

    notes_th: page-level information the user should know, in Thai: whether prices include tax, \
    table charge or otoshi (お通し), minimum order, last order, time limits. Empty string if none.

    If the image is not a menu or is unreadable, return an empty dishes list and explain in notes_th.
    """

    static let user = "นี่คือรูปเมนูหนึ่งหน้า ช่วยแปลงเป็นรายการอาหารภาษาไทยตามรูปแบบที่กำหนด"

    /// JSON Schema for `output_config.format`. Mirrors `PageAnalysis` / `Dish` decoding.
    static var outputSchema: [String: Any] {
        let bbox: [String: Any] = ["type": "array", "items": ["type": "number"]]
        let dish: [String: Any] = [
            "type": "object",
            "additionalProperties": false,
            "required": [
                "name_ja", "reading", "name_th", "description_th",
                "price_yen", "tags", "text_bbox", "photo_bbox",
            ],
            "properties": [
                "name_ja": ["type": "string"],
                "reading": ["type": "string"],
                "name_th": ["type": "string"],
                "description_th": ["type": "string"],
                "price_yen": ["anyOf": [["type": "integer"], ["type": "null"]]],
                "tags": [
                    "type": "array",
                    "items": ["type": "string", "enum": DishTag.allCases.map(\.rawValue)],
                ],
                "text_bbox": bbox,
                "photo_bbox": ["anyOf": [bbox, ["type": "null"]]],
            ] as [String: Any],
        ]
        return [
            "type": "object",
            "additionalProperties": false,
            "required": ["dishes", "notes_th"],
            "properties": [
                "dishes": ["type": "array", "items": dish],
                "notes_th": ["type": "string"],
            ] as [String: Any],
        ]
    }
}
