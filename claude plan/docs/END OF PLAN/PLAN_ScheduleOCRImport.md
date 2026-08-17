# PLAN — Schedule OCR Auto-Fill (ตารางเรียนอัตโนมัติ)

> Turn the existing `ScheduleOCRParser` output into real `ScheduleEntry` rows through a
> user-reviewed import sheet. Read **§0 first, always** — every phase depends on it.
> Then read only the phase you are working on, plus §Z when the phase says so.
>
> Written 2026-08-08 · target: `~/Documents/MyTask/PrototypeApp`
> Prerequisite: PLAN_OCR_Round3 phase A is built and working (confirmed by Few).

---

## §0 · CONTRACT — read this, never re-derive it

### 0.1 What the user does

```
Schedule tab → [+] → "เพิ่มคาบเรียน" sheet
   └ top row (add mode ONLY): "ถ่ายตารางสอน"
        └ alert: "การอ่านตารางจากรูปอาจอ่านผิด โดยเฉพาะรหัสวิชาและเวลา
                  กรุณาตรวจทุกคาบก่อนบันทึก"   [ยกเลิก] [เข้าใจแล้ว]
             └ confirmationDialog: [ถ่ายรูป] [เลือกจากคลังภาพ] [ยกเลิก]
                  └ UIImagePickerController → UIImage
                       └ ScheduleOCRParser.parseScheduleDetailed
                            └ ScheduleImportBuilder → [ImportedPeriod]
                                 └ ScheduleImportReviewSheet (.large sheet, on top)
                                      ├ tap row  → ScheduleImportRowEditSheet
                                      ├ swipe    → delete row
                                      ├ "เพิ่มคาบในวันนี้" → new blank row
                                      ├ toggle   → show only ⚠️ rows
                                      ├ thumbnail → full-screen source photo
                                      ├ [ยกเลิก] → confirm "ทิ้งข้อมูลที่อ่านมา?"
                                      └ [บันทึก] → confirm → ScheduleImportCommitter
                                           └ both sheets close, Schedule tab jumps
                                             to the first imported day
```

### 0.2 The one data type every phase shares

Declare in **`Core/Schedule/ScheduleImport.swift`**. Do not invent variants of it.

```swift
/// One row in the import review sheet. Purely in memory — this is NOT a @Model.
struct ImportedPeriod: Identifiable {
    let id = UUID()

    var dayOfWeek: Int          // 1 = Monday … 7 = Sunday
    var periodNumber: Int       // as printed on the sheet; index+1 when unreadable
    var startMinute: Int        // minutes from midnight
    var endMinute: Int

    var subjectCode: String     // "ว30203", or "" when the cell held no code
    var subjectName: String     // what will be shown in the timetable
    var teacherName: String     // "" when unknown
    var room: String            // "" when unknown
    var isBreak: Bool           // homeroom / lunch / club / activity

    // Why this row might be wrong. Keep these SEPARATE — the review UI shows a
    // different hint for each, and merging them loses that.
    var codeNeedsReview: Bool   // OCR could not prove the subject code
    var codeOptions: [String]   // enumerable alternatives, may be empty
    var timeIsGuessed: Bool     // the period's time was inferred, not read
    var nameIsGuessed: Bool     // name was derived from the code, not read

    var isUserAdded: Bool = false   // typed by hand in the review sheet

    var needsAttention: Bool { codeNeedsReview || timeIsGuessed || nameIsGuessed }
}
```

### 0.3 Decisions already made — do not re-litigate, do not "improve"

| # | Decision |
|---|---|
| D1 | **Overwrite = wipe whole days.** Every `dayOfWeek` present in the import has ALL its existing `ScheduleEntry` rows deleted, then the imported rows are inserted. Days absent from the photo are untouched. Confirm dialog before this happens, naming the days and the count. |
| D2 | **Subject matching: code first, then name.** Non-empty `subjectCode` matches `Subject.code` case-insensitively. Empty code falls back to a case-insensitive `Subject.name` match. Only if both miss is a new `Subject` created. |
| D3 | **Code → name is a guess.** A row whose name came from the code sets `nameIsGuessed = true`, shows ⚠️ in the list, and offers a dropdown of ~40 real subject names (§Z.2) in the edit sheet. |
| D4 | **Breaks are Subjects with `isBreak = true`**, named exactly as OCR read them ("โฮมรูม", "พักกลางวัน", "ชุมนุม"). This is what `ScheduleTimetableSection` already keys off. |
| D5 | **Icon + colour come from a fixed table** (§Z.1), keyed on the code's leading consonant, with per-subject overrides. Never rotate the palette for imported subjects. |
| D6 | **Feature is Free.** No `EntitlementStore` gate, no `TierBadge`. |
| D7 | **Guessed times save fine**, flagged ⚠️. Never block the save button on them. |
| D8 | **Teacher and room are written into `ScheduleEntry`** (`teacherName`, `location`) and are editable in the review sheet. |
| D9 | **One photo per import session.** No multi-photo merge in this plan. |
| D10 | **Entry point exists in add mode only.** `AddScheduleEntrySheet(editing: nil, …)` shows it; edit mode does not. |

### 0.4 Hard constraints

- **No new `@Model`.** `ImportedPeriod` is a plain struct → `Schema([...])` in
  `App/PrototypeAppApp.swift` and `SettingsView.resetAllData()` stay untouched.
- **No new SPM dependency.** Vision + SwiftUI + SwiftData only.
- Deployment target iOS 26.5 — no `if #available` back-compat.
- All UI strings in **Thai**. Code comments in English.
- Colours/spacing/radii from `Theme` only. No hardcoded hex in views.
- Camera and photo-library usage strings **already exist** in `PrototypeApp/Info.plist`.
- New `.swift` files enter the target automatically (file-system-synchronized groups).
  **Never edit `project.pbxproj`.**
- Do **not** touch `Features/Onboarding/ScheduleSetupView.swift`. Its photo flow stays as
  it is for now, duplicated on purpose.

### 0.5 Files this plan creates and modifies

| Phase | File | Action |
|---|---|---|
| A | `Core/OCR/TableGridBuilder.swift` | modify — carry printed period numbers |
| A | `Core/OCR/ScheduleOCRParser.swift` | modify — `periodNumber`, split `timeIsGuessed` |
| B | `Core/Schedule/ThaiSubjectCatalog.swift` | **new** — code grammar → name/icon/colour |
| C | `Core/Schedule/ScheduleImport.swift` | **new** — `ImportedPeriod` + `ScheduleImportBuilder` |
| D | `Features/Schedule/AddScheduleEntrySheet.swift` | modify — entry point + pickers |
| E | `Features/Schedule/ScheduleImportReviewSheet.swift` | **new** |
| E | `Features/Schedule/ScheduleImportRowEditSheet.swift` | **new** |
| F | `Core/Schedule/ScheduleImportCommitter.swift` | **new** |
| F | `Features/Schedule/ScheduleView.swift` | modify — jump to imported day |
| F | `claude plan/PROJECT_MAP.md` | modify — record the new files |

Phases are ordered by dependency. **Stop after each phase, hand it to Few to build.**

---

## §A · Fix F4 — real period numbers, and separate the time flag

**Why now:** `ImportedPeriod.periodNumber` is D1's overwrite key in the user's head and the
number they will read on screen. Today `ScheduleDraftEntry.periodNumber` is the 0-based
*column index*, so a sheet starting at period 1 is off by one and a sheet with a homeroom
column is off by more. Confirmed wrong on both reference photos (PLAN_OCR_Round3 §C5).

The printed numbers are already parsed — `TableGridBuilder.periodNumberFractions` uses
their *positions* to fit the axis and then throws the *values* away.

### A.1 `TableGridBuilder.swift`

1. Add to `OCRTableGrid`:
   ```swift
   /// periodAxis index → the period number printed on the paper. Empty when the
   /// header row was unreadable; callers fall back to index + 1.
   let printedPeriodNumbers: [Int: Int]
   ```
2. New private function, run **after** `periodAxis` is fitted:
   ```swift
   private static func printedPeriodNumbers(
       _ boxes: [OCRTextBox], periodAxis: OCRTableGrid.Axis, daysAreRows: Bool
   ) -> [Int: Int]
   ```
   - For every box where `isPeriodNumberOnly(box.text)`, for every token from
     `tokens(in:)` that parses to `0...12`, compute the same position that
     `numericHeaderCandidate` computes for it, then `periodAxis.index(for:)`.
   - Collect `[index: [value]]`, keep the **most frequent** value per index.
3. **Sanity gate — reject the whole map rather than half-trust it.** Return `[:]` unless:
   - at least 3 indices were resolved, **and**
   - the values are **strictly increasing** with index.

   Strictly increasing, *not* consecutive: a lunch column legitimately makes the
   printed sequence skip (1 2 3 พัก 4 5). A map that is not monotonic means the
   header row was misread, and a wrong number is worse than no number.
4. Pass it into the `OCRTableGrid(...)` initializer next to `dayNumbers`.

### A.2 `ScheduleOCRParser.swift`

1. Add to `ScheduleDraftEntry`:
   ```swift
   /// True when the period's time was inferred from its neighbours rather than read.
   var timeIsGuessed: Bool = false
   ```
   Keep the default so no existing call site breaks.
2. In `buildDraftSchedule`, replace the two fields:
   ```swift
   periodNumber: grid.printedPeriodNumbers[reading.period] ?? (reading.period + 1),
   timeIsGuessed: time?.isInferred != false,
   ```
   `needsReview` keeps its current meaning (`content.needsReview || time?.isInferred != false`)
   so `OCRDebugView` is unaffected.

### A.3 Definition of done
- `printedPeriodNumbers` is non-empty for both reference photos.
- `OCRDebugView`'s list shows `ค1 ค2 ค3 …` matching what is printed, not `ค0`.
- On a photo with an unreadable header row, every row still shows a plausible number
  (index + 1) and nothing crashes.

### A.4 Few taps
Settings → สำหรับนักพัฒนา → OCR Debug → เลือกรูป ม.4/9 แล้วรูป ม.1/1 → เทียบเลขคาบใน
รายการกับเลขที่พิมพ์บนกระดาษ

---

## §B · `ThaiSubjectCatalog` — the code grammar, as data

**New file `Core/Schedule/ThaiSubjectCatalog.swift`. Logic only, no `View`, no SwiftData.**
Read **§Z.1 and §Z.2** now — they are the literal contents of the tables below.

### B.1 Types

```swift
enum ThaiSubjectStrand: String, CaseIterable, Identifiable {
    case thai, math, science, social, health, arts, career
    case english, chinese, japanese, korean, french, german

    var id: String { rawValue }
    var letter: Character   // ท ค ว ส พ ศ ง อ จ ญ ก ฝ ย
    var displayName: String // §Z.1 column 2
    var iconName: String    // §Z.1 column 3
    var colorHex: String    // §Z.1 column 4 — all values come from Theme.Colors.subjectPaletteHex
    var commonSubjects: [String]  // §Z.2
}

struct ParsedSubjectCode {
    let raw: String
    let strand: ThaiSubjectStrand
    let isAdditional: Bool   // digit 3: 1 = พื้นฐาน, 2 = เพิ่มเติม
}
```

### B.2 Functions

```swift
enum ThaiSubjectCatalog {
    /// nil when `code` is not a well-formed Thai subject code, or its leading
    /// consonant is not a strand we know. Reuses SubjectCodeValidator.isValid —
    /// do not re-implement the grammar here.
    static func parse(_ code: String) -> ParsedSubjectCode?

    /// "ว30203" → "วิทยาศาสตร์เพิ่มเติม" · "ค32101" → "คณิตศาสตร์พื้นฐาน"
    /// Deliberately a category, not a real subject name: the code cannot tell
    /// ฟิสิกส์ from เคมี. The review sheet flags this with nameIsGuessed.
    static func generatedName(for parsed: ParsedSubjectCode) -> String

    /// Icon and colour for a subject. `name` wins over `strand` when it matches
    /// an override in §Z.3 (ฟิสิกส์ → atom, ดนตรี → music.note, …).
    static func appearance(strand: ThaiSubjectStrand?, name: String) -> (iconName: String, colorHex: String)

    /// Break / activity cells. Matches on substring, case-insensitive:
    /// พัก · กลางวัน · โฮมรูม · ชุมนุม · กิจกรรม · แนะแนว · ลูกเสือ · เนตรนารี · ยุวกาชาด
    static func isBreakLabel(_ text: String) -> Bool

    /// Appearance for a break: "พัก"/"กลางวัน" → fork.knife + FFB347,
    /// everything else → person.3.fill + FFB347.
    static func breakAppearance(for name: String) -> (iconName: String, colorHex: String)
}
```

`generatedName` is exactly `strand.displayName + (isAdditional ? "เพิ่มเติม" : "พื้นฐาน")`.

### B.3 Definition of done
- Pure functions, zero imports beyond `Foundation`/`SwiftUI`.
- Every `iconName` in §Z.1 and §Z.3 is a real SF Symbol available on iOS 26.
- Every `colorHex` appears in `Theme.Colors.subjectPaletteHex`.
- `parse("ว30203")?.strand == .science`, `.isAdditional == true`.
- `parse("32101") == nil`, `parse("ฮ32101") == nil` (ฮ is not a strand).

### B.4 Few taps
Nothing yet — this phase only has to compile. Confirm ⌘B is green before phase C.

---

## §C · `ScheduleImportBuilder` — drafts → review rows

**New file `Core/Schedule/ScheduleImport.swift`** containing `ImportedPeriod` (§0.2 verbatim)
and:

```swift
enum ScheduleImportBuilder {
    static func build(from drafts: [ScheduleDraftEntry]) -> [ImportedPeriod]
}
```

### C.1 Rules, in order

For each `ScheduleDraftEntry`:

1. Skip when `subjectName.trimmed.isEmpty`.
2. **Break?** `ThaiSubjectCatalog.isBreakLabel(subjectName)` →
   `isBreak = true`, `subjectName` as read, `subjectCode = ""`,
   `nameIsGuessed = false`, `codeNeedsReview = false`.
3. **Code?** `ThaiSubjectCatalog.parse(subjectName)` returns non-nil →
   `subjectCode = subjectName`, `subjectName = generatedName(...)`,
   `nameIsGuessed = true`.
4. **Otherwise** free text (an activity or a name the school printed in full) →
   `subjectName` as read, `subjectCode = ""`, `nameIsGuessed = false`.
5. Always copy across: `dayOfWeek`, `periodNumber`, `startMinute`, `endMinute`,
   `teacherName ?? ""`, `room ?? ""`, `timeIsGuessed`, `reviewOptions → codeOptions`.
6. `codeNeedsReview = draft.needsReview && !draft.timeIsGuessed`
7. Sort by `dayOfWeek`, then `periodNumber`, then `startMinute`.

> Why step 6 subtracts: `ScheduleDraftEntry.needsReview` deliberately folds the time
> flag in for `OCRDebugView`'s benefit (§A.2). `ImportedPeriod` keeps the two apart
> because the review sheet shows a different hint for each, so the time half has to
> come back out here. Do not add a third flag to the parser to avoid this line.

### C.2 Definition of done
- `build(from: [])` returns `[]`.
- A draft named `"ว30203"` comes back with `subjectCode == "ว30203"`,
  `subjectName == "วิทยาศาสตร์เพิ่มเติม"`, `nameIsGuessed == true`.
- A draft named `"โฮมรูม"` comes back with `isBreak == true`, `subjectCode == ""`.
- A draft named `"คณิตศาสตร์เพิ่มเติม ม.5"` comes back unchanged, `nameIsGuessed == false`.

### C.3 Few taps
Still nothing visible. ⌘B green, then phase D.

---

## §D · Entry point — button, warning, camera, library

Modify **`Features/Schedule/AddScheduleEntrySheet.swift`** only.

### D.1 New state

```swift
@State private var isShowingScanWarning = false
@State private var isShowingPhotoSource = false
@State private var activePickerSource: ProfileImagePicker.Source?
@State private var isAnalyzingPhoto = false
@State private var scanError: String?
@State private var reviewPayload: ImportReviewPayload?   // struct { image: UIImage; periods: [ImportedPeriod] } : Identifiable
```

`ProfileImagePicker` lives in `Features/Onboarding/` and its `Source: Identifiable`
conformance is declared in `ProfileSetupView.swift`. Both are in the same target —
use them, do not duplicate them.

### D.2 New first section of the `Form`

Guarded by `if editing == nil` (D10). Place it **above** `dayAndPeriodSection`.

```swift
Section {
    Button {
        isShowingScanWarning = true
    } label: {
        Label("ถ่ายตารางสอน", systemImage: "camera.viewfinder")
    }
    .disabled(isAnalyzingPhoto)
    if isAnalyzingPhoto {
        HStack(spacing: Theme.Spacing.sm) {
            ProgressView()
            Text("กำลังอ่านตารางเรียน…").foregroundStyle(.secondary)
        }
    }
    if let scanError {
        Text(scanError).font(.caption).foregroundStyle(Theme.Colors.warning)
    }
} footer: {
    Text("อ่านตารางทั้งใบจากรูป แล้วกรอกคาบให้อัตโนมัติ")
}
```

Keep this as a `private var scanSection: some View` computed property. The `Form` body
is already near SwiftUI's type-check limit — inlining it risks
"unable to type-check this expression in reasonable time".

### D.3 Modifiers on the `NavigationStack`

```swift
.alert("ระบบอาจอ่านผิด", isPresented: $isShowingScanWarning) {
    Button("ยกเลิก", role: .cancel) {}
    Button("เข้าใจแล้ว") { isShowingPhotoSource = true }
} message: {
    Text("การอ่านตารางจากรูปอาจอ่านผิด โดยเฉพาะรหัสวิชาและเวลา กรุณาตรวจทุกคาบก่อนบันทึก")
}
.confirmationDialog("เลือกรูปตารางเรียน", isPresented: $isShowingPhotoSource, titleVisibility: .visible) {
    if UIImagePickerController.isSourceTypeAvailable(.camera) {
        Button("ถ่ายรูป") { activePickerSource = .camera }
    }
    Button("เลือกจากคลังภาพ") { activePickerSource = .photoLibrary }
    Button("ยกเลิก", role: .cancel) {}
}
.fullScreenCover(item: $activePickerSource) { source in
    ProfileImagePicker(source: source, allowsEditing: false) { analyze($0) }
        .ignoresSafeArea()
}
.sheet(item: $reviewPayload) { payload in
    ScheduleImportReviewSheet(payload: payload) { confirmed in
        commitImport(confirmed)          // phase F
    }
    .presentationDetents([.large])
    .interactiveDismissDisabled(true)
}
```

`import UIKit` at the top of the file (for `UIImage` / `UIImagePickerController`).

### D.4 `analyze`

```swift
private func analyze(_ image: UIImage) {
    isAnalyzingPhoto = true
    scanError = nil
    ScheduleOCRParser.parseScheduleDetailed(from: image, onRawBoxes: nil) { result in
        isAnalyzingPhoto = false
        let periods = ScheduleImportBuilder.build(from: result.entries)
        if periods.isEmpty {
            scanError = result.problem?.message
                ?? "อ่านตารางจากรูปนี้ไม่สำเร็จ ลองถ่ายให้เห็นตารางทั้งใบและอย่าให้เอียง"
            AppLog.warn("ScheduleImport", "OCR ไม่ได้คาบเลย · problem=\(String(describing: result.problem))")
            return
        }
        if let problem = result.problem { scanError = problem.message }   // e.g. timesNotRecognized
        AppLog.action("ScheduleImport", "อ่านได้ \(periods.count) คาบ · ต้องตรวจ \(periods.filter(\.needsAttention).count)")
        reviewPayload = ImportReviewPayload(image: image, periods: periods)
    }
}
```

`parseScheduleDetailed` calls back on the **main thread** already — do not add another hop.

### D.5 Definition of done
- Button appears only when the sheet was opened with `editing: nil`.
- Warning → source dialog → picker → spinner → review sheet, with no dead ends.
- Cancelling the picker returns to the form with nothing changed.
- A blank photo shows the Thai problem message inline, no crash, no empty sheet.

### D.6 Few taps
1. ตารางเรียน → `+` → ต้องเห็นปุ่ม "ถ่ายตารางสอน" บนสุด
2. แตะแถวคาบเดิมเพื่อแก้ → **ต้องไม่เห็นปุ่มนี้**
3. กดปุ่ม → เห็นคำเตือน → เข้าใจแล้ว → เห็นตัวเลือกถ่าย/คลังภาพ
4. เลือกรูปตารางจริง → เห็น spinner → เห็นหน้าตรวจโผล่มาทับ
5. เลือกรูปวิวเปล่าๆ → เห็นข้อความสีส้มบอกว่าอ่านไม่ได้

---

## §E · Review sheet + row edit sheet

Two new files under `Features/Schedule/`. **No SwiftData writes happen in this phase** —
the sheet hands a `[ImportedPeriod]` back through its `onSave` closure and that is all.

### E.1 `ScheduleImportReviewSheet.swift`

```swift
struct ScheduleImportReviewSheet: View {
    let payload: ImportReviewPayload
    let onSave: ([ImportedPeriod]) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var periods: [ImportedPeriod]      // seeded from payload in init
    @State private var showsOnlyFlagged = false
    @State private var editingPeriod: ImportedPeriod?
    @State private var isShowingSourceImage = false
    @State private var isConfirmingDiscard = false
    @State private var isConfirmingSave = false
}
```

Layout, top to bottom, inside a `NavigationStack`:

1. **Summary header** (a `CardContainer`):
   `"อ่านได้ \(periods.count) คาบ · ต้องตรวจ \(flaggedCount) คาบ"`
   plus a small photo thumbnail button on the trailing side → `isShowingSourceImage = true`.
2. **Filter toggle**: `Toggle("เฉพาะที่ต้องตรวจ (\(flaggedCount))", isOn: $showsOnlyFlagged)`,
   hidden entirely when `flaggedCount == 0`.
3. **`List`**, one `Section` per day, days sorted ascending, section header
   `ScheduleConstants.dayLabelsFull[day]`. Show whatever days are present — do **not**
   filter through `ScheduleConstants.visibleDays`; a Saturday row must stay visible so
   the user can delete it.
   - Row content: subject name (`.headline`) · code chip when non-empty ·
     `"คาบ \(periodNumber) · \(startMinute.asClockString)-\(endMinute.asClockString)"` ·
     teacher and room on one secondary line · trailing ⚠️ when `needsAttention`.
   - `.onTapGesture` → `editingPeriod = period`.
   - `.swipeActions` destructive "ลบ" → remove by `id`.
   - Section footer: `Button("เพิ่มคาบใน\(dayLabel)")` → appends a blank
     `ImportedPeriod(dayOfWeek: day, isUserAdded: true, …)` and immediately opens the
     edit sheet for it.
4. **Toolbar**: `.cancellationAction` "ยกเลิก" → `isConfirmingDiscard = true` ·
   `.confirmationAction` "บันทึก" (semibold) → `isConfirmingSave = true`.

Dialogs:
```swift
.confirmationDialog("ทิ้งข้อมูลที่อ่านมา?", isPresented: $isConfirmingDiscard, titleVisibility: .visible) {
    Button("ทิ้งทั้งหมด", role: .destructive) { dismiss() }
    Button("กลับไปตรวจต่อ", role: .cancel) {}
}
.confirmationDialog(saveConfirmTitle, isPresented: $isConfirmingSave, titleVisibility: .visible) {
    Button("บันทึกตารางเรียน") { onSave(periods) }
    Button("ยกเลิก", role: .cancel) {}
} message: {
    Text("จะลบคาบเดิมของ \(dayListText) แล้วใส่ \(periods.count) คาบนี้แทน")
}
```
where `dayListText` is the touched days joined with " · " using
`ScheduleConstants.dayLabels`, e.g. `"จันทร์ · อังคาร · พุธ · พฤหัส · ศุกร์"`.

**Dismissal:** `.interactiveDismissDisabled(true)` is set by the presenter (§D.3).
SwiftUI gives no hook to intercept a swipe-down and ask for confirmation, so the swipe is
disabled and "ยกเลิก" carries the confirmation instead. That is the intent — no
accidental loss — implemented the only way the platform allows. Do not try to work
around it with a `UIViewControllerRepresentable`.

**Source photo viewer** — a plain `.sheet(isPresented: $isShowingSourceImage)` holding
`Image(uiImage:).resizable().scaledToFit()` inside a `ScrollView([.horizontal, .vertical])`,
with a `MagnifyGesture` driving a clamped `scaleEffect` (1…5) and a "เสร็จสิ้น" toolbar
button. Keep it in the same file as a `private struct`.

**Type-check safety:** split the body into `summaryHeader`, `filterToggle`, `periodList`,
and a `periodRow(_:)` function. Do not write one 200-line `body`.

### E.2 `ScheduleImportRowEditSheet.swift`

```swift
struct ScheduleImportRowEditSheet: View {
    let period: ImportedPeriod
    let onSave: (ImportedPeriod) -> Void
    let onDelete: () -> Void
}
```

A `Form` with:

| Section | Fields |
|---|---|
| วิชา | `TextField("ชื่อวิชา", …)` · when `codeOptions` is non-empty, a `Picker` of those options · when the code parsed, a `Picker("วิชาที่พบบ่อย")` listing `strand.commonSubjects` from §Z.2 plus "อื่นๆ (พิมพ์เอง)" · `TextField("รหัสวิชา", …)` |
| เวลา | `Picker("วัน")` over `ScheduleConstants.visibleDays` · `TextField("คาบที่")` numberPad · two `DatePicker(displayedComponents: .hourAndMinute)` |
| รายละเอียด | `TextField("ชื่อครู")` · `TextField("ห้องเรียน")` · `Toggle("เป็นคาบพัก / กิจกรรม")` |
| — | destructive `Button("ลบคาบนี้")` |

Behaviour:
- Picking from the "วิชาที่พบบ่อย" dropdown sets the name **and clears `nameIsGuessed`**.
- Typing in the name field also clears `nameIsGuessed`.
- Picking from `codeOptions` sets `subjectCode` and clears `codeNeedsReview`.
- Editing either time field clears `timeIsGuessed`.
- Save is disabled when the trimmed name is empty or `endMinute <= startMinute`;
  show `"เวลาสิ้นสุดต้องมากกว่าเวลาเริ่ม"` in `Theme.Colors.danger` in that case.
- Convert between `Int` minutes and `Date` the same way `AddScheduleEntrySheet` already
  does (`Calendar.current.dateComponents([.hour, .minute], …)`). Do not invent a
  third conversion helper — if you want one, put it next to `Int.asClockString` in
  `ScheduleEntry.swift` and use it from both.

### E.3 Definition of done
- Every OCR row is visible, grouped by day, in ascending period order.
- The ⚠️ filter hides clean rows and the count in its label is right.
- Editing a row updates the list immediately; deleting removes it.
- "เพิ่มคาบใน…" produces a row that survives to the save payload.
- The thumbnail opens the original photo and it can be zoomed.
- "ยกเลิก" asks before throwing the work away; swipe-down does nothing.
- Nothing has been written to SwiftData yet — closing the app here loses the draft,
  and that is correct for this phase.

### E.4 Few taps
1. ถ่ายรูปตาราง → หน้าตรวจ → เลื่อนดูครบทุกวัน เทียบกับกระดาษ
2. เปิด "เฉพาะที่ต้องตรวจ" → เหลือแต่แถว ⚠️
3. แตะแถว ⚠️ ที่เป็นรหัส → เลือกชื่อวิชาจาก dropdown → ⚠️ หาย
4. แตะรูปย่อมุมบน → เห็นรูปต้นฉบับ ซูมได้
5. ปัด sheet ลง → **ต้องไม่ปิด** · กด "ยกเลิก" → ต้องมีคำถามยืนยัน
6. กด "บันทึก" → เห็นคำถามยืนยันที่ระบุวันและจำนวนคาบ (ยังไม่ต้องบันทึกจริงในเฟสนี้)

---

## §F · Commit to SwiftData, then land on the right day

### F.1 `Core/Schedule/ScheduleImportCommitter.swift`

```swift
enum ScheduleImportCommitter {
    struct Summary {
        var deletedEntries = 0
        var insertedEntries = 0
        var createdSubjects = 0
        var days: [Int] = []
        var firstDay: Int? { days.min() }
    }

    /// Wipes every ScheduleEntry on the days the import covers, then inserts the
    /// reviewed rows. Days absent from `periods` are left alone (contract D1).
    @discardableResult
    static func commit(_ periods: [ImportedPeriod], in context: ModelContext) -> Summary
}
```

Steps, in order:

1. `let days = Set(periods.map(\.dayOfWeek))`. Return an empty `Summary` when empty.
2. Fetch `FetchDescriptor<ScheduleEntry>()`, `context.delete` every entry whose
   `dayOfWeek` is in `days`. Count them.
3. Fetch `FetchDescriptor<Subject>()` **once** into a local array and resolve against
   that array, appending as you create. Do not re-fetch inside the loop.
4. For each period, resolve its `Subject` (contract D2):
   - `subjectCode` non-empty → first subject with
     `subject.code.caseInsensitiveCompare(code) == .orderedSame`
   - else → first subject with `subject.name.caseInsensitiveCompare(name) == .orderedSame`
   - else create:
     ```swift
     let look = period.isBreak
         ? ThaiSubjectCatalog.breakAppearance(for: period.subjectName)
         : ThaiSubjectCatalog.appearance(
             strand: ThaiSubjectCatalog.parse(period.subjectCode)?.strand,
             name: period.subjectName)
     let subject = Subject(name: period.subjectName, code: period.subjectCode,
                           colorHex: look.colorHex, iconName: look.iconName,
                           isBreak: period.isBreak)
     context.insert(subject)
     ```
5. Insert the entry:
   ```swift
   context.insert(ScheduleEntry(
       dayOfWeek: period.dayOfWeek, startMinute: period.startMinute,
       endMinute: period.endMinute, periodNumber: period.periodNumber,
       teacherName: period.teacherName, location: period.room,
       subjectName: subject.name, subject: subject))
   ```
6. `try context.save()` inside `do/catch`. On failure `AppLog.error` and return the
   summary with `insertedEntries = 0` — never swallow it silently.
7. `AppLog.action("ScheduleImport", "บันทึก \(inserted) คาบ · ลบของเดิม \(deleted) คาบ · สร้างวิชาใหม่ \(created) รายการ · วัน \(days.sorted())")`

**Do not delete any `Subject`.** `Assignment.subjectName` is a loose string lookup and
`DayScheduleOverride` keys on a date, so deleting only `ScheduleEntry` rows is safe;
deleting subjects would silently orphan homework.

### F.2 Wire the dismissal chain

`AddScheduleEntrySheet` gains an optional callback:

```swift
init(editing: ScheduleEntry?, defaultDay: Int, onImported: ((Int) -> Void)? = nil)
```

```swift
private func commitImport(_ periods: [ImportedPeriod]) {
    let summary = ScheduleImportCommitter.commit(periods, in: context)
    reviewPayload = nil                       // closes the review sheet
    if let day = summary.firstDay { onImported?(day) }
    dismiss()                                 // closes this sheet
}
```

`ScheduleView` passes it through — the existing add-mode presentation only:

```swift
.sheet(isPresented: $isAddingEntry) {
    AddScheduleEntrySheet(editing: nil, defaultDay: selectedDay) { day in
        selectedDay = day
    }
}
```

Leave the `.sheet(item: $editingEntry)` presentation alone (no import in edit mode).

### F.3 Update `claude plan/PROJECT_MAP.md` in the same commit

- §2 file tree: add `Core/Schedule/ThaiSubjectCatalog.swift`, `Core/Schedule/ScheduleImport.swift`,
  `Core/Schedule/ScheduleImportCommitter.swift`,
  `Features/Schedule/ScheduleImportReviewSheet.swift`, `ScheduleImportRowEditSheet.swift`
- §4 Navigation: note the import entry point inside `AddScheduleEntrySheet` (add mode only)
- §8 tech debt: `ScheduleSetupView` still has its own duplicate photo flow that does not
  use `ScheduleImportBuilder`
- §3 models table: **no change** — nothing new was added to `Schema`

### F.4 Definition of done
- Saving writes real rows and the Schedule tab shows them immediately.
- Re-importing the same photo produces the same result, not doubled rows.
- Importing a Mon–Fri photo leaves a manually added Saturday period untouched.
- A subject that already existed with a matching `code` is reused — check the subject
  count in `AddScheduleEntrySheet`'s picker before and after.
- Break rows render through `ScheduleBreakRow` (cream background, no period number).
- No crash when the app is relaunched afterwards.

### F.5 Few taps
1. ถ่ายรูปตาราง → ตรวจ → บันทึก → ต้องเด้งกลับหน้าตารางที่วันจันทร์ (หรือวันแรกที่มีคาบ)
2. เลื่อนดูครบ จ–ศ ต้องตรงกับที่ตรวจไว้ · แถวพักกลางวันต้องเป็นแถบครีม
3. เพิ่มคาบวันเสาร์ด้วยมือ → นำเข้ารูป จ–ศ ใหม่ → **คาบวันเสาร์ต้องยังอยู่**
4. นำเข้ารูปเดิมซ้ำอีกรอบ → จำนวนคาบต้องเท่าเดิม ไม่เพิ่มเป็นสองเท่า
5. ปิดแอปแล้วเปิดใหม่ → ตารางยังอยู่ ไม่ crash
6. Settings → ล้างข้อมูลทั้งหมด → ไม่ crash และวิชาเริ่มต้น 3 ตัวกลับมา

---

## §G · Risks

| Risk | Mitigation |
|---|---|
| D1 wipes a day the user had hand-tuned | Confirmation dialog names the days and the count before anything is deleted. This is the only destructive step in the feature — keep it loud. |
| Changing `periodNumber` semantics (§A) shifts numbers on existing timetables | It does not: §A only changes what the *parser* emits. Rows already in SwiftData are never rewritten. |
| SwiftUI type-check timeout in the review sheet | Split into sub-views from the start (§E.1). If ⌘B hangs, break the body further — never "simplify" by removing features. |
| Nested presentation (sheet → fullScreenCover → sheet) | Present all three from the same `NavigationStack` in `AddScheduleEntrySheet`, never from inside a child view. |
| The name dropdown (§Z.2) does not match a given school's curriculum | It is a convenience list, not a constraint — the name `TextField` is always editable and always wins. |
| OCR still mis-reads (C1/C2/C3 in PLAN_OCR_Round3 are open) | Out of scope here. This plan's job is to make every mistake visible and one tap away from being fixed. |

---

## §Z · Appendix — the tables (read during phase B only)

### Z.1 Strand → letter, name, icon, colour

Names are the **short** forms used for `generatedName`; "พื้นฐาน"/"เพิ่มเติม" is appended.
All colours are members of `Theme.Colors.subjectPaletteHex`.

| case | letter | displayName | iconName | colorHex |
|---|---|---|---|---|
| `.thai` | ท | ภาษาไทย | `book.closed.fill` | `FF6B6B` |
| `.math` | ค | คณิตศาสตร์ | `function` | `4A7DFF` |
| `.science` | ว | วิทยาศาสตร์ | `atom` | `4CAF50` |
| `.social` | ส | สังคมศึกษา | `globe.asia.australia.fill` | `FFB347` |
| `.health` | พ | สุขศึกษาและพลศึกษา | `figure.run` | `00BCD4` |
| `.arts` | ศ | ศิลปะ | `paintpalette.fill` | `E91E63` |
| `.career` | ง | การงานอาชีพ | `hammer.fill` | `9C27B0` |
| `.english` | อ | ภาษาอังกฤษ | `textformat.abc` | `3F51B5` |
| `.chinese` | จ | ภาษาจีน | `globe` | `FF6B6B` |
| `.japanese` | ญ | ภาษาญี่ปุ่น | `globe` | `E91E63` |
| `.korean` | ก | ภาษาเกาหลี | `globe` | `9C27B0` |
| `.french` | ฝ | ภาษาฝรั่งเศส | `globe` | `3F51B5` |
| `.german` | ย | ภาษาเยอรมัน | `globe` | `00BCD4` |

> `ก` is both a valid Thai consonant and the strand letter for Korean. That is fine here:
> the strand table is only consulted after `SubjectCodeValidator.isValid` has confirmed
> the shape, and `ก` is not used by any core-subject strand.

### Z.2 `commonSubjects` — the review-sheet dropdown (41 entries)

| strand | entries |
|---|---|
| `.thai` | หลักภาษาไทย · วรรณคดีและวรรณกรรม · การอ่านและการเขียน · การเขียนเชิงสร้างสรรค์ |
| `.math` | คณิตศาสตร์พื้นฐาน · คณิตศาสตร์เพิ่มเติม · สถิติ · แคลคูลัสเบื้องต้น |
| `.science` | ฟิสิกส์ · เคมี · ชีววิทยา · วิทยาศาสตร์กายภาพ · วิทยาศาสตร์ชีวภาพ · โลก ดาราศาสตร์ และอวกาศ · วิทยาการคำนวณ · การออกแบบและเทคโนโลยี |
| `.social` | สังคมศึกษา · ประวัติศาสตร์ · พระพุทธศาสนา · หน้าที่พลเมือง · เศรษฐศาสตร์ · ภูมิศาสตร์ |
| `.health` | สุขศึกษา · พลศึกษา |
| `.arts` | ทัศนศิลป์ · ดนตรี · นาฏศิลป์ |
| `.career` | การงานอาชีพ · คหกรรม · งานช่าง · งานเกษตร · ธุรกิจและการเป็นผู้ประกอบการ |
| `.english` | ภาษาอังกฤษพื้นฐาน · ภาษาอังกฤษเพิ่มเติม · ภาษาอังกฤษฟัง-พูด · ภาษาอังกฤษอ่าน-เขียน |
| `.chinese` `.japanese` `.korean` `.french` `.german` | its own `displayName` only (1 entry each) |

### Z.3 Per-subject icon overrides

Matched on exact `subjectName` after the user picks from Z.2. Colour always stays the
strand colour — only the icon changes, so a strand still reads as one colour family.

| name | iconName |
|---|---|
| ฟิสิกส์ | `atom` |
| เคมี | `flask.fill` |
| ชีววิทยา | `leaf.fill` |
| วิทยาการคำนวณ | `desktopcomputer` |
| การออกแบบและเทคโนโลยี | `hammer.fill` |
| ประวัติศาสตร์ | `flag.fill` |
| หน้าที่พลเมือง | `person.3.fill` |
| ดนตรี | `music.note` |
| ทัศนศิลป์ | `paintpalette.fill` |
| คหกรรม | `fork.knife` |
| สุขศึกษา | `heart.fill` |
| พลศึกษา | `figure.run` |

### Z.4 Break keywords for `isBreakLabel`

Substring match, case- and whitespace-insensitive:

```
พัก · กลางวัน · โฮมรูม · ชุมนุม · กิจกรรม · แนะแนว · ลูกเสือ · เนตรนารี · ยุวกาชาด
```

`fork.knife` + `FFB347` when the text contains พัก or กลางวัน; `person.3.fill` + `FFB347`
otherwise.

---

## §H · Reporting rule for every phase

We cannot compile. `xcodebuild` does not exist in this environment. End every phase with:

```
เช็คแล้ว:
- <what was actually verified, e.g. grep confirmed no other caller of this init>

ยังไม่ได้เช็ค:
- ยังไม่ได้คอมไพล์ (รัน xcodebuild ไม่ได้)
- <anything else>

รบกวน Few:
1. กด ⌘B ใน Xcode
2. ถ้าแดง — copy error ทั้งก้อนจาก Issue Navigator มาวาง
3. ถ้าเขียว — ทำตาม "Few taps" ของเฟสนี้ แล้วบอกว่าเห็นอะไร
```

Never write "build ผ่านแล้ว" or "ทดสอบแล้วใช้งานได้". Commit only after Few confirms
green, with `wip:` prefix otherwise.
