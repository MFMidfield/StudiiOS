# PLAN_GPA — Level 1: GPAX Tracker

> **Status:** design locked, not implemented
> **Written:** 2026-08-09 · **Scope of this round:** Level 1 only. Levels 2 and 3 are specified at the end but deliberately out of scope.
> **Verified against source:** `Term.swift`, `TermStore.swift`, `SemesterRecord.swift`, `GradeComponent.swift`, `GradeCenterView.swift`, `PrototypeAppApp.swift` (Schema), `GradeReportSetupView.swift`

---

## 0. Why this feature exists

From Few's user survey (~60 respondents):

| Rank | Biggest worry | Count |
|---|---|---|
| 1 | GPAX will not reach my target | 19 |
| 2 | TCAS / A-Level / TGAT-TPAT prep | 15 |
| 3 | Building a portfolio | 12 |

Separately, the single most-wanted feature was assignment reminders (18). So GPAX is not the hook that gets people to install the app — it is the **anxiety that keeps them opening it**. The feature must therefore cost almost nothing to use.

**Product statement:**

> Turn the question "will my GPAX be enough?" into a number the student can act on — without asking them to type anything they do not already have in front of them.

**The one thing that makes this not-a-spreadsheet:** reverse calculation ("you need 3.92 per term"), a target derived from a real university programme, and inputs that come from data the app already holds.

---

## 1. What already exists in the codebase

This is the most important section. Level 1 is mostly wiring, not new architecture.

### 1.1 `Term` — already perfect for this

`Core/Models/Term.swift`

```swift
@Model final class Term {
    var id: UUID
    var gradeLevel: Int    // 1...6  →  ม.1 ... ม.6
    var termNumber: Int    // 1 or 2
    var createdAt: Date
    var displayName: String  // "ม.4 เทอม 1"
    var band: SchoolBand     // .lower (ม.1–3) / .upper (ม.4–6)
    var sortKey: Int         // gradeLevel * 10 + termNumber
}
```

Notes carried over from the existing file that this plan must respect:

- **No academic-year field, on purpose.** A student passes through each of the 12 slots exactly once, so `gradeLevel + termNumber` is already unique. GPAX inherits this for free.
- **Do not add `@Relationship` arrays to `Term`.** Children point up; deletion is manual in `TermStore.delete`.
- `sortKey` is a computed property, so it **cannot be used inside a `#Predicate`**. Sort in Swift.

### 1.2 `TermStore` — the only writer of term state

`Core/Schedule/TermStore.swift`

- `TermStore.activeTermKey` — `@AppStorage` key holding the **browsing** term's UUID
- `TermStore.allSlots` — all 12 `(gradeLevel, termNumber)` pairs, chronological, not DB rows
- `TermStore.findOrCreate(gradeLevel:termNumber:in:)` — lazy row creation
- `TermStore.bootstrap(in:)` — called once from `RootContainerView.task`
- `Array.inTerm(_:)` helpers for `ScheduleEntry`, `Assignment`, `GradeComponent`

**Rule to preserve: no view writes `activeTermID` or inserts a `Term` directly.** Everything GPAX-related goes through `TermStore` too.

### 1.3 What is already in the Schema

`App/PrototypeAppApp.swift:15-34` — 20 models, including `Term`, `TermSubject`, `SemesterRecord`, `GradeComponent`.

### 1.4 `SemesterRecord` — exists but is Level 2, not Level 1

```swift
@Model final class SemesterRecord {
    var semesterLabel: String   // free text, e.g. "ม.4 เทอม 1"  ← not linked to Term
    var subjectName: String
    var creditHours: Double
    var gradePoint: Double
    var isSimulated: Bool
}
```

One row **per subject per term**. Written today only by `Features/Onboarding/GradeReportSetupView.swift`, read by `SetupSummaryView`, cleared by `SettingsView.resetAllData()`.

**Level 1 does not use this model.** It stays exactly as it is. See §9 for the migration path.

### 1.5 `GradeCenterView` — currently Level 3 only

`Features/GradeCenter/GradeCenterView.swift` (191 lines) already contains:

- `GradeBreakdownCard` — per-component `obtained / max` for the active term
- `TargetScoreCalculatorCard` — "what % do I need on the remaining components"
- `enum ThaiGrading` — the 80/75/70/65/60/55/50 cut table

This is a working, term-scoped implementation of **Level 3**. **Do not delete or rewrite it.** Level 1 is added *above* it in the same screen.

### 1.6 What is missing

| Missing | Consequence |
|---|---|
| A per-term GPA + credit total | Cannot compute GPAX at all |
| The student's **real** current term (distinct from the browsing term) | Cannot know how many terms remain |
| A target GPAX | Nothing to reverse-calculate against |
| Pure calculation code | Formulas would end up duplicated inside views |

---

## 2. Locked decisions

| # | Decision | Rationale |
|---|---|---|
| D1 | Level 1 stores **term-level** GPA + credits, not per-subject rows | Both give a mathematically identical GPAX; the term-level form is 2 numbers instead of ~8 rows, and both numbers are already printed on the ปพ.1 |
| D2 | `totalCredits` is **optional**; when absent, assume 20.0 and label the result as an estimate | Refusing to compute without it would produce an empty screen for most users |
| D3 | A "cumulative GPAX" shortcut exists for students who cannot recall individual terms | The cumulative figure is on the ปพ.1 and is the number students actually memorise |
| D4 | Each past term has exactly **one** source of truth | Prevents double counting when a term is later expanded into subjects (Level 2) |
| D5 | GPAX for TCAS counts **ม.4–ม.6 only** (`band == .upper`) | A ม.1–ม.3 user must not silently get a wrong GPAX |
| D6 | Numbers are always displayed with their provenance ("from 4 terms", "estimated") | The number gets copied into real university applications |
| D7 | The **browsing** term (`TermStore.activeTermKey`) and the **student's current** term are separate values | The user switches the browsing term to look at an old timetable; that must not change "how many terms remain" |
| D8 | Level 3's existing cards stay untouched in this round | Priority order in the skill: do not break what already works before a demo |

---

## 3. Math specification

All of this lives in exactly one file: `Core/Grades/GPAXCalculator.swift`. No view may re-derive any of it.

### 3.1 Definitions

For each completed term `t`:

```
credits(t)       = totalCredits(t)  ??  20.0        (D2)
earnedPoints(t)  = gpa(t) × credits(t)
```

`earnedPoints` is the reconstruction of `Σ(grade × credit)` for that term. This is what makes D1 exact rather than approximate:

```
gpa(t) = Σ(grade × credit) / Σ(credit)
       ⟹  gpa(t) × Σ(credit)  =  Σ(grade × credit)
```

### 3.2 Core outputs

```
completedCredits = Σ credits(t)                      over completed upper-band terms
earnedPoints     = Σ earnedPoints(t)                 over the same set
gpax             = earnedPoints / completedCredits

remainingTerms   = terms from currentTerm through ม.6 เทอม 2, inclusive
remainingCredits = remainingTerms.count × 20.0       (or per-term override if set)
totalCredits     = completedCredits + remainingCredits

requiredAverage  = (target × totalCredits − earnedPoints) / remainingCredits
ceiling          = (earnedPoints + 4.0 × remainingCredits) / totalCredits
floor            = earnedPoints / totalCredits
```

`currentTerm` is **included** in `remainingTerms` — its grade has not been issued yet.

### 3.3 Worked example (use this as the unit-test fixture)

Student is in **ม.6 เทอม 1**, target **3.50**.

| Term | GPA | Credits | earnedPoints |
|---|---|---|---|
| ม.4 เทอม 1 | 3.15 | 21.0 | 66.150 |
| ม.4 เทอม 2 | 3.32 | 20.5 | 68.060 |
| ม.5 เทอม 1 | 3.41 | 21.5 | 73.315 |
| ม.5 เทอม 2 | 3.28 | 20.0 | 65.600 |
| **Total** | | **83.0** | **273.125** |

```
gpax             = 273.125 / 83.0                     = 3.2907  → 3.29
remainingTerms   = [ม.6 เทอม 1, ม.6 เทอม 2]           = 2
remainingCredits = 2 × 20.5                            = 41.0
totalCredits     = 83.0 + 41.0                         = 124.0

requiredAverage  = (3.50 × 124.0 − 273.125) / 41.0     = 3.9238 → 3.92
ceiling          = (273.125 + 4.0 × 41.0) / 124.0      = 3.5252 → 3.53
floor            = 273.125 / 124.0                     = 2.2026 → 2.20
```

Reading: the 3.50 target is still reachable, but only just — the ceiling is 3.53. This is exactly the case the UI needs to communicate without being brutal about it.

### 3.4 Result states

`GPAXCalculator` returns an enum so the view never does arithmetic branching:

| State | Condition | UI copy (Thai) |
|---|---|---|
| `.noData` | `completedCredits == 0` | "ยังไม่มีข้อมูล — เพิ่มผลการเรียนเทอมแรก" |
| `.achieved` | `requiredAverage <= 0` | "ถึงเป้าแล้ว แม้ได้ 0 ทุกเทอมที่เหลือ" |
| `.onTrack(required)` | `0 < required <= 3.5` | "ต้องได้เทอมละ X ขึ้นไป" |
| `.tight(required)` | `3.5 < required <= 4.0` | "ต้องได้เทอมละ X — เกือบเต็มทุกเทอม" |
| `.outOfReach(ceiling)` | `required > 4.0` | "เป้า Y เกินเอื้อมแล้ว · สูงสุดที่เป็นไปได้คือ Z" + route to Portfolio / TCAS round 3 |
| `.finished` | `remainingCredits == 0` | "GPAX สุดท้าย X" |

`.outOfReach` **must** offer a next action, not just deliver the verdict. See §6.5.

### 3.5 Rounding

Display uses 2 decimal places, rounded half-up. **Never round intermediate values** — `earnedPoints` and `credits` stay full precision until the final format call. Rounding `earnedPoints` per-term drifts by up to 0.01 GPAX over six terms.

---

## 4. Data model changes

### 4.1 Chosen approach: two optional fields on `Term`

```swift
// Core/Models/Term.swift  — additions only
/// Final grade-point average for this term, 0.00–4.00.
/// nil = the student has not entered it (term not finished, or not recalled).
var gpa: Double? = nil

/// Total credit hours attempted this term. nil = unknown; the calculator
/// substitutes GPAXCalculator.defaultTermCredits (D2).
var totalCredits: Double? = nil
```

**Why on `Term` and not a new `@Model`:**

- `Term` is already keyed by exactly the tuple GPAX needs, and is already unique per slot
- No `Schema([...])` edit → no risk of the `fatalError` crash path
- No `SettingsView.resetAllData()` edit → no repeat of the Calendar-models oversight
- Two optional properties with defaults is a **lightweight, additive** SwiftData migration

**Cost:** `Term` rows now get created for past terms that have no timetable. That is acceptable — `TermStore.allSlots` already treats the 12 slots as the canonical menu, and `TermStore.delete` already cleans up correctly.

**Rejected alternative:** a separate `TermGradeSummary` model. Better isolation, but requires a Schema edit, a `resetAllData()` edit, and a join for every read. Not worth it for two `Double?` fields.

### 4.2 New settings keys

New file `Core/Grades/GPAXSettings.swift` — **the only place that knows these `UserDefaults` keys**, same pattern as `PomodoroSettings.swift`. No view writes a raw key.

| Key | Type | Meaning |
|---|---|---|
| `com.studentos.gpax.currentGradeLevel` | `Int` | The student's **real** grade level, 1–6 (D7) |
| `com.studentos.gpax.currentTermNumber` | `Int` | 1 or 2 |
| `com.studentos.gpax.target` | `Double` | Target GPAX; 0 = not set |
| `com.studentos.gpax.targetSource` | `String` | Free text, e.g. the programme name that produced the target |
| `com.studentos.gpax.entryMode` | `String` | `perTerm` or `cumulative` (D3/D4) |
| `com.studentos.gpax.priorGPAX` | `Double` | Cumulative mode only |
| `com.studentos.gpax.priorCredits` | `Double` | Cumulative mode only |
| `com.studentos.gpax.priorTermCount` | `Int` | Cumulative mode only |

### 4.3 The two-term-pointer rule (D7) — read this twice

```
TermStore.activeTermKey                → which term the user is LOOKING AT
GPAXSettings.currentGradeLevel/Number  → which term the student is ACTUALLY IN
```

They are usually the same and will diverge the moment the user opens an old timetable. `GPAXCalculator` reads **only** the second pair. If a future change makes GPAX read `activeTermID`, remaining-term counts will silently go wrong — which is the worst class of bug here, because nothing crashes.

### 4.4 Cumulative mode (D3)

When `entryMode == .cumulative`, the calculator ignores per-term `gpa` values for completed terms and instead uses:

```
completedCredits = priorCredits          (default: priorTermCount × 20.0)
earnedPoints     = priorGPAX × priorCredits
```

Switching back to `perTerm` keeps the prior values stored but unused, so the switch is reversible. When the user later enters per-term rows, the app compares the two and warns on mismatch:

> "รวมรายเทอมได้ 3.31 แต่ GPAX สะสมที่กรอกไว้คือ 3.29 — ใช้อันไหนดี?"

---

## 5. New and changed files

### New

```
Core/Grades/GPAXSettings.swift            ~70   AppStorage keys + current-term helpers
Core/Grades/GPAXCalculator.swift         ~140   pure logic, no SwiftUI import
Features/GradeCenter/GPAXSummaryCard.swift    ~120   the big card: GPAX, range bar, required average
Features/GradeCenter/TermGradeListSection.swift ~110  the 6-row list
Features/GradeCenter/TermGradeEditSheet.swift  ~130  GPA + credits form for one term
Features/GradeCenter/CumulativeGPAXSheet.swift  ~90  the "I don't remember" path
Features/GradeCenter/GradeLevelSheet.swift      ~80  "which year are you in" picker
PrototypeAppTests/GPAXCalculatorTests.swift    ~120  first real unit tests in the project
```

`Core/Grades/` is a new folder. File-system-synchronized groups mean **no `.pbxproj` edit is needed**.

### Changed

| File | Change | Risk |
|---|---|---|
| `Core/Models/Term.swift` | +2 optional properties | Low — additive migration |
| `Features/GradeCenter/GradeCenterView.swift` | Insert GPAX section above the existing cards; existing cards untouched | Low |
| `Features/Dashboard/DashboardView.swift` | One-line GPAX card routing to `.gradeCenter` | Medium — 350-line file, read only the section being edited |
| `Features/Settings/SettingsView.swift` | New "ระดับชั้นและเป้า GPAX" section | Medium — `developerSection` uses a computed property because `#if DEBUG` in a ViewBuilder breaks type-checking; do not disturb it |
| `claude plan/PROJECT_MAP.md` | Document `Core/Grades/`, the new `Term` fields, the D7 rule | Required in the same commit |

### Explicitly not touched this round

`SemesterRecord`, `GradeComponent`, `GradeReportOCRParser`, `GradeReportSetupView`, `ScheduleImportCommitter`, the whole OCR pipeline.

---

## 6. UI specification

Entry point is unchanged: Dashboard → `DashboardDestination.gradeCenter`.

### 6.1 Screen 1 — grade level picker (onboarding, once)

Two chip rows: ม.4 / ม.5 / ม.6, then เทอม 1 / เทอม 2. Below, live feedback: "ผ่านมาแล้ว 4 เทอม · เหลืออีก 2 เทอม".

Writes `GPAXSettings.currentGradeLevel` / `currentTermNumber`. Also reachable from Settings as **"ขึ้นชั้นแล้ว"** — without this the numbers freeze when the student advances a year.

`SchoolBand` already splits ม.ต้น / ม.ปลาย; the picker offers all six levels but shows a note for ม.1–ม.3 that TCAS counts ม.ปลาย only (D5).

### 6.2 Screen 2 — main screen (GPAX section of `GradeCenterView`)

**Summary card** (`Theme.Colors.primary` tint):

```
GPAX สะสม · จาก 4 เทอม            ← provenance, always shown (D6)
3.29                              ← 30pt
[███████████████████░░░]│         ← range bar: floor 2.20 → ceiling 3.53
พื้น 2.20 · เพดาน 3.53 · เป้า 3.50   ← target as a tick mark on the bar

ต้องได้เทอมละ 3.92 ขึ้นไป
เป้ายังเป็นไปได้ แต่ต้องเกือบเต็มทั้ง 2 เทอม
```

The range bar is the thing a spreadsheet cannot do: reachability is visible before any number is read. Bar geometry: `x = (gpax − floor) / (ceiling − floor)`, target tick at the same mapping.

**Term list**, always exactly 6 rows for ม.ปลาย, in `sortKey` order:

| Row state | Right-hand side |
|---|---|
| completed, entered | `3.15` + `· 21.0 นก.` in `textSecondary` |
| completed, empty | "เพิ่ม" |
| current | "กำลังเรียน" in `Theme.Colors.primary` |
| future | "ต้องได้ 3.92" in `textSecondary` |

Tapping any past or current row opens Screen 3. Rendering all six from the start — including empty ones — shows the whole path from day one and gives ม.4 students a non-empty screen.

Below this section, the existing `GradeBreakdownCard` and `TargetScoreCalculatorCard` continue to render unchanged (D8).

### 6.3 Screen 3 — term edit sheet

```
ผลการเรียน ม.5 เทอม 2

เกรดเฉลี่ยเทอมนี้     [ 3.28 ]
อยู่บนใบ ปพ.1 ช่อง "ผลการเรียนเฉลี่ย"

หน่วยกิตรวม (ไม่บังคับ)  [ 20.0 ]
ไม่กรอกก็ได้ แต่ GPAX จะคลาดเคลื่อน ±0.03

[ บันทึก ]
จำเกรดเทอมนี้ไม่ได้        → Screen 4
```

Validation: GPA `0.00...4.00`, credits `0.5...40.0`. Decimal keypad. Both fields clearable back to nil.

### 6.4 Screen 4 — "I don't remember"

Three options, first one recommended:

1. **รู้ GPAX สะสมล่าสุด** — one field, replaces every past term (cumulative mode, D3). Copy: "เลขนี้อยู่ท้ายใบ ปพ.1"
2. **เว้นไว้ก่อน** — compute from what exists; the summary card's provenance line reads "จาก 2 จาก 4 เทอม"
3. **ขอใบ ปพ.1 จากฝ่ายทะเบียน** — creates a `CalendarEvent` reminder

### 6.5 The `.outOfReach` state

When `requiredAverage > 4.0`, the card must not read as a verdict:

```
เป้า 3.50 เกินเอื้อมแล้ว
สูงสุดที่เป็นไปได้ตอนนี้คือ 3.31

[ ดูคณะที่ใช้ GPAX 3.25 ]    → TCASPlannerView
[ เริ่มทำ Portfolio ]          → PortfolioView
[ ปรับเป้าเป็น 3.30 ]         → target editor
```

19 of ~60 respondents already carry this anxiety. A dead-end red screen is the most likely place for a user to close the app and not return.

### 6.6 Copy rules

- Frame gaps as distance remaining, not deficit: **"เหลืออีก 0.22"**, never "ต่ำกว่าเป้า −0.22"
- Every GPAX figure carries its provenance (D6)
- Estimated results carry "ประมาณการ ±0.03"
- All UI text is Thai; Buddhist-era dates via `Date+Thai.swift`
- Design tokens only — `Theme.Colors`, `Theme.Spacing`, `Theme.Radius`; reuse `CardContainer`

---

## 7. Edge cases

| Case | Behaviour |
|---|---|
| No data at all | `.noData` empty state with a single CTA — never a blank screen |
| One term entered | Full calculation runs; provenance says "จาก 1 เทอม" |
| `totalCredits` nil | Substitute 20.0, label "ประมาณการ ±0.03" |
| Target not set | Show GPAX and the term list; hide the required-average line; offer "ตั้งเป้า" |
| Student is ม.1–ม.3 | Show GPA per term; state that TCAS GPAX counts ม.ปลาย only (D5) |
| Student is in ม.6 เทอม 2 | `remainingCredits` counts only that term |
| All six terms entered | `.finished`; the reverse calculator disappears |
| `requiredAverage > 4.0` | `.outOfReach` (§6.5) |
| `requiredAverage <= 0` | `.achieved` |
| GPA entered as 3.5 but credits 0 | Reject on save; credits must be > 0 when present |
| Cumulative and per-term disagree | Warn, let the user choose; never silently pick one (D4) |
| Student repeats a year | Out of scope — `Term` has no year field by design. Document as a known limitation |
| Student transfers schools | Works unchanged; cumulative mode covers it |

---

## 8. Risks

| Risk | Mitigation |
|---|---|
| SwiftData migration on `Term` fails | Both fields are `Double?` with `= nil` defaults — additive and lightweight. **If the app crashes on launch after this change, delete the app from the simulator/device and reinstall.** Warn Few before he runs it |
| `DashboardView.swift` (350 lines) type-check timeout | Extract the GPAX card into its own `View` struct in its own file; never inline it into `DashboardView.body` |
| Level 1 and Level 3 both live in `GradeCenterView` | Keep them as two separate child views with no shared state. Level 1 reads `Term.gpa`; Level 3 reads `GradeComponent`. No overlap |
| GPAX read from the browsing term instead of the real current term | D7 + §4.3. Add a comment at the `GPAXCalculator` call site |
| Formulas copied into a view | All arithmetic lives in `GPAXCalculator`. Views format, never compute |
| Wrong number reaches a university application | D6 provenance labels are a correctness requirement, not decoration |

---

## 9. Migration path for `SemesterRecord` (not this round)

`GradeReportSetupView` currently writes per-subject `SemesterRecord` rows keyed by a free-text `semesterLabel`. That is Level 2 data with no link to `Term`.

For this round: leave it alone. It does not feed GPAX and it does not conflict.

When Level 2 is built:

1. Add `var term: Term?` to `SemesterRecord`; migrate `semesterLabel` by parsing "ม.X เทอม Y" and calling `TermStore.findOrCreate`
2. Apply D4 — a term with `SemesterRecord` rows derives its `Term.gpa` from those rows, and the manual field becomes read-only
3. On expansion, validate that the subject credits sum to the previously entered `totalCredits`; warn on mismatch

---

## 10. Build order

Each step is independently verifiable. Do not start the next one until Few confirms the previous builds.

**Step 1 — pure logic, zero UI risk**
`GPAXSettings.swift` + `GPAXCalculator.swift` + `GPAXCalculatorTests.swift` using the §3.3 fixture.
Verify: tests pass in Xcode. Nothing in the app changes yet. This also gives the project its first real unit tests, which is worth mentioning to the judges.

**Step 2 — model**
Two optional fields on `Term`. Verify: app launches, existing timetable and tasks intact.

**Step 3 — read-only display**
`GPAXSummaryCard` + `TermGradeListSection` inside `GradeCenterView`, above the existing cards. No editing yet. Verify: Dashboard → เกรด & GPA shows six rows and an empty state; existing Level 3 cards still work.

**Step 4 — input**
`GradeLevelSheet`, `TermGradeEditSheet`, `CumulativeGPAXSheet`. Verify: enter the §3.3 numbers and confirm the screen reads 3.29 / 3.92 / 3.53 / 2.20.

**Step 5 — Dashboard card**
One line, own file, routes to `.gradeCenter`. Verify: card appears with data and hides cleanly without.

**Step 6 — Settings**
Grade level, "ขึ้นชั้นแล้ว", target GPAX, entry mode. Verify: advancing the term changes the remaining-term count on the main screen.

**Step 7 — PROJECT_MAP.md** updated in the same commit as whichever step changed structure.

---

## 11. Definition of done

- [ ] Entering the §3.3 fixture produces 3.29 / 3.92 / 3.53 / 2.20 on screen
- [ ] Unit tests cover all six `GPAXResult` states
- [ ] Empty state renders with zero data entered
- [ ] Cumulative mode reproduces the same GPAX as per-term entry for the same student
- [ ] `.outOfReach` offers at least two forward actions
- [ ] Every displayed GPAX carries a provenance label
- [ ] Switching the browsing term does not change the remaining-term count (D7)
- [ ] Existing Level 3 cards behave exactly as before
- [ ] `PROJECT_MAP.md` updated

---

## 12. Deferred — Level 2 and Level 3

Specified here so the Level 1 data model does not paint them into a corner.

### Level 2 — per-subject final grades

Expand a single term into subject rows. Credits are derived from the timetable, not the subject code:

> Ministry rule: 1 period per week for a full term = 0.5 credit.
> A subject appearing 3 periods/week in `ScheduleEntry` → 1.5 credits.

The app already holds the timetable, so credits can be counted automatically and only corrected by hand. **Thai subject codes do not encode credits** — an earlier assumption that they do is wrong and must not reach the implementation.

Gives: which subject is dragging GPAX down, and which is worth pushing (high credits × low grade).

### Level 3 — in-term score tracking

Already partly implemented (§1.5). The design conclusions from this discussion that the existing implementation should adopt:

- One universal input shape: **`obtained X / max Y`**. Raw or teacher-converted scores both fit; the app never models a teacher's weighting formula
- Three capture points: after an `ExamEvent` date passes (the primary one — unit quizzes), on `Assignment` completion (opportunistic), and a manual add button (used most in practice, since teachers announce several scores at once)
- Components whose maximum is unknown are excluded from `Σmax` but still shown individually
- Output is a **grade range**, not a point estimate: "final exam 0 → grade 2 · full → grade 4". The range narrows as scores are entered, which makes accuracy a visible reward for entering data
- A "data completeness" bar is mandatory whenever the total maximum is unknown
- Opt-in per subject, default off. Most students track two or three subjects, not all eight

### Rejected: checklist-driven confidence percentages

An earlier proposal was a checklist ("submitted all work", "attendance above 80%", "mid-scores around class average") producing probabilities such as "A 20% · B+ 45%".

Rejected because:

1. The percentages would be invented — there is no training data behind them. Fabricated precision is worse than admitting uncertainty, and it cannot be defended if a judge asks how the number is derived
2. The checklist items are not objectively measurable; two students in identical situations would answer differently
3. It contradicts Level 3, which already has real scores. Real numbers beat estimation

**The checklist idea is kept in a different role:** a per-subject health check that outputs a traffic light, not a number.

```
🟡 ส่งงานครบ           ✓
🔴 เข้าเรียนเกิน 80%    ✗   ← ขาด 5 คาบ เสี่ยงติด "ร"
🟢 ผ่านกลางภาค         ✓
```

It predicts nothing — it reflects what the user entered — so it cannot be wrong, needs no model, and catches a real failure mode (running out of attendance hours) that students notice too late.
