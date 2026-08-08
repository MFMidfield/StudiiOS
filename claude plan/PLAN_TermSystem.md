# PLAN — Term System (ระบบชุดตารางสอนแยกเทอม)

> Written for a Sonnet implementation session. Simple English on purpose.
> Read `PROJECT_MAP.md` first. Read this file second. Do not start coding until §9 is understood.
> Created: 2026-08-09

---

## 0. Goal

Right now the app has **one single timetable**. All `ScheduleEntry` rows live in one flat list.

We want **one timetable per term**: ม.1 เทอม 1, ม.1 เทอม 2, … up to ม.6 เทอม 2 (12 possible term slots).
The user picks which term is "active". The whole app then shows only that term's data.

This is the foundation for a future GPA system, so the data model must already be able to answer:
*"which subjects did the student take in ม.4 เทอม 1, how many credits, what grade?"*

---

## 1. Decisions already locked (do not re-litigate)

| # | Decision | Value |
|---|---|---|
| D1 | `Subject` stays a **global catalog** | One `Subject` row is reused across every term. Same name, same code, same colour, same icon everywhere. |
| D2 | New join model `TermSubject` | Links one `Term` to one `Subject`, and carries `creditHours` + `gradePoint`. This is the row a GPA screen will read later. |
| D3 | No academic year (พ.ศ.) field | A `Term` is only **grade level + term number**. `ม.4 เทอม 1` exists exactly once. |
| D4 | Terms are created **lazily** | The DB starts with zero `Term` rows. The dropdown lists 12 fixed choices from Swift code. A `Term` row is inserted only the first time the user picks it. |
| D5 | Term-scoped models | `ScheduleEntry`, `Assignment`, `GradeComponent` |
| D6 | NOT term-scoped | `DayScheduleOverride`, `Subject`, `Note`, `CalendarEvent`, `PortfolioItem`, `FocusSession`, `TCASEntry`, `SemesterRecord` (see §8 for why) |
| D7 | Rows with `term == nil` | Get **auto-adopted into the active term** on app launch. Nothing is ever hidden because of a missing term. |
| D8 | Term switcher UI | The clock button in `ScheduleView`'s toolbar becomes a **gear button** that opens a new `ScheduleSettingsSheet`. "ร่นคาบ" becomes a row inside that sheet. |
| D9 | Existing local data | Few will **delete the app and reinstall**. No backfill migration code is needed. Still write every new field as optional / with a default so a stale store does not crash. |

---

## 2. New data model

### 2.1 `Term` — `Core/Models/Term.swift` (NEW FILE)

```swift
import Foundation
import SwiftData

/// Which half of Thai secondary school a grade level belongs to.
/// Used only to split the term picker into two dropdowns.
enum SchoolBand: String, CaseIterable, Identifiable {
    case lower   // ม.ต้น — ม.1, ม.2, ม.3
    case upper   // ม.ปลาย — ม.4, ม.5, ม.6

    var id: String { rawValue }
    var label: String { self == .lower ? "ม.ต้น" : "ม.ปลาย" }
    var gradeLevels: [Int] { self == .lower ? [1, 2, 3] : [4, 5, 6] }

    static func containing(gradeLevel: Int) -> SchoolBand {
        gradeLevel <= 3 ? .lower : .upper
    }
}

/// One school term: a grade level (ม.1–ม.6) plus a term number (1 or 2).
/// Every timetable, task and score sheet hangs off exactly one of these.
///
/// There is no academic-year field on purpose (decision D3): a student passes
/// through each of the 12 slots exactly once, so `gradeLevel + termNumber`
/// is already unique for one student.
@Model
final class Term {
    /// Stable id. Stored (as a string) in @AppStorage to remember the active term.
    /// SwiftData's PersistentIdentifier is not safe to persist in UserDefaults,
    /// so we carry our own UUID.
    var id: UUID = UUID()

    /// 1...6 → ม.1 ... ม.6
    var gradeLevel: Int = 4
    /// 1 or 2
    var termNumber: Int = 1
    var createdAt: Date = Date.now

    init(gradeLevel: Int, termNumber: Int, id: UUID = UUID(), createdAt: Date = .now) {
        self.id = id
        self.gradeLevel = gradeLevel
        self.termNumber = termNumber
        self.createdAt = createdAt
    }

    /// "ม.4 เทอม 1"
    var displayName: String { "ม.\(gradeLevel) เทอม \(termNumber)" }

    var band: SchoolBand { SchoolBand.containing(gradeLevel: gradeLevel) }

    /// Chronological order: ม.1เทอม1 = 11 … ม.6เทอม2 = 62.
    /// Use this for every `sort:` on Term. It is a stored-value computation,
    /// so it CANNOT be used inside a #Predicate — sort in Swift instead.
    var sortKey: Int { gradeLevel * 10 + termNumber }
}
```

> **Trap:** do not add `@Relationship` arrays (`var entries: [ScheduleEntry]`) to `Term`.
> Inverse relationships plus cascade delete rules are the easiest way to corrupt this store.
> Children point *up* to the term (`var term: Term?`) and deletion is done manually in `TermStore.delete`.

### 2.2 `TermSubject` — `Core/Models/TermSubject.swift` (NEW FILE)

```swift
import Foundation
import SwiftData

/// "This subject was taken in this term."
/// Created automatically whenever a ScheduleEntry for a subject is saved into a term.
/// `creditHours` and `gradePoint` are filled in later by the GPA feature — this round
/// only creates the rows and leaves the numbers at their defaults.
@Model
final class TermSubject {
    var term: Term?
    var subject: Subject?

    /// หน่วยกิต. 0 means "not entered yet".
    var creditHours: Double = 0
    /// Thai 0–4 scale. nil means "no grade yet".
    var gradePoint: Double?
    var createdAt: Date = Date.now

    init(term: Term?, subject: Subject?, creditHours: Double = 0, gradePoint: Double? = nil) {
        self.term = term
        self.subject = subject
        self.creditHours = creditHours
        self.gradePoint = gradePoint
    }
}
```

**This round does NOT build any UI for `TermSubject`.** It only:
- gets created when a schedule entry lands in a term (see §4.4)
- gets deleted when its term is deleted

### 2.3 Fields added to existing models

All three are **optional relationships with no default value needed** — SwiftData backfills them as `nil`.

| File | Add |
|---|---|
| `Core/Models/ScheduleEntry.swift` | `var term: Term?` + `term: Term? = nil` as the **last** `init` parameter |
| `Core/Models/Assignment.swift` | `var term: Term?` + `term: Term? = nil` as the **last** `init` parameter |
| `Core/Models/GradeComponent.swift` | `var term: Term?` + `term: Term? = nil` as the **last** `init` parameter |

> Add the parameter **at the end** of each `init` so every existing call site keeps compiling untouched.

---

## 3. New file: `Core/Schedule/TermStore.swift`

This is the only place that knows how to find, create, switch and delete terms.
No view is allowed to write `activeTermID` or insert a `Term` by itself.

```swift
import Foundation
import SwiftData

enum TermStore {

    /// The @AppStorage key holding the active term's UUID string.
    /// Views read it with `@AppStorage(TermStore.activeTermKey)`.
    static let activeTermKey = "com.studentos.activeTermID"

    /// All 12 slots the picker can offer, in chronological order.
    /// These are NOT database rows (decision D4) — just the menu.
    static let allSlots: [(gradeLevel: Int, termNumber: Int)] =
        (1...6).flatMap { level in [1, 2].map { (level, $0) } }

    /// The slot a brand-new install starts on.
    static let defaultSlot = (gradeLevel: 4, termNumber: 1)

    // MARK: - Reading

    /// Finds the Term matching the saved id string. Returns nil if nothing matches.
    static func find(idString: String, in terms: [Term]) -> Term? {
        guard let uuid = UUID(uuidString: idString) else { return nil }
        return terms.first { $0.id == uuid }
    }

    static func find(gradeLevel: Int, termNumber: Int, in context: ModelContext) -> Term? {
        let all = (try? context.fetch(FetchDescriptor<Term>())) ?? []
        return all.first { $0.gradeLevel == gradeLevel && $0.termNumber == termNumber }
    }

    // MARK: - Writing

    /// Returns the Term for this slot, inserting it if it does not exist yet (D4).
    @discardableResult
    static func findOrCreate(gradeLevel: Int, termNumber: Int, in context: ModelContext) -> Term {
        if let existing = find(gradeLevel: gradeLevel, termNumber: termNumber, in: context) {
            return existing
        }
        let term = Term(gradeLevel: gradeLevel, termNumber: termNumber)
        context.insert(term)
        AppLog.action("Term", "สร้างเทอมใหม่: \(term.displayName)")
        return term
    }

    /// Makes this term active. Writes the id straight into UserDefaults so it can
    /// be called from non-View code; @AppStorage in views picks the change up.
    static func setActive(_ term: Term) {
        UserDefaults.standard.set(term.id.uuidString, forKey: activeTermKey)
        AppLog.action("Term", "สลับไปเทอม \(term.displayName)")
    }

    /// Called once from RootContainerView.task. Guarantees three things:
    ///   1. an active term always exists (creates the default slot on a fresh install)
    ///   2. every ScheduleEntry / Assignment / GradeComponent with term == nil
    ///      is adopted into the active term (decision D7)
    ///   3. TermSubject rows exist for every subject used by the active term
    /// Safe to call repeatedly.
    static func bootstrap(in context: ModelContext) {
        let terms = (try? context.fetch(FetchDescriptor<Term>())) ?? []
        let savedID = UserDefaults.standard.string(forKey: activeTermKey) ?? ""

        let active: Term
        if let found = find(idString: savedID, in: terms) {
            active = found
        } else if let firstExisting = terms.sorted(by: { $0.sortKey < $1.sortKey }).first {
            active = firstExisting
            setActive(active)
        } else {
            active = findOrCreate(gradeLevel: defaultSlot.gradeLevel,
                                  termNumber: defaultSlot.termNumber,
                                  in: context)
            setActive(active)
        }

        adoptOrphans(into: active, in: context)
        syncTermSubjects(for: active, in: context)
        try? context.save()
    }

    /// D7: anything with no term joins the active term.
    static func adoptOrphans(into term: Term, in context: ModelContext) {
        var adopted = 0
        for e in (try? context.fetch(FetchDescriptor<ScheduleEntry>())) ?? []
            where e.term == nil { e.term = term; adopted += 1 }
        for a in (try? context.fetch(FetchDescriptor<Assignment>())) ?? []
            where a.term == nil { a.term = term; adopted += 1 }
        for g in (try? context.fetch(FetchDescriptor<GradeComponent>())) ?? []
            where g.term == nil { g.term = term; adopted += 1 }
        if adopted > 0 {
            AppLog.action("Term", "ดึงข้อมูลไม่ระบุเทอม \(adopted) รายการเข้า \(term.displayName)")
        }
    }

    /// Makes sure every Subject used by this term's schedule has a TermSubject row.
    /// Never deletes TermSubject rows here — a subject dropped from the timetable
    /// may still hold a grade the student wants to keep.
    static func syncTermSubjects(for term: Term, in context: ModelContext) {
        let entries = ((try? context.fetch(FetchDescriptor<ScheduleEntry>())) ?? [])
            .filter { $0.term?.id == term.id }
        let links = ((try? context.fetch(FetchDescriptor<TermSubject>())) ?? [])
            .filter { $0.term?.id == term.id }

        var linkedIDs = Set(links.compactMap { $0.subject?.persistentModelID })

        for entry in entries {
            guard let subject = entry.subject, !subject.isBreak else { continue }
            guard !linkedIDs.contains(subject.persistentModelID) else { continue }
            context.insert(TermSubject(term: term, subject: subject))
            linkedIDs.insert(subject.persistentModelID)
        }
    }

    /// Deletes a term and everything that belongs to it. Subjects are NEVER deleted
    /// (same rule as ScheduleImportCommitter — Assignment.subjectName is a loose lookup).
    static func delete(_ term: Term, in context: ModelContext) {
        let id = term.id
        for e in (try? context.fetch(FetchDescriptor<ScheduleEntry>())) ?? []
            where e.term?.id == id { context.delete(e) }
        for a in (try? context.fetch(FetchDescriptor<Assignment>())) ?? []
            where a.term?.id == id { context.delete(a) }
        for g in (try? context.fetch(FetchDescriptor<GradeComponent>())) ?? []
            where g.term?.id == id { context.delete(g) }
        for ts in (try? context.fetch(FetchDescriptor<TermSubject>())) ?? []
            where ts.term?.id == id { context.delete(ts) }
        context.delete(term)
        try? context.save()
        AppLog.action("Term", "ลบเทอม \(term.displayName) พร้อมข้อมูลทั้งหมด")
    }
}
```

### 3.1 Filtering helper — put at the bottom of the same file

Every view uses these two so the filter rule exists in exactly one place.

```swift
extension Array where Element == ScheduleEntry {
    /// Rows belonging to this term. A nil term means "show nothing" —
    /// bootstrap() guarantees an active term exists before any view renders.
    func inTerm(_ term: Term?) -> [ScheduleEntry] {
        guard let term else { return [] }
        return filter { $0.term?.id == term.id }
    }
}

extension Array where Element == Assignment {
    func inTerm(_ term: Term?) -> [Assignment] {
        guard let term else { return self }   // never hide tasks (D7)
        return filter { $0.term == nil || $0.term?.id == term.id }
    }
}

extension Array where Element == GradeComponent {
    func inTerm(_ term: Term?) -> [GradeComponent] {
        guard let term else { return self }
        return filter { $0.term == nil || $0.term?.id == term.id }
    }
}
```

> Note the asymmetry, it is deliberate: a schedule row with no term is a bug and should
> not appear; a task or score with no term should still be visible (D7) until bootstrap adopts it.

---

## 4. Edits to existing files

Work through this table top to bottom. Each row is small.

### 4.1 `App/PrototypeAppApp.swift`

1. Add `Term.self` and `TermSubject.self` to the `Schema([...])` array. **Forgetting this crashes the app on launch** (there is a `fatalError`).
2. In `RootContainerView`, add:
   ```swift
   @Environment(\.modelContext) private var context
   ```
   and call bootstrap once when the view appears:
   ```swift
   .task { TermStore.bootstrap(in: context) }
   ```
   Put this **before** the existing `.onChange(of: scenePhase)` modifier.
3. The existing notification refresh must only cover the active term:
   ```swift
   @AppStorage(TermStore.activeTermKey) private var activeTermID = ""
   @Query private var terms: [Term]
   private var activeTerm: Term? { TermStore.find(idString: activeTermID, in: terms) }
   ...
   Task { await NotificationManager.shared.refreshAssignmentReminders(assignments.inTerm(activeTerm)) }
   ```

### 4.2 `Features/Schedule/ScheduleView.swift`

| Change | Detail |
|---|---|
| Add state | `@AppStorage(TermStore.activeTermKey) private var activeTermID = ""` and `@Query private var terms: [Term]` |
| Add computed | `private var activeTerm: Term? { TermStore.find(idString: activeTermID, in: terms) }` |
| Filter | `entriesForSelectedDay` becomes `allEntries.inTerm(activeTerm).filter { $0.dayOfWeek == selectedDay }.sorted { ... }` |
| Toolbar | Replace the clock `Button` with a gear button (`Image(systemName: "gearshape")`) that sets `isShowingScheduleSettings = true`. Keep the `+` button exactly as it is. |
| Sheet | Replace `.sheet(isPresented: $isShiftingPeriods)` with `.sheet(isPresented: $isShowingScheduleSettings) { ScheduleSettingsSheet(...) }`. `PeriodShiftSheet` is now presented **from inside** `ScheduleSettingsSheet`. |
| Nav title | Show the term under the title so the user always knows where they are: use `.navigationTitle("ตารางเรียน")` plus a small `Text(activeTerm?.displayName ?? "")` line in the `ScheduleDayPickerBar` area, or a `ToolbarItem(placement: .principal)` with a two-line VStack. Pick whichever renders cleaner and say which you chose. |
| Empty state | If the term has no entries, the existing `emptyState` is fine. Add the term name to the message: `"ยังไม่มีคาบเรียนใน\(dayLabel) (\(activeTerm?.displayName ?? ""))"`. |

### 4.3 `Features/Schedule/AddScheduleEntrySheet.swift`

1. Add the same `activeTermID` / `terms` / `activeTerm` trio.
2. `overlappingEntry` must compare against `allEntries.inTerm(activeTerm)` only — otherwise ม.5's timetable blocks a slot in ม.4.
3. At line ~353 where `ScheduleEntry(...)` is constructed, pass `term: activeTerm`.
4. In edit mode, **do not touch** `editing.term`. An entry never changes term through this form.
5. After a successful save, call `TermStore.syncTermSubjects(for: activeTerm, in: context)` before `context.save()`.

### 4.4 `Core/Schedule/ScheduleImportCommitter.swift`

This is the destructive one. Read the file header comment first.

1. Change the signature to:
   ```swift
   static func commit(_ periods: [ImportedPeriod], into term: Term, in context: ModelContext) -> Summary
   ```
2. Step 1 (the wipe) must be scoped:
   ```swift
   for entry in existingEntries where days.contains(entry.dayOfWeek) && entry.term?.id == term.id {
   ```
   **This is the single most important line in the whole plan.** Without the term check,
   importing a ม.5 timetable deletes the ม.4 timetable for the same weekdays.
3. Pass `term: term` into the `ScheduleEntry(...)` initialiser.
4. After the insert loop, before `context.save()`, call `TermStore.syncTermSubjects(for: term, in: context)`.
5. Update the file's header comment to say the wipe is now per-term.
6. Update the caller in `AddScheduleEntrySheet` to pass the active term. If `activeTerm` is nil, do not commit — show the existing error path instead.

### 4.5 `Features/Onboarding/ScheduleSetupView.swift`

Around line 210 it inserts `ScheduleEntry` directly. Add the term:
```swift
let term = TermStore.findOrCreate(gradeLevel: TermStore.defaultSlot.gradeLevel,
                                  termNumber: TermStore.defaultSlot.termNumber,
                                  in: context)
TermStore.setActive(term)
```
resolve this **once** before the loop, then pass `term: term` into each `ScheduleEntry(...)`.

Do **not** refactor the rest of this file. It has a known duplicate OCR path
(see PROJECT_MAP §8) — leave that debt alone this round.

### 4.6 `Features/Onboarding/SetupSummaryView.swift`

`scheduleEntries` count should be `scheduleEntries.inTerm(activeTerm).count`. Add the
`activeTermID` / `terms` / `activeTerm` trio here too.

### 4.7 Tasks — `Features/Tasks/`

| File | Change |
|---|---|
| `AssignmentListView.swift` | Add the trio. Every place that reads `assignments` reads `assignments.inTerm(activeTerm)` instead. Do it **once** in a computed `private var scopedAssignments` and use that everywhere in the file — do not sprinkle `.inTerm()` through the chips/stats code. |
| `AddTaskSheet.swift` | Add the trio. When creating a **new** Assignment, pass `term: activeTerm`. When editing, leave `term` untouched. |
| `TaskFilterSheet.swift` | No change (it only queries Subject). |

### 4.8 `Features/Dashboard/DashboardView.swift`

Add the trio; use `assignments.inTerm(activeTerm)` as the source for the
"งานค้าง" / "งานวันนี้" cards. Same rule: compute once into a private var.

### 4.9 `Features/Schedule/ScheduleTodayTasksSection.swift`

Add the trio; filter `allAssignments` through `.inTerm(activeTerm)` before the
existing day/kind filtering.

### 4.10 `Features/GradeCenter/GradeCenterView.swift`

1. Add the trio to `GradeCenterView`.
2. Pass the resolved `activeTerm` down into `GradeBreakdownCard` and
   `TargetScoreCalculatorCard` as a `let term: Term?` property — do not repeat the
   `@Query` in each subview.
3. `components` becomes `components.inTerm(activeTerm)`.
4. `addComponent()` sets `term: activeTerm` on the new `GradeComponent`.
5. Add the term name to the nav title area so it is obvious the scores are per-term.

### 4.11 `Features/Settings/SettingsView.swift`

1. `resetAllData()` — add `deleteAll(TermSubject.self)` and `deleteAll(Term.self)`
   (TermSubject **before** Term). Also clear the active term:
   ```swift
   UserDefaults.standard.removeObject(forKey: TermStore.activeTermKey)
   ```
   Put this next to `StudentProfileStore.shared.reset()`.
   Do **not** re-seed a term here — `TermStore.bootstrap` will do it on the next launch.
2. In the existing `Section("ตารางเรียน")`, add above the toggle:
   ```
   NavigationLink { TermManagementView() } label: {
       LabeledContent("เทอมปัจจุบัน", value: activeTerm?.displayName ?? "—")
   }
   ```

---

## 5. New UI

### 5.1 `Features/Schedule/ScheduleSettingsSheet.swift` (NEW FILE)

Presented from `ScheduleView`'s gear button. A `NavigationStack` + `Form`, medium/large detent.

```
ตั้งค่าตารางสอน                                   [เสร็จ]
──────────────────────────────────────────────
เทอม
  ระดับชั้น        [ ม.ต้น | ม.ปลาย ]        ← Picker(.segmented)
  เทอม            ม.4 เทอม 1            ▾   ← Picker(.menu), 6 rows
  ⓘ ตารางสอน งาน และคะแนน จะแยกเก็บตามเทอม
──────────────────────────────────────────────
วันนี้
  ⏱  ร่นคาบวันนี้                          >   ← opens PeriodShiftSheet
     (ถ้ามี override อยู่แล้ว แสดงบรรทัดย่อยว่าร่นจากคาบไหน)
──────────────────────────────────────────────
  จัดการเทอมทั้งหมด                          >   ← push TermManagementView
```

Rules:
- The **band picker** is local `@State`, initialised from `activeTerm?.band ?? .upper`.
  Changing the band does **not** switch terms by itself — it only changes which 6 rows the
  second picker offers.
- The **term picker** shows all 6 slots of the chosen band (`ม.4 เทอม 1`, `ม.4 เทอม 2`, …).
  Slots that already exist in the DB get a small "•" or the entry count as a trailing label so
  the user can tell which ones already have data. Slots that do not exist yet still appear (D4).
- Selecting a slot calls
  `TermStore.setActive(TermStore.findOrCreate(gradeLevel:termNumber:in:))` then
  `TermStore.syncTermSubjects` + `context.save()`.
- Switching terms must **not** dismiss the sheet. The user should see the picker update.
- "ร่นคาบวันนี้" pushes/presents the **existing** `PeriodShiftSheet` with exactly the
  arguments `ScheduleView` used to pass (`day`, `dayEntries`, `targetDate`, `existing`).
  Those four values are passed **into** `ScheduleSettingsSheet` from `ScheduleView` —
  do not recompute them inside the sheet.

Signature:
```swift
struct ScheduleSettingsSheet: View {
    let day: Int
    let dayEntries: [ScheduleEntry]
    let targetDate: Date
    let existingOverride: DayScheduleOverride?
}
```

### 5.2 `Features/Settings/TermManagementView.swift` (NEW FILE)

A plain `List` pushed from Settings (and from the sheet). Read-only plus delete.

```
เทอมทั้งหมด
──────────────────────────────
ม.4 เทอม 1        12 คาบ · 3 งาน   ✓   ← ✓ = active
ม.4 เทอม 2         0 คาบ · 0 งาน
ม.5 เทอม 1        25 คาบ · 1 งาน
──────────────────────────────
แตะเพื่อสลับเทอม · ปัดซ้ายเพื่อลบ
```

- Shows only terms that **exist in the DB**, sorted by `sortKey`.
- Tapping a row calls `TermStore.setActive` and pops back.
- Swipe-to-delete calls `TermStore.delete`. Show a confirmation alert first, naming the term
  and the counts: `"ลบ ม.4 เทอม 1 — คาบเรียน 12, งาน 3, คะแนน 5 รายการ จะถูกลบถาวร"`.
- **Deleting the active term:** after deletion, call `TermStore.bootstrap(in:)` again so a new
  active term is chosen (or the default is recreated). Never leave `activeTermID` dangling.
- If a user tries to delete the last remaining term, allow it — bootstrap recreates ม.4 เทอม 1.

---

## 6. Order of work

Do these in order. Each step should compile on its own.

| Step | Work | Done when |
|---|---|---|
| 1 | Create `Term.swift` + `TermSubject.swift`. Add both to `Schema`. Add `deleteAll` lines in `resetAllData`. | App launches, nothing visibly changed |
| 2 | Add `var term: Term?` to `ScheduleEntry`, `Assignment`, `GradeComponent` (+ last init param) | Still compiles, nothing changed |
| 3 | Create `TermStore.swift` including the three `inTerm` extensions | Compiles |
| 4 | Wire `TermStore.bootstrap` into `RootContainerView.task` | Console shows `Term · สร้างเทอมใหม่: ม.4 เทอม 1` on first launch |
| 5 | `ScheduleView` + `AddScheduleEntrySheet` + `ScheduleImportCommitter` + `ScheduleSetupView` term scoping | Schedule still works exactly as before (one term) |
| 6 | Build `ScheduleSettingsSheet`, move ร่นคาบ into it, swap the toolbar icon | Gear opens the sheet, ร่นคาบ still works from inside it |
| 7 | Build `TermManagementView` + the Settings row | Can create/switch/delete terms |
| 8 | Assignment + GradeComponent scoping (`AssignmentListView`, `AddTaskSheet`, `DashboardView`, `ScheduleTodayTasksSection`, `GradeCenterView`, `SetupSummaryView`) | Switching term changes tasks and scores too |
| 9 | Update `PROJECT_MAP.md` §2 §3 §4 in the same commit | Map matches reality |

Commit after step 5 and after step 9. Use `wip:` prefix if Few has not confirmed a build yet.

---

## 7. Traps — read before writing code

1. **`Schema([...])`** — missing `Term.self` / `TermSubject.self` = instant `fatalError` on launch.
2. **`resetAllData()`** — missing the two new `deleteAll` lines = orphan rows survive a reset. This has already been forgotten once in this project (Calendar models).
3. **`ScheduleImportCommitter` wipe** — must filter on `entry.term?.id == term.id`. Getting this wrong silently destroys another term's timetable and looks exactly like a normal import.
4. **`sortKey` in `#Predicate`** — `sortKey`, `displayName` and `band` are computed properties. SwiftData predicates cannot see them. Fetch all terms and sort in Swift.
5. **Comparing terms** — always compare `term?.id == other.id` (our own UUID), never `term == other` or `persistentModelID`. Object identity across contexts is not reliable.
6. **No inverse relationships** — do not add `@Relationship(inverse:)` anywhere in this feature.
7. **`Subject` is never deleted** — not on term delete, not anywhere. `Assignment.subjectName` is a loose string lookup and would silently orphan.
8. **Break subjects skip `TermSubject`** — `subject.isBreak == true` must not create a link row, or พักกลางวัน shows up in the GPA later.
9. **Previews** — every `#Preview` using `ModelContainer(for:)` in the Schedule/Tasks/Grade files needs `Term.self` and `TermSubject.self` added to the type list, or the preview crashes. Files affected: `ScheduleView`, `ScheduleTimetableSection`, `SchedulePeriodRow`, `ScheduleBreakRow`, `PeriodShiftSheet`, `AddScheduleEntrySheet`.
10. **Big-file rule** — `SettingsView.swift` (~375) and `DashboardView.swift` (350) are large. Read only the line ranges you need with `Read` + `offset`/`limit`.
11. **Design tokens** — no hardcoded colours or spacing in the two new views. `Theme.Colors.*`, `Theme.Spacing.*` only. All UI text in Thai.

---

## 8. Why some models are NOT term-scoped

| Model | Reason |
|---|---|
| `Subject` | D1 — global catalog. "คณิตศาสตร์เพิ่มเติม" is one row shared by ม.4 and ม.5. Which terms actually used it is answered by `TermSubject`. |
| `DayScheduleOverride` | Keyed on a real calendar date. Only "today" is ever shown, and only one term can be the real current term, so a cross-term leak is cosmetic only. **Known limitation:** if the user switches to a past term while an override exists for today, the shift will also apply to that term's view. Accept for now; note it in PROJECT_MAP §8. |
| `Note`, `CalendarEvent`, `PortfolioItem`, `FocusSession`, `TCASEntry` | Not school-term data. Notes and portfolio items span years by design. |
| `SemesterRecord` | Already has its own `semesterLabel` string and belongs to the GPA round (§9). Do not touch it this round. |

---

## 9. Left for the GPA round (do NOT build now)

- UI to enter `creditHours` and `gradePoint` on each `TermSubject`
- Per-term GPA and cumulative GPAX calculation (one calculator file, no formula duplicated in views)
- Migrating `SemesterRecord.semesterLabel: String` onto a real `Term` relationship
- Linking `GradeComponent` to a `Subject` (right now Grade Center is one flat score sheet per term, not per subject)
- Asking the student their grade level during onboarding instead of defaulting to ม.4 เทอม 1

---

## 10. What Few checks when it is done

1. Delete the app from the simulator/device, then build and run.
2. Finish onboarding. Schedule tab should show a term name (ม.4 เทอม 1).
3. Add 2 periods on วันจันทร์.
4. Gear button → เทอม → switch to **ม.5 เทอม 1**. The timetable should be **empty**.
5. Add 1 different period on วันจันทร์ in ม.5.
6. Switch back to **ม.4 เทอม 1**. The original 2 periods must still be there, unchanged.
7. Gear button → ร่นคาบวันนี้. The old shift sheet should open and still work.
8. Settings → ตารางเรียน → เทอมปัจจุบัน. The list shows both terms with correct counts.
9. Add a task in ม.4, switch to ม.5 — the task should disappear from the Todo screen and the Dashboard, and come back when switching to ม.4.
10. Settings → ล้างข้อมูลทั้งหมด → app returns to Welcome and does not crash.
