# Itadaki — Japanese menu → Thai (personal iOS/iPadOS app)

Working name: **Itadaki** (いただき). Personal use only, not for the App Store.

## What it does
1. User photographs a Japanese menu (camera) or picks one or more photos (library).
2. App extracts every dish: Japanese name, reading, Thai name, short Thai description, price.
3. If the menu has a photo of the dish, crop it from the original image and show it next to the Thai name.
4. Results are saved so the user can reopen a menu later, offline.

## Platform & stack
- SwiftUI, iOS/iPadOS 18+, iPhone + iPad (universal).
- Project generated with **XcodeGen** (`project.yml`). Never hand-edit `.pbxproj`.
- Persistence: SwiftData.
- No third-party dependencies unless clearly needed; ask first.
- UI language: Thai. Code, comments, identifiers: English.

## Architecture
```
App/            App entry, root navigation
Features/
  Capture/      Camera + PhotosPicker, multi-page capture
  Scan/         Calls MenuAnalyzer, progress UI, error states
  Menu/         Dish list (iPhone) / split view with original image (iPad)
  History/      Saved menus
  Settings/     API key, model, yen→baht rate
Services/
  MenuAnalyzer  protocol: analyze(requests) async throws -> [PageAnalysis]
  ClaudeMenuAnalyzer   online, primary
  OnDeviceMenuAnalyzer offline fallback (Phase 3)
  ImageCropper  crop dish photos from normalized bounding boxes
  TilePlan      split a page into overlapping strips, merge strip results
  KeychainStore
Models/         Dish (plain Codable struct); SavedMenu, SavedPage (SwiftData)
```

## Primary analyzer: Claude API (vision)
- Endpoint: `POST https://api.anthropic.com/v1/messages`, headers `x-api-key`, `anthropic-version: 2023-06-01`.
- Default model `claude-sonnet-5-5`; Settings offers Haiku 5.5, Sonnet 5.5, Opus 5.5, Fable 5.2 or a typed model id, and a thinking level (low / medium / high, default low).
- Send each page as base64 JPEG (resize long edge ≈ 1568 px, quality 0.8).
- Small text: a page is cut into 1–3 overlapping strips across its long edge (Settings, default 2). Each strip is sent in its own request together with the whole page for context; results are mapped back to page coordinates and items seen twice in an overlap are merged.
- A read that finds nothing is retried once, one thinking level up. Photos under 900 px on the long edge are flagged before sending.
- Partly illegible pages return the items that can be read, with a note about the rest; nothing is guessed.
- Ask for **JSON only**, matching this schema per page:

```json
{
  "dishes": [
    {
      "section_ja": "定食",
      "section_th": "ชุดอาหาร",
      "name_ja": "唐揚げ定食",
      "reading": "からあげていしょく",
      "name_th": "ชุดไก่ทอดคาราอาเกะ",
      "description_th": "ไก่ทอดสไตล์ญี่ปุ่น เสิร์ฟพร้อมข้าว ซุปมิโซะ และผักดอง",
      "price_yen": 980,
      "tags": ["pork|beef|chicken|seafood|raw|spicy|alcohol|vegetarian"],
      "text_bbox": [x, y, w, h],
      "photo_bbox": [x, y, w, h] | null
    }
  ],
  "notes_th": "เช่น ราคารวมภาษีแล้ว / ชาร์จที่นั่ง"
}
```
- Bounding boxes are normalized 0–1, origin top-left, relative to the image sent.
- Validate with `Codable`; on parse failure retry once with the error message, then show an error.
- API key: entered in Settings, stored in Keychain. Never hardcode, never log, never commit.

## UI
- **Dish list:** cards grouped under the section headings printed on the menu (Thai + Japanese), in menu order, with a chip bar to jump between headings. Dishes appear as each strip finishes.
- **Order:** each card has a quantity control; a bottom bar opens the order summary — picked dishes in very large Japanese with quantities and the total in ¥ and ≈ ฿ — to show staff.
- **History:** every scan that finds dishes is saved automatically (page photos, dishes, notes) and listed newest first; a saved menu opens offline with the same list, detail and order screens. Menus can be renamed and deleted.
- **Several pages:** pick up to 8 photos at once, or photograph pages one after another into a tray before reading. Results are shown per page, with a thumbnail strip to switch pages; the order spans all pages.
- **Zoom:** in the detail sheet, tapping the dish photo or the menu page opens it full screen with pinch-to-zoom; the page opens zoomed in on the dish's box.
- **Unreadable page:** short explanation, photo tips and a retake button.
- **Dish row:** cropped photo (if any) on the left; Thai name (large), Japanese name (large enough to point at for staff), reading (small), price ¥ (and ≈ ฿ if rate set, entered as baht per 100 yen), tag chips. The photo column is hidden when the page has no dish photos.
- **Tap a dish:** detail sheet with the Japanese name very large (to show staff), larger photo and description. On the original page, highlight its `text_bbox`.
- **iPad:** `NavigationSplitView` with the original page (zoomable, boxes overlaid) on one side and the dish list on the other; selecting either side highlights the other.
- Dishes without photos still appear, with a neutral placeholder.
- Show a clear loading state per page; pages are processed in parallel (max 3).

## Phases
1. **MVP:** XcodeGen project, capture/pick one photo, ClaudeMenuAnalyzer, dish list with cropped photos, Settings with Keychain key. Runs on a real iPhone.
2. Multi-page menus, SwiftData history, iPad split view with bbox overlay, yen→baht.
3. Offline fallback: Vision `VNRecognizeTextRequest` (`ja-JP`) + Apple Translation framework (ja → th), text only, no photo matching.
4. Polish: crop padding/refinement, share a menu as an image, haptics, dark mode check.

## Known risks
- Claude's bounding boxes may be loose. Add ~4% padding and let the user nudge or hide a crop. Test on real menus early.
- Handwritten or vertical (縦書き) menus: check both analyzers on them.
- Free Apple ID signing expires every 7 days; just rebuild.

## Working rules for Claude Code
- Build after each change: `xcodegen generate && xcodebuild -scheme Itadaki -destination 'platform=iOS Simulator,name=iPhone 16' build`. Fix all errors before moving on.
- Keep `MenuAnalyzer` behind the protocol so both analyzers are swappable, and add a mock analyzer with fixture JSON for SwiftUI previews and tests.
- Unit tests: JSON decoding, bbox → crop rect math, price formatting.
- Finish one phase at a time; summarise what changed and what to test on device.
