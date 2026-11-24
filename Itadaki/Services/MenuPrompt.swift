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
    - section_ja / section_th: the menu heading the item is printed under (for example 刺身, \
    焼き物, お飲み物), exactly as printed, and its Thai translation. The app groups the list \
    under these headings so it mirrors the menu's layout. Give every item under the same heading \
    identical values. Use empty strings for both when the menu has no headings.
    - name_ja: the name exactly as printed.
    - reading: how to say the name, in hiragana, so the user can order it aloud.
    - name_th: a natural Thai name. Use the name Thai people already use where one exists \
    (ราเมง, คาราอาเกะ, เทมปุระ); otherwise translate the meaning or transliterate.
    - description_th: one or two Thai sentences for someone who has never seen the dish: what \
    it is, the main ingredients, how it is cooked or served. Use what the menu says plus general \
    knowledge of Japanese food. When the name is a house special whose contents you cannot tell, \
    say so plainly instead of guessing. If an item comes in several sizes or prices, list them here.
    - options: when one item lists several choices at the same price — fillings, flavours, \
    toppings, cuts, hot or cold — put each choice here with its printed name (name_ja) and a Thai \
    translation (name_th), and keep name_ja above to the item's own name (おにぎり, not the whole \
    list of fillings). The user orders by pointing at one choice, so every choice printed must \
    appear and be translated. Use an empty list when the item has no choices. Choices with their \
    own prices are separate items, not options.
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

    Sometimes you get two images instead: the whole page for context, then a zoomed strip of the \
    same page. The app has cut the page into overlapping strips because the text is small, and \
    reads each strip in a separate request. In that case extract only the items printed in the \
    strip, use the whole-page image to find the heading each item sits under, give boxes relative \
    to the strip, and keep notes_th to what is printed in the strip. An item cut off by the \
    strip's edge also appears whole in the neighbouring strip and the app merges the two, so \
    include it when you can still read its name and leave it out when you cannot.

    The user would rather see the items you can read than nothing. When part of the image is \
    blurred, cut off or illegible, return the items you can read with confidence and say in \
    notes_th which part you could not read. Never invent an item to fill a gap: a wrong dish is \
    worse than a missing one. If nothing is readable, or the image is not a menu, return an empty \
    dishes list and explain why in notes_th in one or two short sentences.
    """

    static let user = "นี่คือรูปเมนูหนึ่งหน้า ช่วยแปลงเป็นรายการอาหารภาษาไทยตามรูปแบบที่กำหนด"
    static let overviewLabel = "Image 1 — the whole menu page, for context only:"
    static let stripLabel = "Image 2 — the zoomed strip to extract items from:"
    static let userStrip = "ช่วยแปลงรายการอาหารในรูปที่ 2 เป็นภาษาไทยตามรูปแบบที่กำหนด"

    /// JSON Schema for `output_config.format`. Mirrors `PageAnalysis` / `Dish` decoding.
    static var outputSchema: [String: Any] {
        let bbox: [String: Any] = ["type": "array", "items": ["type": "number"]]
        let dish: [String: Any] = [
            "type": "object",
            "additionalProperties": false,
            "required": [
                "section_ja", "section_th", "name_ja", "reading", "name_th", "description_th",
                "options", "price_yen", "tags", "text_bbox", "photo_bbox",
            ],
            "properties": [
                "section_ja": ["type": "string"],
                "section_th": ["type": "string"],
                "name_ja": ["type": "string"],
                "reading": ["type": "string"],
                "name_th": ["type": "string"],
                "description_th": ["type": "string"],
                "options": [
                    "type": "array",
                    "items": [
                        "type": "object",
                        "additionalProperties": false,
                        "required": ["name_ja", "name_th"],
                        "properties": [
                            "name_ja": ["type": "string"],
                            "name_th": ["type": "string"],
                        ],
                    ] as [String: Any],
                ] as [String: Any],
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
