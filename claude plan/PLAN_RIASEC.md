# PLAN_RIASEC — Career Discovery v2 (RIASEC screening inventory)

> **Status:** design locked, not implemented
> **Written:** 2026-08-09
> **Audience:** the implementing agent (Sonnet). Read this file top to bottom before writing any code.
> **Verified against source:** `CareerDiscoveryView.swift`, `CareerInterestResult.swift`, `PrototypeAppApp.swift` (Schema), `SettingsView.swift` (`resetAllData`), `RootTabView.swift`, `Theme.swift`, `FeatureTier.swift`, `GPAXCalculatorTests.swift`
> **Source research:** `uploads/สร้างแบบประเมิน RIASEC.md` (deep-research report). **That report's scoring section contains four bugs. This plan supersedes it. Do not copy formulas from the report.**

---

## 0. What this feature is, and what it replaces

Today `Features/CareerDiscovery/CareerDiscoveryView.swift` asks the student to tap some of 8 interest chips, then runs a chain of `if tags.contains(...)` in `CareerMatcher` and prints one career string. It is transparently an if-else ladder and will not survive a judge asking "what is this based on?".

v2 replaces the chip picker with an **18-item RIASEC screening inventory** grounded in Holland's theory, with a defensible scoring model, a 3-ranked result with fit percentages, and an honest "result not clear enough" state.

**Non-goals for this round:** no online AI, no new SPM dependency, no changes to `TCASPlannerView`, no purchase flow.

---

## 1. Why this is low-risk (read before worrying about breakage)

Two facts that remove the usual danger:

1. **`CareerInterestResult` is already in the Schema** — `App/PrototypeAppApp.swift:25`. No `@Model` is being added, so the `fatalError` trap in `ModelContainer` init is not in play.
2. **`resetAllData()` already deletes it** — `Features/Settings/SettingsView.swift:234`. Nothing to add there.

The only migration risk is §4 (adding stored properties to an existing `@Model`). Everything else is additive files.

---

## 2. The 18 items (final — use exactly this)

### 2.1 What changed from the research report, and why

| # | Change | Reason |
|---|---|---|
| 1 | **All `source` strings rewritten** to `"original, conceptually informed by O*NET Interest Profiler (public domain)"` | The report cited `O*NET IP Short Form item #142`, `#107`, `#80`, `#75`. The Short Form has only 60 items, so those numbers cannot be verified and are probably fabricated. An unverifiable citation is worse than an honest "original". |
| 2 | **Three double-barrelled items split** | Old item 5 asked "statistics **or** coding", old item 3 asked "farm plot / plant trees / **raise animals**", old item 1 asked "repair broken things **or** assemble furniture". A student who loves one half and hates the other cannot answer. Each item now names one activity. |
| 3 | **Secondary weights rebalanced so every dimension receives exactly 1.0** | See §2.2 — this is the important one. |
| 4 | **Presentation order interleaved R,I,A,S,E,C** | The report listed items grouped by dimension (RRR III AAA…), which invites pattern-answering and lets an observant student reverse-engineer the test. |

### 2.2 The weight-balance bug (the reason §3 exists)

In the research report the cross-loadings were distributed unevenly. Summing every weight each dimension *receives*:

| Dim | primary (3 × 1.0) | secondary received | total |
|---|---|---|---|
| R | 3.0 | 1.0 | 4.0 |
| I | 3.0 | 1.2 | **4.2** |
| A | 3.0 | 0.9 | 3.9 |
| S | 3.0 | 0.7 | **3.7** |
| E | 3.0 | 1.1 | 4.1 |
| C | 3.0 | 1.0 | 4.0 |

Consequence: a student who answers **3 to every question** gets centred scores of I +0.65, E +0.35, R +0.05, C +0.05, A −0.25, S −0.85. Under the report's percentage formula that is a **16.7-point spread produced by nothing but the weight table**. I always wins, S always loses, regardless of answers — and the bias scales up with how enthusiastically the student answers.

The table below fixes this: every dimension receives exactly **1.0** of secondary weight, so every dimension totals **4.0**. `RIASECScorerTests` asserts this invariant so a future edit cannot silently reintroduce it.

### 2.3 The item table

Presentation order = `id` order. Likert 1–5.

| id | Thai text | primary | pW | secondary | sW |
|---|---|---|---|---|---|
| 1 | ซ่อมแซมสิ่งของเครื่องใช้ที่พังให้กลับมาใช้งานได้ | R | 1.0 | I | 0.4 |
| 2 | ทำการทดลองวิทยาศาสตร์เพื่อหาสาเหตุของปรากฏการณ์ต่างๆ | I | 1.0 | R | 0.4 |
| 3 | ออกแบบป้ายประกาศหรือภาพกราฟิกให้สวยงาม | A | 1.0 | R | 0.3 |
| 4 | เป็นพี่เลี้ยงอาสาคอยดูแลรุ่นน้องในค่ายของโรงเรียน | S | 1.0 | E | 0.3 |
| 5 | เป็นผู้นำแบ่งงานในกลุ่ม และกระตุ้นให้เพื่อนทำงานจนสำเร็จ | E | 1.0 | S | 0.4 |
| 6 | จัดทำบัญชีรายรับรายจ่ายของห้องเรียนให้ครบถ้วนแม่นยำ | C | 1.0 | E | 0.4 |
| 7 | ช่วยติดตั้งและควบคุมเครื่องเสียงในงานกิจกรรมของโรงเรียน | R | 1.0 | S | 0.3 |
| 8 | เขียนโค้ดเพื่อสร้างโปรแกรมคอมพิวเตอร์เบื้องต้น | I | 1.0 | C | 0.4 |
| 9 | แต่งเรื่องสั้นหรือคิดพล็อตสำหรับการแสดงละคร | A | 1.0 | S | 0.3 |
| 10 | ติวหรืออธิบายเนื้อหาที่ยากให้เพื่อนเข้าใจ | S | 1.0 | I | 0.3 |
| 11 | คิดแคมเปญเชิญชวนให้คนมาเข้าร่วมกิจกรรมของชมรม | E | 1.0 | A | 0.3 |
| 12 | ตรวจสอบความถูกต้องของข้อมูลในรายงานก่อนส่งครู | C | 1.0 | I | 0.3 |
| 13 | ดูแลแปลงเกษตรหรือปลูกต้นไม้ในโครงการของโรงเรียน | R | 1.0 | C | 0.3 |
| 14 | ค้นหาข้อมูลจากหลายแหล่งเพื่อทำรายงานเชิงลึกในหัวข้อที่สนใจ | I | 1.0 | A | 0.4 |
| 15 | ตัดต่อคลิปวิดีโอเพื่อเล่าเรื่องราวที่อยากสื่อสาร | A | 1.0 | E | 0.3 |
| 16 | รับฟังปัญหาของเพื่อนและช่วยให้กำลังใจเมื่อเพื่อนท้อ | S | 1.0 | A | 0.3 |
| 17 | เป็นตัวแทนพูดโน้มน้าวหรือเจรจาเพื่อรักษาสิทธิ์ของนักเรียน | E | 1.0 | C | 0.3 |
| 18 | จัดหมวดหมู่เอกสารหรือไฟล์ให้เป็นระเบียบค้นหาง่าย | C | 1.0 | R | 0.3 |

Balance check (must hold): R receives 2(0.4)+3(0.3)+18(0.3)=1.0 · I receives 1(0.4)+10(0.3)+12(0.3)=1.0 · A receives 14(0.4)+16(0.3)+11(0.3)=1.0 · S receives 7(0.3)+9(0.3)+5(0.4)=1.0 · E receives 4(0.3)+15(0.3)+6(0.4)=1.0 · C receives 13(0.3)+8(0.4)+17(0.3)=1.0

### 2.4 Likert labels (Thai, exact strings)

```
1 = ไม่ชอบเลย
2 = ไม่ค่อยชอบ
3 = เฉยๆ
4 = ค่อนข้างชอบ
5 = ชอบมาก
```

---

## 3. Scoring algorithm (corrected — this supersedes the report)

Four fixes vs. the report:

| Bug in report | Fix here |
|---|---|
| Unequal dimension weights → structural bias toward I | Divide raw score by that dimension's total weight before centring (§3.2 step 3) |
| Inconclusive threshold `SD < 1.2`, wrong scale — would fire for almost everyone | Threshold `SD < 0.30` on the normalised 1–5 scale (§3.2 step 5) |
| `(c + 4.5) / 9 * 100` assumed spread ±4.5; real max is ≈ ±9.4 raw → constant clamping to 0 and 100 | `clamp(50 + 20 × centred, 10, 95)` on the normalised scale (§3.2 step 6) |
| Scores held in `[String: Double]`; tie-break says "keep R,I,A,S,E,C order" but Swift `Dictionary` has no order → non-deterministic results for identical input | `enum RIASECDimension: CaseIterable` + arrays throughout. Never iterate a dictionary to produce ranked output. |

### 3.1 Public API

```swift
struct RIASECProfile {
    let percentages: [RIASECDimension: Int]   // 10...95, for display only
    let centered: [RIASECDimension: Double]   // ranking source of truth
    let rawScores: [RIASECDimension: Double]  // tie-break source
    let ranked: [RIASECDimension]             // 6 entries, best first, deterministic
    let hollandCode: String                   // e.g. "RIS" — first 3 of `ranked`
    let isInconclusive: Bool
    let spread: Double                        // the SD, exposed for debugging/tests
}

enum RIASECScorer {
    static func score(answers: [Int: Int]) -> RIASECProfile
}
```

`answers` is `[itemID: likertValue]`. The quiz UI guarantees all 18 are present (§6.2); the scorer must still not crash on a missing key — treat missing as `3` **and** force `isInconclusive = true` if any key is missing.

### 3.2 The steps

Let `W = 4.0` (every dimension's total weight — but **compute it from the item table at runtime, do not hardcode 4.0**, so the invariant test is meaningful).

1. **Raw accumulation.** For each item, `raw[primary] += answer × primaryWeight` and `raw[secondary] += answer × secondaryWeight`.
2. **Total weight per dimension.** `totalWeight[d] = Σ` of every weight pointing at `d` across all items.
3. **Normalise.** `norm[d] = raw[d] / totalWeight[d]` → lands in `1.0 ... 5.0`.
   *This is the step that kills the bias. A student answering all-3 now gets `norm[d] = 3.0` for all six.*
4. **Centre within-person (ipsative).** `mean = Σ norm[d] / 6`; `centered[d] = norm[d] − mean`. Σ`centered` = 0 by construction — assert this in tests with a tolerance of 1e-9.
5. **Inconclusive test.** `sd = sqrt( Σ centered[d]² / 6 )` (population SD).
   `isInconclusive = sd < 0.30 || answeredCount < 18 || modeCount >= 15`
   where `modeCount` is how many of the 18 answers share the single most common Likert value — this catches straight-lining that centring alone would not.
   Also compute `isBorderline = !isInconclusive && (percent[ranked[0]] − percent[ranked[2]] < 8)` and surface it (§7.3).
6. **Display percentage.** `percent[d] = clamp( Int(round(50 + 20 × centered[d])), 10, 95 )`.
   Floor of 10 and ceiling of 95 are deliberate: a student should never be shown "0% fit" with anything, and "100%" overclaims for a screening tool.
7. **Ranking + tie-break.** Sort descending by `centered`. On a tie, higher `raw` wins. On a further tie, canonical order `R, I, A, S, E, C` wins. Implement by sorting an array built from `RIASECDimension.allCases` (which must be declared in exactly that order) with a stable comparator — do not rely on `Dictionary` iteration anywhere.
8. **Holland code** = the letters of `ranked[0...2]` concatenated, e.g. `"RIS"`.

### 3.3 Worked example — use verbatim as the primary unit test

Answers by item id:

```
1:5  2:4  3:2  4:3  5:3  6:2  7:5  8:4  9:2
10:3 11:2 12:3 13:4 14:4 15:1 16:3 17:2 18:3
```

Intermediate values (all hand-computed; if the code disagrees, the code is wrong):

| Dim | raw | norm (raw/4.0) | centered |
|---|---|---|---|
| R | 17.1 | 4.2750 | +1.204167 |
| I | 15.8 | 3.9500 | +0.879167 |
| A | 8.1 | 2.0250 | −1.045833 |
| S | 12.3 | 3.0750 | +0.004167 |
| E | 9.0 | 2.2500 | −0.820833 |
| C | 11.4 | 2.8500 | −0.220833 |

`mean(norm) = 3.070833…` · `Σ centered = 0` · `sd = 0.820495` → **not** inconclusive

| Dim | percent |
|---|---|
| R | 74 |
| I | 68 |
| S | 50 |
| C | 46 |
| E | 34 |
| A | 29 |

`ranked = [R, I, S, C, E, A]` · `hollandCode = "RIS"`

### 3.4 Additional required tests

| Test | Expectation |
|---|---|
| `allDimensionsHaveEqualTotalWeight` | every `totalWeight[d] == 4.0` (tolerance 1e-9). **This is the regression guard for §2.2 — never delete it.** |
| `flatThrees` | all answers `3` → every `centered == 0`, every `percent == 50`, `sd == 0`, `isInconclusive == true` |
| `flatFives` | all answers `5` → identical to `flatThrees` except `rawScores` are larger. Proves acquiescence bias is neutralised. |
| `flatOnes` | all answers `1` → same as above |
| `centeredSumsToZero` | for 3 different random-but-fixed answer sets |
| `straightLiningDetected` | 15 answers = 4, 3 answers = 5 → `isInconclusive == true` via `modeCount` |
| `missingAnswerForcesInconclusive` | 17 answers supplied → `isInconclusive == true`, no crash |
| `deterministicTieBreak` | run `score` on the same input 50 times → identical `hollandCode` every time |
| `workedExample` | §3.3 exactly |

Test file style: mirror `PrototypeAppTests/GPAXCalculatorTests.swift` — `import Testing`, `@testable import PrototypeApp`, `struct RIASECScorerTests { @Test func ... }`, and a header comment saying the fixture matches `claude plan/PLAN_RIASEC.md` §3.3 so the two are updated together.

### 3.5 Honesty constraint on the numbers

`percent` is a **within-person relative fit indicator**, not a probability and not a percentile against other students. Never label it "ความแม่นยำ" or "โอกาสสำเร็จ". The UI string is `"ความเข้ากัน"` and §7.5's disclaimer must always be visible on the result screen.

---

## 4. Model change — `CareerInterestResult`

`Core/Models/CareerInterestResult.swift`

**Rule: add properties, do not remove or retype any existing one.** The five existing properties (`takenAt`, `interestTags`, `recommendedCareer`, `recommendedFaculty`, `recommendedSkills`) stay exactly as they are so the "ผลลัพธ์ก่อนหน้า" list keeps rendering old rows.

Add, each with a default value in the initialiser so SwiftData lightweight migration has a fallback:

```swift
var scoreR: Int = 50
var scoreI: Int = 50
var scoreA: Int = 50
var scoreS: Int = 50
var scoreE: Int = 50
var scoreC: Int = 50
var hollandCode: String = ""
var isInconclusive: Bool = false
/// 18 Likert answers in item-id order, so a future scoring change can
/// re-score historical results without asking the student to retake.
var answers: [Int] = []
```

How the legacy fields are filled by v2:

- `interestTags` → the three letters of the Holland code as strings, e.g. `["R", "I", "S"]`
- `recommendedCareer` → the Thai group name of `ranked[0]` (e.g. `"กลุ่มทักษะปฏิบัติการและเครื่องจักรกล"`)
- `recommendedFaculty` → faculties of `ranked[0]`, joined with `" · "`
- `recommendedSkills` → the `focusSubjects` of `ranked[0]`

**Migration warning to relay to Few:** adding stored properties to an existing `@Model` normally succeeds under lightweight migration, but if any device already holds `CareerInterestResult` rows the app can still fail to open. Tell Few to **delete the app from the simulator/device before the first run** of this change. Do not claim it will migrate cleanly.

**No change needed** in `PrototypeAppApp.swift` (already in Schema) or `SettingsView.resetAllData()` (already deleted). Verify both by reading them, then say so.

---

## 5. New files

All under paths that already exist as file-system-synchronized groups — **create the files and stop. Do not edit `PrototypeApp.xcodeproj/project.pbxproj`.**

```
Core/Career/RIASECDimension.swift    enum + Thai names + Theme colour + SF Symbol
Core/Career/RIASECItem.swift         the 18 items from §2.3
Core/Career/RIASECScorer.swift       §3, pure, no SwiftData import
Core/Career/FacultyMapping.swift     §8 table as data
Features/CareerDiscovery/RIASECQuizView.swift
Features/CareerDiscovery/RIASECResultView.swift
PrototypeAppTests/RIASECScorerTests.swift
```

Modified:

```
Core/Models/CareerInterestResult.swift        §4
Features/CareerDiscovery/CareerDiscoveryView.swift   §7.1 — becomes a hub screen
```

Deleted: the `private enum CareerMatcher`, `private struct InterestOption`, `private struct CareerMatch`, and `private struct InterestChip` inside `CareerDiscoveryView.swift`. They are all `private` to that file — confirm with `grep -rn "CareerMatcher\|InterestChip\|InterestOption" --include=*.swift .` before deleting, and report what you found.

### 5.1 `RIASECDimension`

```swift
enum RIASECDimension: String, CaseIterable, Codable, Identifiable {
    case R, I, A, S, E, C   // declaration order IS the canonical tie-break order
}
```

Per-case data (all colours already exist in `Theme.Colors` — **no new design token, therefore no Figma variable update needed**):

| case | `thaiName` | `groupName` | colour | SF Symbol |
|---|---|---|---|---|
| R | ลงมือทำ | กลุ่มทักษะปฏิบัติการและเครื่องจักรกล | `Theme.Colors.success` | `wrench.and.screwdriver.fill` |
| I | ค้นคว้า | กลุ่มการค้นคว้า วิจัย และวิเคราะห์เชิงลึก | `Theme.Colors.primary` | `magnifyingglass` |
| A | สร้างสรรค์ | กลุ่มศิลปะสร้างสรรค์และการสื่อสาร | `Theme.Colors.pink` | `paintpalette.fill` |
| S | ช่วยเหลือผู้อื่น | กลุ่มการบริการสังคม สุขภาพ และการสอน | `Theme.Colors.warning` | `heart.fill` |
| E | โน้มน้าวและนำ | กลุ่มการนำเสนอ ธุรกิจ และการบริหาร | `Theme.Colors.purple` | `megaphone.fill` |
| C | จัดระบบ | กลุ่มการจัดการข้อมูลและระเบียบแบบแผน | `Theme.Colors.info` | `list.bullet.rectangle.fill` |

---

## 6. Behavioural decisions already made — do not re-litigate

### 6.1 Tier: **Free**

Not Pro. Reason: `EntitlementStore.hasPro` reads from `UserDefaults` and there is no purchase flow in V1, so it is `false` on every fresh install. Gating this feature would show judges an upsell wall instead of the feature. Demo integrity (priority 2 and 3 in the skill's priority list) beats monetisation theatre.

If Few later wants it gated, the change is one line in `CareerDiscoveryView` — wrap the start button in `if EntitlementStore.shared.isUnlocked(.pro)` and show `ProUpsellView` otherwise. Leave a `// MARK: - Tier gate` comment at that spot so it is easy to find. Do **not** add a `TierBadge` now; the badge would imply gating that does not exist.

### 6.2 All 18 questions are mandatory

No skip button. Rationale: the default-to-3 fallback the research report proposed distorts the profile, and 18 taps is well under the 3-minute budget. The "ถัดไป" affordance simply does not exist until an option is selected. A **back** button is allowed and must restore the previously chosen answer as selected.

### 6.3 One question per screen

Not a scrolling list. Prevents the student from seeing the R/I/A/S/E/C pattern, keeps tap targets large, and makes the progress bar meaningful.

---

## 7. UI specification

Design token discipline: every colour, spacing and radius comes from `Theme`. No literal hex, no magic numbers for padding. Reuse `CardContainer`. All user-facing strings Thai. Dates via `Date+Thai.swift` (`thaiShortString`).

### 7.1 `CareerDiscoveryView` — hub

Replaces the chip grid. Contents, top to bottom, inside a `ScrollView`:

1. **Intro `CardContainer`** — title `"ค้นหาสายอาชีพที่ใช่"`, body copy explaining: 18 คำถาม · ประมาณ 3 นาที · ไม่มีคำตอบถูกผิด · ทำงานแบบออฟไลน์ ไม่ส่งข้อมูลออกจากเครื่อง. One prominent button `"เริ่มทำแบบสำรวจ"`.
2. **Latest result `CardContainer`** — only if `pastResults.first != nil`. Shows the Holland code, the top-1 dimension name and its percentage, the date, and a `NavigationLink` into `RIASECResultView` reconstructed from the saved row. If the saved row `isInconclusive`, show the §7.3 treatment instead of a code.
3. **History `CardContainer`** — `pastResults.dropFirst().prefix(5)`, one row each: Holland code · top dimension · `takenAt.thaiShortString`. Tappable, same destination.
4. **Empty state** — when `pastResults.isEmpty`, sections 2 and 3 are omitted entirely (no empty card, no placeholder text). The intro card carries the screen.

Navigation: `NavigationStack` is supplied by `RootTabView` via `DashboardDestination.careerDiscovery`. Push `RIASECQuizView` with `NavigationLink`; the quiz replaces itself with the result via a `@State` flag rather than pushing a second level, so "back" from the result returns to the hub, not to question 18.

### 7.2 `RIASECQuizView`

- Top: `ProgressView(value:total:)` tinted `Theme.Colors.primary`, plus `"ข้อ 7 จาก 18"` in `.caption`, `Theme.Colors.textSecondary`.
- Middle: the question in `.title3`, `Theme.Colors.textPrimary`, left-aligned, generous vertical padding. Prefix with `"คุณชอบทำสิ่งนี้แค่ไหน"` once at the top of the screen (not repeated per item) so the question text itself stays short.
- Bottom: five full-width buttons stacked vertically, top = `ชอบมาก` (5) down to `ไม่ชอบเลย` (1). Minimum height 48pt each (≥44pt tap target). Selected state = filled with the dimension-agnostic `Theme.Colors.primary.opacity(0.15)` + primary-coloured text; unselected = `Color(.systemGray6)`.
  **Do not colour the buttons by dimension** — that would leak which dimension the item measures.
- Tapping an option records the answer and auto-advances after `0.2s`. On the last item, compute the profile, insert the `CareerInterestResult`, and flip to the result view.
- A back chevron in the toolbar returns to the previous item with its answer pre-selected. On item 1, back dismisses the quiz (with no save).
- `AppLog.action("Career", "ทำแบบสำรวจ RIASEC เสร็จ — \(code)")` on completion.

### 7.3 `RIASECResultView`

Takes a `RIASECProfile` (fresh) **or** a `CareerInterestResult` (historical) — define one small initialiser for each so the same view serves both paths.

Sections:

1. **Header card** — the Holland code in `.largeTitle.bold()`, tinted with `ranked[0]`'s colour, and beneath it the three dimension `thaiName`s joined by `" · "`.
2. **Top-3 card** — three rows. Each row: SF Symbol + `thaiName` + a horizontal bar + `"74%"`. Bar = `Capsule()` track in `Theme.Colors.separator` with a `Capsule()` fill in the dimension colour, width = `trackWidth × percent/100`. Build the bar as its **own small `View` struct** with a `GeometryReader` inside — not inline in the parent body (see §9 on the type-checker).
3. **All-six card** — the same bar row component for all six dimensions in `ranked` order, smaller type. Gives the student the full picture and makes the ranking auditable.
4. **Faculty card** — for `ranked[0]` (and `ranked[1]` if its percentage is within 10 points): the faculty list from §8 and the `focusSubjects` line.
5. **Link out** — a button `"ดูแผน TCAS ของฉัน"` that pops back and navigates to `DashboardDestination.tcasPlanner`. If wiring that cross-navigation turns out to need changes in `RootTabView`, **stop and ask instead of refactoring the tab shell.** A plain non-functional button is not acceptable; either it navigates or it is omitted.
6. **Disclaimer** — §7.5, always visible, `.caption`, `Theme.Colors.textSecondary`.
7. **`"ทำแบบสำรวจอีกครั้ง"`** button.

**Inconclusive state.** When `isInconclusive`, replace sections 1, 2 and 4 with a single card:

> **"ผลยังไม่ชัดเจนพอ"**
> คำตอบของคุณค่อนข้างใกล้เคียงกันทุกด้าน ซึ่งเป็นเรื่องปกติมาก — หลายคนสนใจหลายอย่างพอๆ กัน
> ลองทำใหม่โดยเลือกคำตอบให้ต่างกันมากขึ้นตามความรู้สึกจริง หรือลองทำกิจกรรมใหม่ๆ แล้วกลับมาทำอีกครั้ง

Section 3 (all-six bars) still shows, so the screen is not empty. The result is still saved, with `isInconclusive = true`.

**Borderline state** (`isBorderline` from §3.2 step 5): show the normal layout plus one extra line under the header — `"อันดับ 1–3 คะแนนใกล้เคียงกันมาก ลองพิจารณาทั้งสามด้านควบคู่กัน"`.

### 7.4 Accessibility

Every bar gets `.accessibilityLabel("\(thaiName) \(percent) เปอร์เซ็นต์")` and `.accessibilityHidden(true)` on the decorative capsule. Likert buttons get `.accessibilityAddTraits(.isButton)`. Do not fix font sizes with `.system(size:)` except where `TierBadge` already does; use semantic styles so Dynamic Type works.

### 7.5 Disclaimer (exact string — do not paraphrase)

```
ผลลัพธ์นี้เป็นเพียงจุดเริ่มต้นในการทำความรู้จักตัวเองเพื่อสำรวจคณะที่ใช่
ความสนใจของคนเราเปลี่ยนแปลงและเติบโตได้เสมอ แนะนำให้ใช้เป็นแนวทางในการ
ลองทำกิจกรรมที่หลากหลาย และปรึกษาครูแนะแนวควบคู่กันไป
```

---

## 8. Dimension → Thai faculty mapping

Store as data in `Core/Career/FacultyMapping.swift`. This is **expert mapping, not empirical research** — say so in the file's header comment, because the research report's own note says the same.

| Dim | Faculties (TCAS naming) | `focusSubjects` |
|---|---|---|
| R | วิศวกรรมศาสตร์ (เครื่องกล · โยธา · โลจิสติกส์) · เกษตรศาสตร์ · สัตวแพทยศาสตร์ · วิทยาศาสตร์การกีฬา · เทคโนโลยีอุตสาหกรรม | ฟิสิกส์ · คณิตศาสตร์ · ชีววิทยา |
| I | แพทยศาสตร์ · ทันตแพทยศาสตร์ · เภสัชศาสตร์ · วิทยาศาสตร์ (ฟิสิกส์/เคมี/ชีววิทยา) · วิทยาการคอมพิวเตอร์ · Data Science | คณิตศาสตร์ · เคมี · ฟิสิกส์ · วิทยาการคำนวณ |
| A | สถาปัตยกรรมศาสตร์ · นิเทศศาสตร์ (ภาพยนตร์/สื่อดิจิทัล) · มัณฑนศิลป์ · ศิลปกรรมศาสตร์ · อักษรศาสตร์ | ศิลปะ · ภาษาไทย · ภาษาต่างประเทศ |
| S | ครุศาสตร์ / ศึกษาศาสตร์ · พยาบาลศาสตร์ · สหเวชศาสตร์ · จิตวิทยา · สังคมสงเคราะห์ศาสตร์ · สาธารณสุขศาสตร์ | สังคมศึกษา · ชีววิทยา · ภาษาไทย |
| E | บริหารธุรกิจ (การตลาด/การจัดการ) · นิติศาสตร์ · รัฐศาสตร์ · การจัดการโรงแรมและการท่องเที่ยว · นิเทศศาสตร์ (โฆษณา/PR) | คณิตศาสตร์ · สังคมศึกษา · ภาษาอังกฤษ |
| C | บัญชี · บริหารธุรกิจ (การเงิน) · โลจิสติกส์และซัพพลายเชน · รัฐประศาสนศาสตร์ · สารสนเทศศาสตร์ / สถิติประยุกต์ | คณิตศาสตร์ (สถิติ) · ภาษาอังกฤษ · วิทยาการคำนวณ |

**Do not put the research report's TCAS69 popularity statistics into the app.** "นิติศาสตร์ 43,218 รายการเลือก" comes from a single blog and dates instantly; it adds nothing to the feature and is easy for a judge to challenge.

---

## 9. Implementation guardrails

- **Deployment target iOS 26.5.** No `if #available` back-compat. No SPM package — if you think you need one, stop and ask.
- **Type-checker.** SwiftUI's "unable to type-check this expression in reasonable time" is the known failure mode in this repo. Keep every `body` under ~40 lines and extract private subviews aggressively: `BarRow`, `LikertButton`, `ResultHeaderCard`, `FacultyCard`. Annotate the type on the 18-item literal array (`static let all: [RIASECItem] = [...]`) and on the faculty dictionary.
- **`RIASECScorer.swift` must not `import SwiftData` or `import SwiftUI`** — `import Foundation` only. It is a pure function so the tests are trivial and fast.
- **Never iterate a `Dictionary` to produce ordered output.** Build from `RIASECDimension.allCases`.
- **Before deleting anything**, `grep` for references and report the result.
- **Do not touch** `TCASPlannerView.swift`, `RootTabView.swift` (unless §7.3 item 5 forces it — in which case ask first), or `project.pbxproj`.

---

## 10. Build & verification

You cannot compile. `xcodebuild` and `swift` are not available in the sandbox and there is no access to the Mac. **Never write "build ผ่าน", "คอมไพล์ได้", or "ทดสอบแล้วใช้งานได้".**

End your hand-off with this block, filled in honestly:

```
เช็คแล้ว:
- <things actually verified, e.g. "grep ยืนยันว่า CareerMatcher ถูกใช้แค่ในไฟล์เดียว">
- <e.g. "คำนวณ §3.3 ด้วยมือซ้ำ ตรงกับตารางในแผน">

ยังไม่ได้เช็ค:
- ยังไม่ได้คอมไพล์ (ผมรัน xcodebuild ไม่ได้)
- <อื่นๆ>

รบกวน Few:
1. ลบแอปออกจาก simulator ก่อน (schema ของ CareerInterestResult เปลี่ยน)
2. กด ⌘B — ถ้าแดง copy error ทั้งก้อนจาก Issue Navigator มาวาง
3. ⌘U เพื่อรัน RIASECScorerTests — ต้องผ่านครบ 9 เคส
4. ถ้าเขียว: หน้าแรก → Career Discovery → เริ่มทำแบบสำรวจ → ตอบ 18 ข้อ → ดูว่าได้ Holland Code + แถบ % ครบ 6 ด้าน
5. ทดสอบ inconclusive: ตอบ "เฉยๆ" ทั้ง 18 ข้อ → ต้องขึ้น "ผลยังไม่ชัดเจนพอ" ไม่ใช่ผลลัพธ์ปกติ
```

### 10.1 Definition of done

| # | Check | Pass condition |
|---|---|---|
| 1 | `⌘U` | all `RIASECScorerTests` green, including `allDimensionsHaveEqualTotalWeight` |
| 2 | Happy path | 18 answers → header shows a 3-letter code, six bars render, none reads 0% or 100% |
| 3 | Flat profile | all "เฉยๆ" → inconclusive card, six equal 50% bars, no crash |
| 4 | Persistence | force-quit, reopen, hub shows the result under "ผลลัพธ์ก่อนหน้า" with a Thai Buddhist-era date |
| 5 | Back navigation | back from question 5 → question 4 with the previous answer still selected |
| 6 | Reset | Settings → reset all data → hub returns to the empty state, app does not crash |
| 7 | Old rows | if any pre-v2 `CareerInterestResult` exists, the history list still renders it without crashing |

---

## 11. Commit

Only after Few confirms the build is green. Otherwise prefix `wip:`.

```
feat: Career Discovery v2 — แบบประเมิน RIASEC 18 ข้อ

- เพิ่ม Core/Career/ (RIASECDimension, RIASECItem, RIASECScorer, FacultyMapping)
- เพิ่ม RIASECQuizView + RIASECResultView, เขียน CareerDiscoveryView ใหม่เป็นหน้า hub
- เพิ่ม field คะแนน 6 มิติ + hollandCode + answers ใน CareerInterestResult
- แก้บั๊กน้ำหนักไม่สมดุลจาก research report (I เคยชนะเสมอ) + เกณฑ์ SD + สูตร %
- เพิ่ม RIASECScorerTests 9 เคส
```

Also update `claude plan/PROJECT_MAP.md` in the same commit: new `Core/Career/` folder, two new views, changed `CareerInterestResult` fields.
