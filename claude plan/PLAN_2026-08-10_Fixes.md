# PLAN 2026-08-10 — Multi-system fixes

Simple English plan. 6 tasks, ordered from safest to riskiest.
Nothing is coded yet — waiting for OK.

---

## Task 1 — Remove "เลือกจากวิชาที่มีอยู่" picker

**Where:** `Features/Schedule/AddScheduleEntrySheet.swift` (manual add form)

Checked with grep: this picker exists in **one place only**.
The OCR row editor (`ScheduleImportRowEditSheet`) has no such picker — its only
Picker is "รหัสที่อ่านได้" (OCR code candidates), which is a different thing and stays.

**Edit:**
- Delete the `Picker("เลือกจากวิชาที่มีอยู่", selection: $pickedExisting)` block.
- Delete `@State pickedExisting`, its `.onChange(of: pickedExisting)`, and the
  `pickedExisting`-clearing branch inside `.onChange(of: subjectName)`.
- Check whether `@Query subjects` is still used elsewhere in the file; delete if not.

`SubjectPickerFields` (กลุ่มสาระ → รายวิชา → ชื่อ → รหัส) and the
"เพิ่มวิชาใหม่" button both stay.

**Risk:** low. Pure deletion, no model change.
**How to check:** ตารางสอน → `+` → section "วิชา" has no "เลือกจากวิชาที่มีอยู่" row anymore,
and typing a name + code still saves a period correctly.

---

## Task 2 — Remove ม.ต้น from the term picker

**Where:** `Features/Schedule/ScheduleSettingsSheet.swift`

**Edit:**
- Delete the segmented `Picker("ระดับชั้น", selection: $selectedBand)`.
- Delete `@State selectedBand` and the `.onAppear { selectedBand = ... }`.
- Hardcode the term menu to `SchoolBand.upper.gradeLevels` (ม.4–ม.6 → 6 options).
- Fix the footer text that mentions `selectedBand.label`.
- `termSelection` getter: drop the `activeTerm.band == selectedBand` guard,
  keep returning nil when the active term is not in the list (a ม.ต้น term
  created earlier would otherwise have no matching tag).

**Not touched:** `SchoolBand` enum in `Term.swift` stays — `Term.band` and
`SchoolBand.containing` are used elsewhere. Only the UI drops ม.ต้น.

**Risk:** low, but note: if Few already created a ม.ต้น term on device, it stays
in the database and still shows in `TermManagementView`; it just can't be picked
from this sheet anymore.
**How to check:** ตารางสอน → gear → only one dropdown, listing ม.4 เทอม 1 … ม.6 เทอม 2.

---

## Task 3 — Remove "ตัวอย่างผลลัพธ์" from the period-shift form

**Where:** `Features/Schedule/PeriodShiftSheet.swift`

**Edit:**
- Delete `previewSection` + `previewRow(_:)` and the call site in `body`.
- Delete `previewPeriods` if nothing else uses it (grep first — the save action
  may reuse it).

**Risk:** low.
**How to check:** ตารางสอน → gear → ร่นคาบวันนี้ → no preview section; saving still shifts periods.

---

## Task 4 — Remove "คะแนนรวม" + "คำนวณคะแนนเพื่อให้ถึงเป้าหมาย"

**Where:** `Features/GradeCenter/GradeCenterView.swift`

**Answer to your question — what breaks if we delete everything?**

The UI cards are dead code, safe to delete. The `GradeComponent` **model** is
referenced in 5 more files:

| File | Reference |
|---|---|
| `App/PrototypeAppApp.swift` | in `Schema([...])` |
| `Core/Schedule/TermStore.swift` | 2 fetches in bootstrap/delete + `inTerm` extension |
| `Features/Settings/SettingsView.swift` | `resetAllData()` |
| `Features/Settings/TermManagementView.swift` | `@Query` for the delete-confirm count + preview container |

None of these would break logically — but **removing a `@Model` from `Schema`
is a destructive schema change**. On a device that already has the app
installed, SwiftData can fail to open the store and the app crashes on launch
unless the app is deleted first. With the demo 2–4 weeks away that is not a
trade worth making for dead code.

**Recommendation: delete the UI only, keep the model.**
- Delete `GradeBreakdownCard`, `GradeComponentRow`, `TargetScoreCalculatorCard`,
  `enum ThaiGrading` (grep confirms `ThaiGrading` is used nowhere else)
  — but see Task 5, which may want `ThaiGrading.grades` for the grade selector.
  If so, keep the enum and move it to `Core/Grades/`.
- Delete `@State targetGrade` and the `components` / `allComponents` queries in
  `GradeCenterView`.
- `GradeCenterView.body` becomes: `GPAXSummaryCard` + `TermGradeListSection`.
- Add a one-line comment in `Core/Models/GradeComponent.swift` saying the model
  is kept only for store compatibility and has no UI.

Say the word if you'd rather delete the model too — then Task 4 also requires
"ลบแอปออกจากเครื่อง/simulator ก่อนติดตั้งรุ่นใหม่".

**How to check:** Dashboard → เกรด & GPA → only the GPAX card and the per-term list.

---

## Task 5 — Redesign per-term grade entry (the big one)

### 5.1 New model — `Core/Models/TermGradeSubject.swift`

```swift
@Model final class TermGradeSubject {
    var id: UUID = UUID()
    var term: Term?
    var name: String = ""
    var code: String = ""
    var creditHours: Double = 1.0
    var gradePoint: Double = 2.5
    var sortOrder: Int = 0
    var createdAt: Date = .now
}
```

Separate from `TermSubject` on purpose: `TermStore.syncTermSubjects` rewrites
`TermSubject` rows from the timetable, so a deleted period would silently erase
a grade. `TermGradeSubject` is seeded *from* the timetable once and then owns
its own data.

**Required follow-through (§3 of the skill):**
1. add to `Schema([...])` in `App/PrototypeAppApp.swift`
2. add to `SettingsView.resetAllData()`
3. delete the term's rows inside `TermStore.delete(...)`
4. update `PROJECT_MAP.md` §2 + §3 in the same commit

### 5.2 Term gets one new field

`Term.usesDetailedGrades: Bool = false` — additive with a default, so existing
rows migrate fine (same pattern as `gpa` / `totalCredits`).
Per-term, as you chose.

### 5.3 New screen — `Features/GradeCenter/TermGradeEditView.swift`

Replaces `TermGradeEditSheet` as a **pushed page**, not a sheet.
`TermGradeListSection`'s row changes from `.sheet(isPresented:)` to
`NavigationLink { TermGradeEditView(...) }`. `GradeCenterView` is already inside
a `NavigationStack` (pushed from Dashboard) so no new stack is needed.

Layout:

```
Section (top)   [Toggle] กรอกละเอียด

── toggle OFF (simple, current behaviour) ──
Section  เกรดเฉลี่ยเทอมนี้   TextField, prefilled 2.00 for a new term
Section  หน่วยกิตรวม        TextField (optional)
Section  "จำเกรดเทอมนี้ไม่ได้" → CumulativeGPAXSheet   (unchanged)

── toggle ON (detailed) ──
Section  รายวิชา
    row per subject: ชื่อวิชา · หน่วยกิต (TextField) · เกรด (Stepper, read-only text)
    swipe to delete
    Button "เพิ่มวิชา"
Section  สรุป
    เกรดเฉลี่ย 3.21 · 20.5 นก.   (computed, read-only)
```

**Grade selector:** `Stepper` stepping through the valid Thai grade list
`[0, 1, 1.5, 2, 2.5, 3, 3.5, 4]`, default 2.5, text is not editable.
*(Open question: you said "สูงสุด 4 ต่ำสุด 0" — I'm assuming the Thai 8-step
list, not free 0.5 steps. Tell me if you want plain 0.0→4.0 in 0.5 steps.)*

**Seeding subjects from the timetable:** the first time detailed mode is turned
on for a term with no `TermGradeSubject` rows, copy the distinct subjects from
that term's `ScheduleEntry` rows (name + code, credits 1.0, grade 2.5).
Break periods (`Subject.isBreak`) are skipped. If the term has no timetable,
the list starts empty and "เพิ่มวิชา" is the only way in — exactly as you described.
A "ดึงวิชาจากตารางสอนอีกครั้ง" button re-runs the seed, adding only names that
aren't in the list yet (never deletes).

**Saving:** on save, when `usesDetailedGrades` is true, compute
`term.gpa = Σ(credit × grade) / Σcredit` and `term.totalCredits = Σcredit`.
So `GPAXCalculator`, `GPAXSummaryCard` and the dashboard card need **no changes** —
they keep reading `Term.gpa` / `Term.totalCredits` as they do today.
`TermStore.findOrCreate` remains the only way a `Term` is created.

**Files:**
- new: `Core/Models/TermGradeSubject.swift`, `Features/GradeCenter/TermGradeEditView.swift`
- edit: `Term.swift`, `PrototypeAppApp.swift`, `TermStore.swift`, `SettingsView.swift`,
  `TermGradeListSection.swift`
- delete: `TermGradeEditSheet.swift` (grep first — Settings may open it too)

**Risk:** highest of the six. New `@Model` + a Schema change. If the seed logic
or the Schema entry is wrong the app crashes on launch. I'll do Task 5 in its own
commit, after 1–4 are confirmed building.

**How to check:**
1. Dashboard → เกรด & GPA → tap ม.4 เทอม 1 → it **pushes** a page (no sheet)
2. Toggle off → enter 3.25 / 20 → back → row shows `3.25 · 20.0 นก.`
3. Toggle on → subjects from that term's timetable appear → change credits/grades
   → summary line updates → back → the row shows the computed GPA
4. Pick a term with no timetable → empty list + "เพิ่มวิชา" works
5. GPAX card at the top still shows the same number as before

---

## Task 6 — Green message at GPAX 4.00

**Where:** `Features/GradeCenter/GPAXSummaryCard.swift`

Today `.tight` always prints "ต้องได้เทอมละ 4.00 — เกือบเต็มทุกเทอม" in orange
(`Theme.Colors.warning`), which is wrong when the student is *already* at 4.00.

**Edit:** pass `result.gpax` into `copy(for:)` and `color(for:)`. In the `.tight`
case, when `gpax >= 3.995`:
- text → "ทำได้ดีมากแล้ว รักษาระดับนี้ไว้"
- colour → `Theme.Colors.success`

Everything else in `.tight` is unchanged.

**Risk:** low, display only.
**How to check:** enter 4.00 in every completed term with target 4.00 →
message is green, not orange.

---

## Order and commits

```
commit 1  fix: ลบ UI ที่ไม่ได้ใช้ 4 จุด        Tasks 1, 2, 3, 4
commit 2  fix: ข้อความ GPAX เมื่อได้ 4.00        Task 6
commit 3  feat: กรอกเกรดรายวิชาแบบละเอียด      Task 5 (+ PROJECT_MAP update)
```

Each commit goes to Few for ⌘B before the next one starts.

## Still unanswered

1. Grade selector steps — Thai 8-step list, or free 0.5 steps 0.0–4.0?
2. Simple mode: prefill GPA with 2.00 for a term that has no data yet — correct?
   (Today an empty field means "not entered"; prefilling makes 2.00 the default answer.)
3. Detailed mode credits: default 1.0 per subject, typed as text. Want a stepper there too?
