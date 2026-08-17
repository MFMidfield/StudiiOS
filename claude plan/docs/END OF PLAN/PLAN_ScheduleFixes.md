# PLAN — Schedule Fixes (Period Shift + Subject Picker)

> Written 2026-08-08 for an implementing agent (Sonnet).
> Spec confirmed with Few. **Do not re-ask these questions — they are already answered below.**

---

## 0. Before you touch anything

1. Read `claude plan/PROJECT_MAP.md` first. Do not `grep` the whole repo to rebuild context.
2. Repo root: `~/Documents/MyTask/PrototypeApp`. Source lives in `PrototypeApp/`.
3. **You cannot compile.** There is no `xcodebuild` and no Swift compiler in this environment.
   Never write "build passed", "compiles", or "tested and working".
4. All UI strings are Thai. Code comments are English.
5. Colors / spacing / radius must come from `Theme`. Never hardcode.
6. New `.swift` files are picked up automatically (file-system-synchronized groups).
   **Do not edit `.pbxproj`.**
7. When you are done, end your message with this exact block:

```
เช็คแล้ว:
- <what you actually verified, e.g. "grep ยืนยันไม่มีที่อื่นเรียก ThaiSubjectStrand.korean">

ยังไม่ได้เช็ค:
- ยังไม่ได้คอมไพล์ (ผมรัน xcodebuild ไม่ได้)
- <anything else>

รบกวน Few:
1. กด ⌘B ใน Xcode
2. ถ้าแดง — copy error ทั้งก้อนจาก Issue Navigator มาวางได้เลย
3. ถ้าเขียว — <exact steps from §5 below>
```

---

## 1. Task 1 — Fix the period-shift ("ร่นคาบ") feature

### 1.1 The bug

`Core/Schedule/PeriodShiftCalculator.swift`, lines 46–51:

```swift
for (index, entry) in sorted.enumerated() {
    if entry.subject?.isBreak == true {
        result.append(ResolvedPeriod(entry: entry, startMinute: entry.startMinute, endMinute: entry.endMinute, isShifted: false))
        cursor = entry.endMinute      // <-- THIS LINE IS THE BUG
        continue
    }
    ...
```

If the first row of the day is a break (โฮมรูม / พักกลางวัน — and today `ThaiSubjectCatalog.isBreakLabel`
also marks แนะแนว, ชุมนุม, กิจกรรม as breaks), the loop overwrites `cursor` with that row's *original*
end time. The user's chosen start (e.g. 09:20) is thrown away, so period 1 goes back to its normal time.
That is exactly the symptom Few reported.

### 1.2 The new agreed behaviour

Few chose:

- The shift sheet lets the user **pick which period number the start time applies to** (e.g. คาบ 0 or คาบ 1).
- Rows **before** that period are **hidden completely** for that day.
- From the anchor period onward, **every row shifts, including breaks**.
- Breaks are **shrunk to the same length as the periods** (`periodLengthMinutes`), not kept at their
  original length.

Worked example. Normal Monday:

| Row | Normal time |
|---|---|
| คาบ 0 โฮมรูม | 08:00–08:30 |
| คาบ 1 | 08:30–09:20 |
| คาบ 2 | 09:20–10:10 |
| คาบ 3 | 10:10–11:00 |
| คาบ 4 | 11:00–11:50 |
| พักกลางวัน (คาบ 0) | 11:50–12:40 |
| คาบ 5 | 12:40–13:30 |

Shift settings: start period = **1**, start time = **09:20**, period length = **40 min**. Result:

| Row | Shifted time |
|---|---|
| ~~คาบ 0 โฮมรูม~~ | **hidden — not rendered at all** |
| คาบ 1 | 09:20–10:00 |
| คาบ 2 | 10:00–10:40 |
| คาบ 3 | 10:40–11:20 |
| คาบ 4 | 11:20–12:00 |
| พักกลางวัน | 12:00–12:40 (shrunk to 40 min) |
| คาบ 5 | 12:40–13:20 |

### 1.3 File: `Core/Models/DayScheduleOverride.swift`

Add one stored property **with a default value** so SwiftData can do a lightweight migration:

```swift
var startPeriodNumber: Int = 1
```

Add it to `init` as `startPeriodNumber: Int = 1` and assign it. Place the parameter after `date:`
and before `startMinute:` so call sites read naturally.

Update the file header comment: it currently says breaks are not touched. That is no longer true.

> **Risk to report to Few:** adding a property is normally a lightweight migration, but if the app
> crashes at launch he must delete the app from the simulator/device and reinstall. Say this
> explicitly in your final message.

### 1.4 File: `Core/Schedule/PeriodShiftCalculator.swift`

Rewrite `apply(override:to:)`:

```swift
static func apply(override: DayScheduleOverride?, to entries: [ScheduleEntry]) -> [ResolvedPeriod] {
    let sorted = entries.sorted { $0.startMinute < $1.startMinute }

    guard let override else {
        return sorted.map {
            ResolvedPeriod(entry: $0, startMinute: $0.startMinute, endMinute: $0.endMinute, isShifted: false)
        }
    }

    // Where the shift starts. An exact period-number match is what the user
    // picked; the >= fallback keeps the day visible if that row was deleted
    // after the override was saved, instead of silently hiding everything.
    let anchor = sorted.firstIndex { $0.periodNumber == override.startPeriodNumber }
        ?? sorted.firstIndex { $0.periodNumber >= override.startPeriodNumber }
        ?? 0

    var cursor = override.startMinute
    var result: [ResolvedPeriod] = []

    // Rows before the anchor are dropped on purpose: on a shortened day the
    // assembly/homeroom before the first real period does not happen at all.
    for (offset, entry) in sorted[anchor...].enumerated() {
        let newEnd = cursor + override.periodLengthMinutes

        if newEnd > 1439 {
            AppLog.warn("Shift", "เวลาล้นเกินเที่ยงคืน หยุดร่นที่คาบ \(entry.periodNumber)")
            // Keep the remaining rows visible at their original times rather
            // than dropping them — losing rows reads as data loss.
            for remaining in sorted[(anchor + offset)...] {
                result.append(ResolvedPeriod(entry: remaining, startMinute: remaining.startMinute, endMinute: remaining.endMinute, isShifted: false))
            }
            return result
        }

        result.append(ResolvedPeriod(entry: entry, startMinute: cursor, endMinute: newEnd, isShifted: true))
        cursor = newEnd
    }

    return result
}
```

Notes:
- **Delete** the whole `if entry.subject?.isBreak == true { ... }` block. Breaks now shift like anything else.
- Update the doc comment above the function to describe the new rules.
- This is display-only. `ScheduleEntry` rows are never mutated, and deleting the override still
  restores the day exactly. Do not change that contract.

### 1.5 File: `Features/Schedule/PeriodShiftSheet.swift`

Add a period picker.

**New state**

```swift
@State private var startPeriodNumber: Int
```

**Available choices** — computed property, unique period numbers of the day in time order:

```swift
/// Period numbers as they appear down the day, de-duplicated but kept in
/// clock order — a school that prints "0" for both homeroom and lunch must
/// still offer that number exactly once.
private var periodChoices: [Int] {
    var seen = Set<Int>()
    return dayEntries
        .sorted { $0.startMinute < $1.startMinute }
        .map(\.periodNumber)
        .filter { seen.insert($0).inserted }
}

/// "คาบ 1 · ฟิสิกส์" — the number alone is ambiguous when a school uses 0
/// for both homeroom and lunch.
private func periodChoiceLabel(_ n: Int) -> String {
    let first = dayEntries.sorted { $0.startMinute < $1.startMinute }.first { $0.periodNumber == n }
    let subject = first?.subject?.name ?? first?.subjectName ?? ""
    return subject.isEmpty ? "คาบ \(n)" : "คาบ \(n) · \(subject)"
}
```

**`init` changes**

- If `existing != nil`: `startPeriodNumber = existing.startPeriodNumber`.
- Otherwise: default to the first period number of the day that is **not** a break
  (`dayEntries.sorted { $0.startMinute < $1.startMinute }.first { $0.subject?.isBreak != true }?.periodNumber ?? 1`).
- Keep the existing `initialStartMinute` / `initialLength` logic, but base it on the entry that
  matches `startPeriodNumber` instead of `firstReal`, so the time field pre-fills with that row's
  real start time.
- `init` runs before `self` is usable, so compute the sorted array into a local `let` first. Do not
  call the computed properties above from `init`.

**`infoSection` — add above the `DatePicker`:**

```swift
Picker("เริ่มร่นที่คาบ", selection: $startPeriodNumber) {
    ForEach(periodChoices, id: \.self) { n in
        Text(periodChoiceLabel(n)).tag(n)
    }
}
```

And add a footer/caption under the section explaining the hide rule:

```swift
Text("คาบก่อนหน้าคาบที่เลือกจะไม่แสดงในวันนี้")
    .font(.caption)
    .foregroundStyle(Theme.Colors.textSecondary)
```

**`previewPeriods`** — pass the new field:

```swift
let previewOverride = DayScheduleOverride(
    date: targetDate,
    startPeriodNumber: startPeriodNumber,
    startMinute: startMinuteValue,
    periodLengthMinutes: length
)
```

The preview will now automatically show the hidden rows disappearing, because it calls the same
`apply`. Do not add a second formula here.

**`previewRow`** — the `"(ไม่ร่น)"` marker now only appears in the midnight-overflow case. Leave it.
But the label should show the subject name for break rows *and* period rows the same way; simplify to:

```swift
Text(period.entry.periodNumber == 0
     ? (period.entry.subject?.name ?? period.entry.subjectName)
     : "คาบ \(period.entry.periodNumber)")
```

**`confirmShift()`**

- Write `startPeriodNumber` on both the create and the update path.
- Replace the impacted/break counts in the log with the new meaning:

```swift
let resolved = previewPeriods
let hiddenCount = dayEntries.count - resolved.count
AppLog.action("Shift", "ร่นคาบ \(targetDate.thaiDayMonthYearString) · เริ่มคาบ \(startPeriodNumber) เวลา \(startMinuteValue.asClockString) · คาบละ \(length) นาที · ร่น \(resolved.count) คาบ · ซ่อน \(hiddenCount) คาบ")
```

**`#Preview`** — update the `DayScheduleOverride` construction if you changed the init order.

### 1.6 File: `Features/Schedule/PeriodShiftBanner.swift`

Line 22, change the label so the user can see the anchor without opening the sheet:

```swift
Text("วันนี้ร่นคาบ · เริ่มคาบ \(override.startPeriodNumber) \(override.startMinute.asClockString) · คาบละ \(override.periodLengthMinutes) นาที")
```

Update the `#Preview` constructor too.

### 1.7 Also check

`grep -rn "DayScheduleOverride(" PrototypeApp/` — every construction site needs the new parameter
(or relies on its default). Fix them all.

---

## 2. Task 2 — แนะแนว / ชุมนุม are subjects, not breaks. Korean → Activities.

### 2.1 Agreed classification

| Label | Classification |
|---|---|
| โฮมรูม | break (`isBreak = true`) |
| พักกลางวัน / พัก… | break |
| แนะแนว | **normal subject** (has a period number, gets shifted) |
| ชุมนุม | **normal subject** |
| กิจกรรมในเครื่องแบบ | **normal subject** |
| ลูกเสือ / เนตรนารี / ยุวกาชาด | **normal subject** |

This also makes the OCR path agree with `PrototypeAppApp.seedBuiltInSubjects`, which already seeds
ชุมนุม and กิจกรรมในเครื่องแบบ with `isBreak: false`.

### 2.2 File: `Core/Schedule/ThaiSubjectCatalog.swift`

**(a) Shrink `breakKeywords`** (around line 200):

```swift
private static let breakKeywords = ["พัก", "กลางวัน", "โฮมรูม"]
```

Update the doc comment above `isBreakLabel` — the examples that mention กิจกรรม are no longer right.

**(b) Rename the `korean` strand to `activity`.**

Few asked to remove ภาษาเกาหลี and put แนะแนว in its place. The leading consonant `ก` in Thai school
codes is in practice used for กิจกรรมพัฒนาผู้เรียน (ก20901 แนะแนว, ก20902 ชุมนุม), so this is a
correct change, not just a cosmetic one.

In `enum ThaiSubjectStrand`:

- Case list: replace `korean` with `activity`.
- `letter`: `case .activity: return "ก"` (same letter, was korean's).
- `displayName`: `case .activity: return "กิจกรรมพัฒนาผู้เรียน"`.
- `iconName`: remove `.korean` from the `globe` group; add `case .activity: return "person.3.fill"`.
- `colorHex`: change `case .career, .korean:` to `case .career, .activity:` (keeps `9C27B0`).
- `commonSubjects`: remove `.korean` from the `[displayName]` group and add:

```swift
case .activity:
    return ["แนะแนว", "ชุมนุม", "กิจกรรมในเครื่องแบบ", "ลูกเสือ-เนตรนารี", "ยุวกาชาด", "บำเพ็ญประโยชน์"]
```

**(c) `generatedName`** — "กิจกรรมพัฒนาผู้เรียนพื้นฐาน" is not a real thing. Special-case it:

```swift
static func generatedName(for parsed: ParsedSubjectCode) -> String {
    guard parsed.strand != .activity else { return parsed.strand.displayName }
    return parsed.strand.displayName + (parsed.isAdditional ? "เพิ่มเติม" : "พื้นฐาน")
}
```

**(d) `nameOverrides`** — add icons so the new common subjects do not all fall back to the generic one:

```swift
"แนะแนว": ("signpost.right.fill", .activity),
"ชุมนุม": ("person.3.fill", .activity),
"กิจกรรมในเครื่องแบบ": ("figure.hiking", .activity),
"ลูกเสือ-เนตรนารี": ("figure.hiking", .activity),
"ยุวกาชาด": ("cross.case.fill", .activity),
```

### 2.3 Safety checks before you commit this

- `grep -rn "korean" PrototypeApp/` — the only current use is inside `ThaiSubjectCatalog.swift` itself.
  Confirm this is still true after your edit.
- `ThaiSubjectStrand.rawValue` is **not** persisted anywhere (it is only used for `id`), so renaming
  the case is safe and needs no migration. Verify with grep before you rely on it.
- Confirm `SubjectCodeValidator` still accepts `ก` as a leading consonant — it did for korean, so it
  should, but check rather than assume.

### 2.4 Existing data

Subjects already created by an earlier import with `isBreak = true` (e.g. an old "ชุมนุม") will keep
that flag. **Do not write a migration for this.** Mention it to Few in your final message and let him
decide — he can fix it by hand or reset data.

---

## 3. Task 3 — One shared subject picker for both edit screens

### 3.1 The problems Few reported

1. In `ScheduleImportRowEditSheet` (fix a row read from a photo), the "วิชาที่พบบ่อย" dropdown only
   appears `if let strand`, and `strand` comes from parsing the subject code. **A cell with no code
   gets no dropdown at all** — the user has to type the whole subject name by hand.
2. `AddScheduleEntrySheet` (edit a row in the timetable) has no subject/category picker at all. It
   only offers the list of already-created `Subject` rows.
3. The two screens look nothing alike.

### 3.2 New file: `Features/Schedule/SubjectPickerFields.swift`

This renders **only the rows**, not the `Section` wrapper, so each caller can add its own extra rows
above/below and still get identical-looking controls.

```swift
//
//  SubjectPickerFields.swift
//  The two-level subject chooser (กลุ่มสาระ → รายวิชา) shared by
//  AddScheduleEntrySheet and ScheduleImportRowEditSheet. One file so the two
//  screens cannot drift apart — Few asked for them to look the same.
//
//  Renders Form rows only, never a Section, so each caller can add its own
//  extra rows (OCR code options, the existing-Subject picker) beside these.
//

struct SubjectPickerFields: View {
    @Binding var name: String
    @Binding var code: String

    /// Called when the user actively changes the name/code, so a caller that
    /// tracks "this was guessed" flags can clear the right one. nil when the
    /// caller has no such flags.
    var onNameEdited: (() -> Void)? = nil
    var onCodeEdited: (() -> Void)? = nil

    /// nil = "อื่นๆ / ไม่ระบุ" — the free-text name field is the answer instead.
    @State private var strandChoice: ThaiSubjectStrand?
    /// nil = "อื่นๆ (พิมพ์เอง)".
    @State private var nameChoice: String?

    var body: some View { ... }
}
```

**Rows, in this order:**

1. `Picker("กลุ่มสาระ", selection: $strandChoice)` — first item `Text("อื่นๆ / ไม่ระบุ").tag(ThaiSubjectStrand?.none)`,
   then `ForEach(ThaiSubjectStrand.allCases)` with `.tag(ThaiSubjectStrand?.some(strand))`.
2. `if let strandChoice` → `Picker("รายวิชา", selection: $nameChoice)` — first item
   `Text("อื่นๆ (พิมพ์เอง)").tag(String?.none)`, then `strandChoice.commonSubjects`.
3. `TextField("ชื่อวิชา", text: $name)` — **always visible and always editable**. The typed name always wins.
4. `TextField("รหัสวิชา", text: $code).autocorrectionDisabled()`.

**Sync rules — implement exactly these, in this order. Getting them wrong causes an update loop.**

| Trigger | Action |
|---|---|
| `.onAppear` | `strandChoice = ThaiSubjectCatalog.parse(code)?.strand`. Then `nameChoice = (strandChoice?.commonSubjects.contains(name) == true) ? name : nil`. |
| `.onChange(of: code)` | Call `onCodeEdited?()`. If `ThaiSubjectCatalog.parse(code)?.strand` is non-nil **and different from** `strandChoice`, assign it to `strandChoice`. Never clear `strandChoice` just because the code became invalid. |
| `.onChange(of: strandChoice)` | If the new strand's `commonSubjects` does **not** contain the current `name`, set `nameChoice = nil`. **Never wipe `name`.** |
| `.onChange(of: nameChoice)` | If non-nil: `name = nameChoice!` and call `onNameEdited?()`. If nil: do nothing. |
| `.onChange(of: name)` | Call `onNameEdited?()`. If `name != nameChoice`, set `nameChoice = nil` — but only when they actually differ, otherwise rule 4 and rule 5 ping-pong forever. |

### 3.3 Also move the period-number control into that file

`AddScheduleEntrySheet` has a nice `Picker("คาบที่")` with a "กำหนดเอง" escape hatch;
`ScheduleImportRowEditSheet` has a bare `TextField`. Few wants them identical, so extract the good one.

In the same new file (or a second new file `PeriodNumberField.swift`, your choice — keep it to one
new concept per file):

```swift
enum PeriodChoice: Hashable {
    case number(Int)
    case custom
}

/// The "คาบที่" control. Two rows, not one, because the custom field only
/// appears when it is needed.
struct PeriodNumberField: View {
    @Binding var periodNumber: Int
    @State private var choice: PeriodChoice = .number(0)
    @State private var customText: String = ""
    ...
}
```

- Range `0...10` in the picker, plus `Text("กำหนดเอง").tag(PeriodChoice.custom)`.
- `.onAppear`: if `(0...10).contains(periodNumber)` → `.number(periodNumber)`, else `.custom` with
  `customText = String(periodNumber)`.
- `.onChange(of: choice)` and `.onChange(of: customText)` both write back into `periodNumber`.
  When `.custom` and `Int(customText)` is nil, leave `periodNumber` unchanged (do not zero it).
- Delete the old `private enum PeriodChoice` from `AddScheduleEntrySheet.swift`.

### 3.4 File: `Features/Schedule/ScheduleImportRowEditSheet.swift`

Replace `subjectSection` with:

```swift
private var subjectSection: some View {
    Section("วิชา") {
        if !period.codeOptions.isEmpty {
            Picker("รหัสที่อ่านได้", selection: $draft.subjectCode) {
                ForEach(codeChoices, id: \.self) { Text($0).tag($0) }
            }
        }

        SubjectPickerFields(
            name: $draft.subjectName,
            code: $draft.subjectCode,
            onNameEdited: { draft.nameIsGuessed = false },
            onCodeEdited: { draft.codeNeedsReview = false }
        )

        if draft.nameIsGuessed {
            hint("ชื่อวิชานี้เดามาจากรหัส ตรวจให้ตรงกับที่เรียนจริง", color: Theme.Colors.warning)
        }
    }
}
```

Then:
- **Delete** `@State private var commonChoice: String?` and the `private var strand` computed property.
  They now live inside `SubjectPickerFields`.
- Keep `codeChoices` — it is OCR-specific and stays here.
- In `timeSection`, replace `TextField("คาบที่", text: $periodText)` with
  `PeriodNumberField(periodNumber: $draft.periodNumber)` and delete the `periodText` state and the
  `result.periodNumber = Int(periodText...)` line in `save()` (the binding already wrote it).
- `detailSection`: rename the toggle label from `"เป็นคาบพัก / กิจกรรม"` to `"เป็นคาบพัก (โฮมรูม / พักกลางวัน)"`
  — activities are no longer breaks (Task 2).
- The `if result.isBreak { codeNeedsReview = false; nameIsGuessed = false }` logic in `save()` is
  still correct. Leave it.

### 3.5 File: `Features/Schedule/AddScheduleEntrySheet.swift`

This file already carries a comment warning that the `Form` body is near SwiftUI's type-check
budget. **Keep every section as its own computed property and put `.onChange` modifiers on the
sections, not on the `Form`.** Do not inline anything.

**Section order — change it to match the import sheet:**

```
scanSection      (add mode only, unchanged)
subjectSection   ← "วิชา"
timeSection      ← "เวลา"  (วัน + คาบที่ + เวลาเริ่ม + เวลาสิ้นสุด + overlap warning)
detailSection    ← "รายละเอียด"  (ชื่อครู + ห้องเรียน)
deleteSection    (edit mode only, unchanged)
```

Delete the old `dayAndPeriodSection` and fold วัน + คาบที่ into `timeSection`.

**State changes**

Replace `@State private var selectedSubject: Subject?` with three pieces of state:

```swift
@State private var subjectName: String
@State private var subjectCode: String
/// The Subject the user picked from the existing list, when they did. Cleared
/// as soon as the name stops matching, so the picker never claims a row it no
/// longer describes.
@State private var pickedExisting: Subject?
```

`init`:

```swift
_subjectName    = State(initialValue: editing?.subject?.name ?? editing?.subjectName ?? "")
_subjectCode    = State(initialValue: editing?.subject?.code ?? "")
_pickedExisting = State(initialValue: editing?.subject)
```

Also replace `periodChoice` / `customPeriodText` state with a single
`@State private var periodNumber: Int`, initialised to `editing?.periodNumber ?? 0`, now that
`PeriodNumberField` owns the picker/custom logic.

**`subjectSection`:**

```swift
private var subjectSection: some View {
    Section("วิชา") {
        Picker("เลือกจากวิชาที่มีอยู่", selection: $pickedExisting) {
            Text("— ไม่เลือก —").tag(Subject?.none)
            ForEach(subjects) { subject in
                Text(subject.name).tag(Subject?.some(subject))
            }
        }

        SubjectPickerFields(name: $subjectName, code: $subjectCode)

        Button {
            isAddingSubject = true
        } label: {
            Label("เพิ่มวิชาใหม่", systemImage: "plus.circle.fill")
        }
    }
    .onChange(of: pickedExisting) { _, new in
        guard let new else { return }
        subjectName = new.name
        subjectCode = new.code
    }
    .onChange(of: subjectName) { _, new in
        // Typing a different name means the user has left the picked subject
        // behind; keeping the picker highlighted would be a lie.
        if let picked = pickedExisting, picked.name.caseInsensitiveCompare(new) != .orderedSame {
            pickedExisting = nil
        }
    }
}
```

The existing `.sheet(isPresented: $isAddingSubject)` callback must now set all three:

```swift
AddSubjectSheet { subject in
    pickedExisting = subject
    subjectName = subject.name
    subjectCode = subject.code
}
```

**`canSave`:**

```swift
private var canSave: Bool {
    !subjectName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        && endMinuteValue > startMinuteValue
}
```

(`periodNumber` is now always a valid `Int`, so drop the `periodNumberValue != nil` check and the
`periodNumberValue` computed property.)

**`save()`** — resolve or create the `Subject` instead of force-unwrapping a picked one:

```swift
guard let subject = ScheduleConstants.resolveSubject(
    named: subjectName, code: subjectCode, in: context
) else { return }
```

Everything below that (assigning to `editing` or building a new `ScheduleEntry`) stays the same,
using `periodNumber` directly.

### 3.6 File: `Features/Schedule/ScheduleConstants.swift`

Add a new helper **next to** the existing `findOrCreateSubject`. **Do not change
`findOrCreateSubject`'s signature** — `grep -rn "findOrCreateSubject" PrototypeApp/` first and
confirm what still calls it (onboarding does).

```swift
/// Finds the Subject a hand-edited schedule row means, or creates it. Code
/// wins over name, matching ScheduleImportCommitter's rule, so a row typed
/// with a code lands on the same Subject a photo import would have found.
/// Colour and icon come from ThaiSubjectCatalog so a manually typed subject
/// looks the same as an imported one.
/// Returns nil for a blank name.
static func resolveSubject(named: String, code: String, in context: ModelContext) -> Subject? {
    let name = named.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !name.isEmpty else { return nil }
    let code = code.trimmingCharacters(in: .whitespacesAndNewlines)

    let existing = (try? context.fetch(FetchDescriptor<Subject>())) ?? []

    if !code.isEmpty,
       let match = existing.first(where: { !$0.code.isEmpty && $0.code.caseInsensitiveCompare(code) == .orderedSame }) {
        return match
    }
    if let match = existing.first(where: { $0.name.caseInsensitiveCompare(name) == .orderedSame }) {
        // Fill in a code the user has now supplied, but never overwrite one.
        if !code.isEmpty, match.code.isEmpty { match.code = code }
        return match
    }

    let look = ThaiSubjectCatalog.appearance(
        strand: ThaiSubjectCatalog.parse(code)?.strand,
        name: name
    )
    let subject = Subject(name: name, code: code, colorHex: look.colorHex, iconName: look.iconName)
    context.insert(subject)
    AppLog.action("Subject", "สร้างวิชาจากฟอร์มคาบ: \(name) (\(code))")
    return subject
}
```

`isBreak` is deliberately left `false` here. A break subject is created through
`AddSubjectSheet`'s "เป็นช่วงพัก" toggle or through the import path, not by typing a name.

**Do not touch `ScheduleImportCommitter.resolveSubject`.** It has its own `inout` cache for
performance and PROJECT_MAP names it the single write point for imports. The duplication is
intentional for now; note it as follow-up debt if you like, but do not refactor it in this change.

---

## 4. Update `claude plan/PROJECT_MAP.md` in the same commit

At minimum:

- §2 file tree: add `SubjectPickerFields.swift` (and `PeriodNumberField.swift` if you split it) under
  `Features/Schedule/`.
- §2: update the `PeriodShiftCalculator` line — breaks are now shifted, not skipped.
- §3: `DayScheduleOverride` row — mention `startPeriodNumber` and that rows before it are hidden.
- §2 `ThaiSubjectCatalog` line — 13 strands, but `korean` is now `activity`.
- §8 technical debt: add "resolveSubject logic exists twice (ScheduleConstants + ScheduleImportCommitter)".

---

## 5. Definition of done — what Few will click

Give him these exact steps in your final message:

1. **Shift, basic** — ตารางเรียน tab → clock button in the toolbar → set **เริ่มร่นที่คาบ = 1**,
   **คาบแรกเริ่ม = 09:20**, **คาบละ = 40 นาที**.
   The preview list must show คาบ 1 = 09:20–10:00, คาบ 2 = 10:00–10:40, and **โฮมรูม / คาบ 0 must be
   gone from the list entirely**.
2. **Shift, saved** — tap ยืนยันร่นคาบ. Back on the timetable, the times must match the preview
   exactly, and the banner must read "เริ่มคาบ 1 09:20 · คาบละ 40 นาที".
3. **Shift, break shrinks** — on a day with พักกลางวัน, confirm the lunch row now also shows a
   40-minute block and everything after it follows on.
4. **Shift, restore** — tap คืนค่าเดิม. Every row, including the hidden โฮมรูม, must come back at its
   original time.
5. **Timetable subject picker** — tap any period row → the form must show **กลุ่มสาระ → รายวิชา**.
   Choose กิจกรรมพัฒนาผู้เรียน → แนะแนว, save, and the row must show แนะแนว.
6. **Import subject picker** — เพิ่มคาบเรียน (`+`) → ถ่ายตารางสอน → in the review sheet tap a row that
   has **no** subject code. The กลุ่มสาระ and รายวิชา dropdowns must be there (before this change
   there was nothing at all).
7. **Both screens look the same** — วิชา / เวลา / รายละเอียด sections in the same order, same
   "คาบที่" control, in both the timetable edit sheet and the import edit sheet.
8. **No Korean** — anywhere a strand list is shown, ภาษาเกาหลี must be gone and
   กิจกรรมพัฒนาผู้เรียน must be there instead.

---

## 6. Commit

Only commit after Few confirms the build is green. If you commit before that, prefix the message
with `wip:`. Thai commit messages are fine:

```
fix: แก้ระบบร่นคาบ + ตัวเลือกวิชา 2 ชั้นใช้ร่วมกัน 2 หน้า

- ร่นคาบ: เพิ่ม startPeriodNumber, ซ่อนคาบก่อนหน้า, ร่นคาบพักด้วย
- แนะแนว/ชุมนุม/กิจกรรม เป็นวิชาปกติ (ไม่ใช่คาบพัก)
- เปลี่ยน strand ภาษาเกาหลี → กิจกรรมพัฒนาผู้เรียน
- SubjectPickerFields ใช้ร่วมกันทั้งหน้าแก้คาบและหน้าแก้ผล import
```

---

## 7. If you get stuck

- Read the **whole** error before changing anything. Do not fix line 1 and guess the rest.
- `unable to type-check this expression in reasonable time` in SwiftUI means **split the body into
  smaller sub-views**, not a syntax fix. `AddScheduleEntrySheet` is the likely place.
- Same error twice in a row on the same line → **stop, explain where you are stuck, and ask.**
  Do not keep guessing.
