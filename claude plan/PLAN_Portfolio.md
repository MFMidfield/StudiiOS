# PLAN — Portfolio System (images + date range + grid)

Target: Student OS / PrototypeApp
Repo: `~/Documents/MyTask/PrototypeApp`
Written for: Sonnet (implementation)
Language rule: **all UI strings in Thai**, code comments in English.

---

## 0. Read this first

- Read `claude plan/PROJECT_MAP.md` before touching code.
- Deployment target is **iOS 26.5**. No `if #available` back-compat needed.
- **No external dependencies.** Do not add SPM packages.
- All colors / spacing / radius must come from `Theme` (`Theme.Colors.*`, `Theme.Spacing.*`, `Theme.Radius.*`). Never hardcode.
- New files are picked up automatically (file-system-synchronized groups). **Do not edit `.pbxproj`.**
- You cannot compile. Never claim "build passed". End every code delivery with the checked / not-checked / please-Few block.

---

## 1. What we are building

Current state (`Features/Portfolio/PortfolioView.swift`, 89 lines):
- Grouped `List` by category, text only, no images.
- Add sheet has: title, category, single date, detail.

Target state:
1. **Portfolio page** = 2-column card **grid**, each card shows a cover image preview.
2. **Add sheet** gains: image attachments (photo library / file / camera / **document scan**), image preview strip, start date, end date, detail.
3. **Detail page** for one item: full image gallery + all fields, editable, deletable.

---

## 2. Decisions already made (do not re-ask)

| Question | Decision |
|---|---|
| Grid vs list | **2-column card grid** |
| Images per item | **Multiple.** First image = cover |
| Date fields | **Rename `date` → `startDate`, add `endDate: Date?`** (breaking schema change, accepted) |
| Scanner | **VisionKit `VNDocumentCameraViewController`** (system UI, auto-shutter, auto-crop) |

⚠️ Because of the rename, **existing portfolio data will be lost**. Tell Few explicitly: *"ต้องลบแอปออกจากเครื่อง/simulator ก่อน แล้วติดตั้งใหม่ ไม่งั้นแอปจะ crash ตอนเปิด"*

---

## 3. Data model

### 3.1 `Core/Models/PortfolioItem.swift` — modify

```swift
@Model
final class PortfolioItem {
    var title: String
    var detail: String
    var categoryRaw: String
    var startDate: Date          // renamed from `date`
    var endDate: Date?           // nil = single-day activity

    @Relationship(deleteRule: .cascade, inverse: \PortfolioImage.item)
    var images: [PortfolioImage] = []

    var category: PortfolioCategory { get/set — keep as is }

    /// First image by sortOrder. Used as the grid cover.
    var coverImage: PortfolioImage? {
        images.sorted { $0.sortOrder < $1.sortOrder }.first
    }

    /// "12 ส.ค. 2568" or "12 – 15 ส.ค. 2568"
    var dateRangeText: String { ... use Date+Thai.swift ... }

    init(title:detail:category:startDate:endDate:)
}
```

Keep `PortfolioCategory` enum exactly as it is (5 cases, Thai labels, SF Symbol icons). Do not change it.

### 3.2 `Core/Models/PortfolioImage.swift` — NEW file

Images are **not** stored in SwiftData. Only the filename is stored; bytes go to the Documents directory. Follow the existing precedent in `Core/Profile/StudentProfileStore.swift`.

```swift
@Model
final class PortfolioImage {
    var filename: String     // e.g. "portfolio_<uuid>.jpg"
    var sortOrder: Int
    var createdAt: Date
    var item: PortfolioItem?

    init(filename: String, sortOrder: Int)
}
```

### 3.3 Register the model — REQUIRED, 2 places

1. `App/PrototypeAppApp.swift` → add `PortfolioImage.self` to the `Schema([...])` array.
   **Forgetting this = instant crash on launch** (there is a `fatalError`).
2. `Features/Settings/SettingsView.swift` → `resetAllData()` → delete `PortfolioImage` too, **and** delete the image files from disk (see 4.2 `deleteAll()`).

---

## 4. Image storage

### 4.1 `Core/Portfolio/PortfolioImageStore.swift` — NEW file

A small file-system helper. No SwiftData inside it.

```swift
enum PortfolioImageStore {
    static var directory: URL      // Documents/PortfolioImages (create if missing)

    /// Compress to JPEG 0.85, downscale so max side <= 2000px, write, return filename.
    static func save(_ image: UIImage) throws -> String

    /// Load full-size image. Return nil if the file is gone.
    static func load(_ filename: String) -> UIImage?

    /// Load a small version for grid cells. Use CGImageSourceCreateThumbnailAtIndex
    /// with kCGImageSourceThumbnailMaxPixelSize = 400. Do NOT decode the full image
    /// for thumbnails — the grid will stutter.
    static func loadThumbnail(_ filename: String, maxPixel: CGFloat = 400) -> UIImage?

    static func delete(_ filename: String)
    static func deleteAll()        // used by resetAllData()
}
```

Rules:
- Downscale before writing. A raw 12MP photo per item will blow up app size.
- `save` throws; the sheet shows a Thai error alert on failure, never fails silently.
- Deleting a `PortfolioItem` must delete its files from disk too (cascade only removes the SwiftData rows).

### 4.2 Thumbnail caching

Add a tiny in-memory cache inside `PortfolioImageStore`:

```swift
private static let cache = NSCache<NSString, UIImage>()
```

`loadThumbnail` checks the cache first. Clear the entry in `delete`.

---

## 5. Image input — 4 sources

The add/edit sheet has one **"เพิ่มรูป"** button that opens a `.confirmationDialog` with 4 options:

| Thai label | Mechanism |
|---|---|
| สแกนเอกสาร | `VNDocumentCameraViewController` (VisionKit) |
| ถ่ายรูป | `UIImagePickerController` with `sourceType = .camera` |
| เลือกจากคลังรูป | `PhotosPicker` (PhotosUI), `selectionLimit = 0` (unlimited) |
| เลือกจากไฟล์ | `.fileImporter` with `[.image, .pdf]` |

### 5.1 `Core/Portfolio/DocumentScannerView.swift` — NEW file

This is the "Apple Notes scan" behaviour Few asked for. VisionKit already does auto-edge-detection, auto-shutter, and perspective correction. Do not build a custom camera.

```swift
struct DocumentScannerView: UIViewControllerRepresentable {
    let onScanned: ([UIImage]) -> Void     // one scan session can return many pages
    let onCancel: () -> Void

    // makeUIViewController -> VNDocumentCameraViewController
    // Coordinator: VNDocumentCameraViewControllerDelegate
    //   didFinishWith scan: loop scan.pageCount, collect scan.imageOfPage(at:)
    //   didCancelWith / didFailWithError -> onCancel
}
```

Model the wrapper on the existing `Features/Onboarding/ProfileImagePicker.swift`. Same shape, same coordinator pattern.

⚠️ VisionKit does **not** work in the simulator (no camera). Guard with `VNDocumentCameraViewController.isSupported` and, on simulator, show a Thai alert: *"สแกนเอกสารใช้ได้เฉพาะบนเครื่องจริง"*. Same for `.camera` source type — check `UIImagePickerController.isSourceTypeAvailable(.camera)`.

### 5.2 Camera / photo picker

Reuse `ProfileImagePicker` for camera, but pass `allowsEditing: false` (we don't want the square crop for certificates).

### 5.3 PDF from `.fileImporter`

If the picked file is a PDF, render page 1 with PDFKit into a `UIImage` and store that. Only page 1 — keep it simple.

### 5.4 Info.plist permission strings — REQUIRED

The project has no camera keys yet. Add to the target's Info settings:

- `NSCameraUsageDescription` = "ใช้กล้องเพื่อถ่ายและสแกนรูปผลงานของคุณ"
- `NSPhotoLibraryUsageDescription` = "ใช้เลือกรูปผลงานจากคลังรูปภาพ"

Without these the app **crashes** the moment the camera opens. If you cannot set these from code, stop and tell Few to add them in Xcode → target → Info tab, and give him the exact key/value pairs.

---

## 6. Screens

### 6.1 `PortfolioView` — rewrite the body

```
NavigationStack
└── ScrollView
    └── LazyVGrid(columns: 2, spacing: Theme.Spacing.md)
        └── PortfolioCard(item)  → NavigationLink → PortfolioDetailView
```

- Keep the existing category filter concept, but move it to a **horizontal scrolling chip row** pinned above the grid: `[ทั้งหมด] [เกียรติบัตร] [กิจกรรม] [จิตอาสา] [การแข่งขัน] [โปรเจกต์]`. Selected chip uses `Theme.Colors.primary`; unselected uses `Theme.Colors.cardBackground` with a `Theme.Colors.separator` border.
- Sort: `startDate` descending.
- Empty state: keep `ContentUnavailableView("ยังไม่มีผลงาน", systemImage: "folder")` with a description line *"กดปุ่ม + เพื่อเพิ่มผลงานชิ้นแรก"*.
- Toolbar `+` button opens `PortfolioItemSheet(mode: .create)`.

### 6.2 `PortfolioCard` — NEW, put in `Features/Portfolio/PortfolioCard.swift`

```
┌───────────────────┐
│                   │  cover image, aspect 4:3, .fill + .clipped
│   [cover image]   │  if no image: Theme.Colors.background +
│                   │  category icon centered, Theme.Colors.textSecondary
├───────────────────┤
│ ชื่อกิจกรรม        │  2 lines max, .medium, textPrimary
│ 12 – 15 ส.ค. 2568 │  caption, textSecondary
│ [เกียรติบัตร]      │  small category pill, category color
└───────────────────┘
```

- Wrap in `CardContainer` if its padding allows an edge-to-edge image at the top; if it doesn't, build the card with `Theme.Radius.card` + `Theme.Colors.cardBackground` + the same shadow `CardContainer` uses. **Read `CardContainer` first** before deciding.
- Load the cover with `loadThumbnail`, in `.task {}`, into `@State private var thumb: UIImage?`. Never call `load()` (full size) here.
- If the item has more than 1 image, show a small badge in the top-right of the image: photo icon + count.

### 6.3 `PortfolioDetailView` — NEW file `Features/Portfolio/PortfolioDetailView.swift`

```
ScrollView
├── TabView(.page style), height ~260 — full image gallery, swipeable
│   (hidden entirely if images.isEmpty)
├── title (title2, bold)
├── category pill + date range text
└── detail text (if not empty)
```

Toolbar: **แก้ไข** → opens `PortfolioItemSheet(mode: .edit(item))`.
Bottom: destructive **ลบผลงาน** button → confirmation alert → delete SwiftData rows **and** the image files, then `dismiss()`.

### 6.4 `PortfolioItemSheet` — replace `NewPortfolioItemSheet`

New file `Features/Portfolio/PortfolioItemSheet.swift`. One sheet handles both create and edit:

```swift
enum Mode { case create, edit(PortfolioItem) }
```

Form sections, in this order:

1. **รูปผลงาน**
   - Horizontal `ScrollView` of 80×80 thumbnails, rounded `Theme.Radius.control`.
   - Each thumbnail has an `xmark.circle.fill` overlay in the corner to remove it.
   - Last cell is a dashed-border **"+ เพิ่มรูป"** button → the 4-source `.confirmationDialog`.
   - Long-press-to-reorder is **out of scope**. Order = order added.
2. **ชื่อกิจกรรม** — `TextField`, required.
3. **หมวดหมู่** — `Picker`, existing 5 categories.
4. **วันที่เริ่ม** — `DatePicker`, `.date` only.
5. **วันที่สิ้นสุด** — a `Toggle("กิจกรรมหลายวัน")`; when on, show a second `DatePicker`. When off, `endDate = nil`.
   - Validation: if `endDate < startDate`, disable บันทึก and show *"วันที่สิ้นสุดต้องอยู่หลังวันที่เริ่ม"* in red under the field.
6. **รายละเอียด** — `TextField(axis: .vertical)`, `lineLimit(3...8)`.

Toolbar: ยกเลิก / บันทึก. บันทึก is disabled while `title` is empty or the date range is invalid.

**Important — staged images:** while the sheet is open, newly picked images are held in a local `@State var pendingImages: [UIImage]` plus `@State var existingImages: [PortfolioImage]`. Only on **บันทึก** do you write files to disk and insert `PortfolioImage` rows. On **ยกเลิก**, discard `pendingImages` and write nothing. This prevents orphan files when the user backs out.

In edit mode, images the user removed must be deleted from disk on save, not before.

---

## 7. Files touched — summary

**New**
```
Core/Models/PortfolioImage.swift
Core/Portfolio/PortfolioImageStore.swift
Core/Portfolio/DocumentScannerView.swift
Features/Portfolio/PortfolioCard.swift
Features/Portfolio/PortfolioDetailView.swift
Features/Portfolio/PortfolioItemSheet.swift
```

**Modified**
```
Core/Models/PortfolioItem.swift        — startDate/endDate/images/coverImage/dateRangeText
Features/Portfolio/PortfolioView.swift — grid + filter chips, remove NewPortfolioItemSheet
App/PrototypeAppApp.swift              — add PortfolioImage.self to Schema
Features/Settings/SettingsView.swift   — resetAllData() deletes rows + files
Info.plist / target Info settings      — NSCameraUsageDescription, NSPhotoLibraryUsageDescription
claude plan/PROJECT_MAP.md             — update file tree, models table, notes
```

**Check before you edit:** `grep -rn "PortfolioItem" --include=*.swift .` — anything referencing `.date` (Dashboard widget? QuickAddSheet?) must be updated in the same pass. Report to Few which files came back.

---

## 8. Build order (one testable step at a time)

Do **not** deliver all of this in one drop. Stop after each step, hand it to Few, wait for a green build.

| Step | Content | Few checks by |
|---|---|---|
| 1 | Model changes + `PortfolioImage` + Schema + `resetAllData` + `PortfolioImageStore` (no UI yet). Fix `PortfolioView` to compile against `startDate`. | Delete app → reinstall → app opens without crashing, Portfolio list still shows text items |
| 2 | `PortfolioItemSheet` with photo-library picker only + staged save. Detail/grid not yet. | + → add title, dates, pick 2 photos → save → no crash |
| 3 | `PortfolioCard` + grid + filter chips in `PortfolioView` | Portfolio page shows 2-column cards with real image previews |
| 4 | `PortfolioDetailView` + edit + delete (rows and files) | Tap card → gallery → edit → delete works |
| 5 | `DocumentScannerView` + camera + fileImporter + Info.plist keys | **On a real device:** scan a certificate, image auto-crops and appears |

Step 5 needs a physical iPhone. Steps 1–4 work in the simulator.

---

## 9. Risks

| Risk | Mitigation |
|---|---|
| Schema rename crashes on launch | Warn Few to delete the app before installing. State this in the very first message of step 1. |
| Missing Info.plist keys → crash at camera open | Step 5 is blocked until Few confirms the keys are in the target |
| VisionKit unavailable in simulator | Guard with `isSupported`, show a Thai alert instead of a dead button |
| Grid stutters with many photos | `loadThumbnail` + `NSCache` only; never decode full images in cells |
| Orphan image files | Staged save; delete-on-save; cascade delete + explicit file delete |
| SwiftUI "unable to type-check in reasonable time" | `PortfolioItemSheet` has 6 sections — split each into its own `private var`/small View from the start |

---

## 10. Out of scope (do not build)

- Reordering images by drag
- Exporting portfolio as a PDF
- OCR of the scanned certificate text (a separate feature; `Core/OCR` already exists but is for schedule/grade reports)
- iCloud sync
- Pro gating — Portfolio stays a free feature

---

## 11. Definition of done

Few opens Portfolio and sees a 2-column grid of cards, each with a real photo. He taps +, fills in name / start date / end date / detail, taps เพิ่มรูป → สแกนเอกสาร, points the phone at a certificate, it auto-captures and auto-crops, the thumbnail appears in the strip, he saves, and the new card shows up in the grid with that image as the cover. Tapping the card opens a swipeable gallery.
