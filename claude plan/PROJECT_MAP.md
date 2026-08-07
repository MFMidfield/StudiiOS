# PROJECT_MAP — Student OS (PrototypeApp)

> แผนที่โปรเจกต์ที่ใช้แทนการ grep/read ซ้ำทุก session
> **อัปเดตล่าสุด:** 2026-08-07 · **ตรวจสอบด้วย:** `find` + `grep` บนซอร์สจริง
> ถ้าแก้โครงสร้าง (เพิ่ม/ลบไฟล์, เพิ่ม @Model, เปลี่ยน tab) → อัปเดตไฟล์นี้ในคอมมิตเดียวกัน

---

## 1. สเปคเทคนิค (ยืนยันจาก project.pbxproj)

| รายการ | ค่า |
|---|---|
| Deployment target | **iOS 26.5** |
| SWIFT_VERSION | 5.0 |
| Bundle ID | `mfmidfield.PrototypeApp` |
| Framework | SwiftUI + SwiftData (ไม่มี dependency ภายนอกเลย) |
| Xcode project | objectVersion 77, ใช้ **file-system-synchronized groups** |
| Test targets | `PrototypeAppTests`, `PrototypeAppUITests` (ยังเป็น template เปล่า) |

**ผลจาก file-system-synchronized groups:** สร้างไฟล์ `.swift` ใหม่ในโฟลเดอร์ = เข้า target อัตโนมัติ **ไม่ต้องแก้ `.pbxproj` เลย** อย่าไปยุ่งกับ pbxproj โดยไม่จำเป็น

**ผลจาก iOS 26.5:** API ของ iOS 17/18/26 ใช้ได้หมด รวม Liquid Glass, `@Observable`, `NavigationStack`, `.scrollTargetBehavior`, SwiftData รุ่นใหม่ — **ไม่ต้องเขียน availability check ย้อนหลัง**

---

## 2. โครงสร้างไฟล์จริง (~55 ไฟล์ Swift)

```
PrototypeApp/                      ← โฟลเดอร์ซอร์ส (ชั้นในของ repo)
├── App/
│   ├── PrototypeAppApp.swift      (72)  @main + Schema + RootContainerView + NotificationManager.shared bootstrap + seed Subject
│   └── RootTabView.swift          (84)  5-tab shell + DashboardDestination
├── Core/
│   ├── DesignSystem/
│   │   ├── Theme.swift            (68)  design tokens + CardContainer + TierBadge
│   │   └── ProUpsellView.swift
│   ├── Entitlements/FeatureTier.swift  (62)  Free/Pro/Plus + EntitlementStore.shared
│   ├── Extensions/
│   │   ├── Color+Hex.swift
│   │   └── Date+Thai.swift              วันที่ไทย/พ.ศ. + thaiShortNoYear/thaiDayMonthYear
│   ├── Logging/AppLog.swift             print-based console log (🔵🟠🔴)
│   ├── Models/                          (13 ไฟล์ — ดูตาราง §3)
│   ├── Notifications/NotificationManager.swift  จัดการ UNUserNotificationCenter — 2 ส่วนแยกกันสิ้นเชิง คนละ identifier prefix
│   │                                            · CalendarEvent: `event-{id}` 1 จุด ตาม EventAlert
│   │                                            · Assignment: `assignment-{uid}-{d1|am|h1}` 3 จุด (1 วันก่อน · 07:00 วันกำหนด · 1 ชม.ก่อน)
│   │                                              `schedule(for:)` ยกเลิกของเดิมให้เองเสมอ → เรียกซ้ำได้ปลอดภัย
│   │                                              `refreshAssignmentReminders(_:)` เรียกจาก RootContainerView ตอนเข้า .active
│   ├── OCR/                             parser ทั้งสองมี overload `onRawBoxes:` คืนกล่องดิบจาก Vision ก่อน heuristic
│   │   │                                (ใช้โดย OCRDebugView) + dump ลง console ทุกครั้งใน DEBUG
│   │   │                                **แยกเป็น overload ไม่ใช่ param ที่มี default** เพราะ trailing closure เดิม
│   │   │                                จะไป bind กับ onRawBoxes แทน completion (Swift forward-scan)
│   │   ├── OCRTextBox.swift             โครงกลาง 1 บรรทัดข้อความ: text + boundingBox + confidence + `candidates: [String]`
│   │   │                                (พิกัด normalized origin ซ้าย**ล่าง** กลับหัวกับ SwiftUI) + `dumpOCRBoxes(_:label:)`
│   │   │                                `candidates` = topCandidates ของ Vision เรียงดีสุดก่อน, `candidates[0] == text` เสมอ
│   │   │                                init มี default → call site ที่ขอ top 1 อย่างเดียวยังคอมไพล์ได้
│   │   ├── SubjectCodeValidator.swift   ไวยากรณ์รหัสวิชาไทย (พยัญชนะ 1 + เลข 5)
│   │   │                                `confusionMap` = คู่ที่**ยืนยันจากรูปจริง** (ตัวเลือกเดียว = ซ่อมอัตโนมัติ)
│   │   │                                `shapeOnlyConfusionMap` = เดาจากรูปทรงล้วน (4→ง, 6→ค, A→ค, a→ส, N→พ, n→ก/ท, ด→ค)
│   │   │                                → **ติดธงเสมอ ไม่ซ่อมอัตโนมัติ** แม้มีตัวเลือกเดียว
│   │   │                                `looksLikeCode` = 6 ตัวเป๊ะ (เส้นทางซ่อม) · `looksLikeCodeSlot` = 5–7 ตัว + เลขติดกัน ≥4 (เส้นทางติดธง)
│   │   │                                `SubjectCodeLedger` = โหวตข้ามภาพ — key คือ**เลข 5 ตัวท้าย** และต้อง**เอกฉันท์**
│   │   │                                  ⚠️ ห้ามเปลี่ยนเป็น majority: tail `32101` ในรูปอ้างอิงใช้ร่วมกัน 6 วิชา (ท ค พ อ ศ ส)
│   │   │                                  หลักฐานนับเฉพาะรหัสที่ถูกต้องอยู่แล้ว (`.alreadyValid`) — ของที่ซ่อมมาห้ามเป็นหลักฐาน
│   │   │                                  ครู↔รหัส ตรวจก่อน sheet-wide เพราะกู้ tail ที่ใช้ร่วมกันได้
│   │   │                                ⚠️ **ห้ามใช้ `confidence` เลือก candidate** — วัดจากรูปจริงแล้วมันกลับด้าน
│   │   │                                (รหัสที่ผิดทุกตัว conf 1.00 · ที่ถูกหลายตัว conf 0.50) รายละเอียดใน `PLAN_OCRAccuracy.md` §0.2
│   │   ├── CellFieldValidator.swift     ไวยากรณ์ของฟิลด์ที่**ไม่ใช่**รหัสวิชา — ชื่อครู · ห้อง · รวมชื่อครูที่สะกดต่างกัน
│   │   │                                `teacher(in:)` ซ่อม `ครวรัญญา`→`ครูวรัญญา` (สระ ู หาย) · ตัดจุดท้าย · ติดธงถ้ามีอักษรละติน (`ครูA`)
│   │   │                                `canonicalTeacherNames` edit distance ≤1 = คนเดียวกัน (`ครูจริยา`/`ครูจาริยา`) **ต้องรันก่อนโหวตรหัส**
│   │   │                                หมายเหตุ: `Character` ไทย = grapheme cluster → `"ครู".count == 2` โค้ดทั้งไฟล์อาศัยข้อนี้
│   │   ├── TableGridBuilder.swift       **หัวใจของ OCR ตารางเรียน** — เปลี่ยน [OCRTextBox] เป็นกริดจริง
│   │   │                                auto-detect orientation (วันเป็นแถวหรือคอลัมน์ — **ห้าม hardcode**)
│   │   │                                → fit `pos = origin + step·index` จาก **คำที่ซ้ำหนึ่งครั้งต่อแถว**
│   │   │                                  (`โฮมรูม`/`พัก`) ไม่ใช่ชื่อวัน เพราะชื่อวันคือสิ่งที่ Vision อ่านไม่ออก
│   │   │                                → กู้แถว/คอลัมน์ที่อ่านไม่ออกกลับมาจากเส้นที่ fit ได้
│   │   │                                คืน `OCRTableGrid` (dayAxis/periodAxis/dayNumbers/periodTimes/cells)
│   │   │                                รวมงาน: แยกกล่องที่คร่อมหลายคอลัมน์ · กรองหัว/ท้ายกระดาษ (ตกนอกกริด)
│   │   │                                · รวมช่องหลายบรรทัด (ตกช่องเดียวกันเอง) · เวลาต้องเป็นช่วง start<end 20–180 นาที
│   │   ├── ScheduleOCRParser.swift      ScheduleDraftEntry ใช้ startMinute/endMinute (Int)
│   │   │                                + `periodNumber` `teacherName` `room` `needsReview` `reviewOptions` (มี default ครบ)
│   │   │                                `classifySubjectCode(_:)` = **จุดเดียว**ที่ตัดสินรหัสวิชา (`.notACode` = ช่องนี้ไม่ใช่ช่องรหัส)
│   │   │                                `buildDraftSchedule` = TableGridBuilder → `readCell` (รหัส/ครู/ห้อง/กิจกรรม)
│   │   │                                → `unifyTeacherNames` → `applyCrossImageVote` (ลำดับนี้ห้ามสลับ)
│   │   │                                `CellContent` แยก `codeNeedsReview` กับ `fieldNeedsReview` — โหวตล้างได้แค่ตัวแรก
│   │   │                                `parseScheduleDetailed` คืน `ScheduleOCRResult` (entries + problem บอกสาเหตุ)
│   │   │                                `usesLanguageCorrection` เป็น static var ไว้ A/B (PLAN_OCRFix C5)
│   │   └── GradeReportOCRParser.swift
│   ├── Profile/StudentProfileStore.swift (71)
│   ├── Schedule/PeriodShiftCalculator.swift  logic ล้วน (ไม่มี View): date(forDay:in:) + apply(override:to:) → [ResolvedPeriod]
│   └── Tasks/AssignmentPriorityEngine.swift  logic ล้วน: priority(kind:dueDate:) + daysUntil() + dueLabel() — สูตรความสำคัญอัตโนมัติที่เดียว
└── Features/
    ├── Calendar/CalendarView.swift        (687) ← ไฟล์ใหญ่สุด
    ├── CareerDiscovery/CareerDiscoveryView.swift (163)
    ├── Dashboard/DashboardView.swift      (350)
    ├── GradeCenter/GradeCenterView.swift  (183)
    ├── Onboarding/  (6 ไฟล์: Welcome→Profile→Schedule→GradeReport→Summary + ProfileImagePicker)
    ├── Portfolio/   PortfolioView.swift (89) + FocusModeView.swift (133) ⚠️ FocusMode วางผิดโฟลเดอร์
    ├── Schedule/  ScheduleView.swift (root) + ScheduleConstants.swift (visibleDays/dayLabels/findOrCreateSubject)
    │              + ScheduleDayPickerBar · ScheduleTimetableSection (ใช้ [ResolvedPeriod]) · SchedulePeriodRow · ScheduleBreakRow
    │              + AddScheduleEntrySheet (add/edit ใช้ร่วม) · AddSubjectSheet
    │              + ScheduleTodayTasksSection (งาน/การบ้านวันนี้ ผูก Assignment.subjectName แบบ lookup ชื่อ)
    │              + PeriodShiftBanner · PeriodShiftSheet (ร่นคาบ — ใช้ PeriodShiftCalculator ที่เดียว ไม่มีสูตรซ้ำใน View)
    ├── QuickAdd/QuickAddSheet.swift       (~340) half-sheet เมนู "เพิ่มอะไรดี?" (กริดไอคอน) ที่เด้งตอนกดปุ่ม `+` กลาง tab
    │                                              งาน → AddTaskSheet · ปฏิทิน/โน๊ต/Portfolio → CaptureDetailSheet (private ในไฟล์เดียวกัน)
    │                                              **เพิ่มโหมดใหม่ = เพิ่ม 1 บรรทัดใน `options`** (แทน SmartCaptureView เดิมที่ถูกลบ)
    ├── Settings/
    │   ├── SettingsView.swift             (~375) section "สำหรับนักพัฒนา" อยู่ใน `developerSection`
    │   │                                         (computed property เพราะ `#if DEBUG` ใน ViewBuilder ทำ type-check เพี้ยน)
    │   └── OCRDebugView.swift             ทั้งไฟล์ครอบ `#if DEBUG` — เลือกรูป → ดูทุกกล่องที่ Vision อ่านได้ + confidence
    │                                      ไม่ขึ้นใน Release · ไม่มี overlay (รอรอบ 2 ตาม PLAN_OCRDebug.md)
    │                                      โหมด "ตารางเรียน" ต่อท้ายแต่ละแถวด้วยผลของ `classifySubjectCode`
    │                                      (`✅ ซ่อมแล้ว` / `⚠️ กำกวม` / `✓ ถูกอยู่แล้ว`) + บรรทัดสรุปนับรวม
    │                                      + **รายการตารางที่ parse ได้จริง** (วัน · คาบ · เวลา · วิชา · ครู · ห้อง · ⚠️)
    │                                      และข้อความ problem จาก `ScheduleOCRResult` เวลาหากริด/เวลาไม่เจอ
    │                                      → นี่คือเครื่องมือวัดผลของ PLAN_OCRAccuracy และ PLAN_OCRFix
    ├── Tasks/   หน้า "งาน / การบ้าน" ทั้งโมดูล
    │   ├── AssignmentListView.swift   (~330) root ของหน้า — ประกอบ chips + สถิติ + section + FAB + ค้นหา
    │   │                                     ใช้ `List(.plain)` + `plainRow()` (ซ่อนเส้น/พื้นแถว) เพื่อให้ได้การ์ดลอย **และ** ปัดซ้ายลบได้
    │   ├── TaskScope.swift            (~95)  **นิยามเงื่อนไข chip/สถิติที่เดียวของทั้งหน้า** + TaskKindFilter + TaskSortOrder
    │   │                                     ห้ามเขียนสูตร "ใกล้ถึงกำหนด"/"เลยกำหนด" ซ้ำที่อื่น
    │   ├── TaskFilterChips.swift      (~70)  chip 4 อัน + ปุ่ม "กรอง" (มีจุดบอกว่ามีตัวกรองทำงานอยู่)
    │   ├── TaskStatsRow.swift         (~70)  การ์ดสถิติ 4 ใบ กดแล้วสลับ chip
    │   ├── TaskRowCard.swift          (~145) การ์ดงาน 1 แถว — วงกลม toggle · ไอคอนวิชา · ป้ายวัน · ขอบแดงถ้าเลยกำหนด
    │   ├── TaskFilterSheet.swift      (~90)  ประเภท · วิชา · เฉพาะเลยกำหนด · เรียงตาม
    │   └── AddTaskSheet.swift         (~215) ฟอร์มเพิ่ม/แก้งาน `AddTaskSheet(editing:onSaved:)`
    │                                         ทางเข้า: QuickAddSheet · การ์ด "งานค้าง" ใน Dashboard · FAB ในหน้านี้
    └── TCASPlanner/TCASPlannerView.swift  (142)
```

---

## 3. SwiftData Models (17 @Model — ทั้งหมดต้องอยู่ใน Schema)

Schema ประกาศที่ `App/PrototypeAppApp.swift:15-33`

| Model | ไฟล์ |
|---|---|
| Assignment | Core/Models/Assignment.swift — `subjectName: String` (default "") · `kindRaw` (การบ้าน/งานทั่วไป) · `hasDueDate` (default **true**) · `isPriorityManual` · `remindersEnabled` · `uid` (เติมด้วย `ensureUID()`)<br>**อ่านวันส่งผ่าน `resolvedDueDate` เท่านั้น** (nil = ไม่กำหนด) · ความสำคัญใช้ `effectivePriority` (auto จาก `AssignmentPriorityEngine`, ห้าม cache ลง `priorityRaw`) |
| Note | Core/Models/Note.swift |
| Flashcard | Core/Models/Flashcard.swift |
| GradeComponent | Core/Models/GradeComponent.swift |
| ExamEvent | Core/Models/ExamEvent.swift |
| ScheduleEntry | Core/Models/ScheduleEntry.swift — เวลาเป็น `startMinute`/`endMinute: Int` (ไม่ใช่ Date แล้ว) + `subject: Subject?` relationship |
| Subject | Core/Models/Subject.swift — วิชา/ช่วงพัก (`isBreak`), seed 3 ตัวตอนเปิดแอปครั้งแรก |
| DayScheduleOverride | Core/Models/DayScheduleOverride.swift — ร่นคาบเฉพาะวัน จัดการผ่าน `PeriodShiftSheet`/`PeriodShiftBanner`, คำนวณผ่าน `PeriodShiftCalculator` เท่านั้น (ไม่แก้ `ScheduleEntry` จริง) |
| FocusSession | Core/Models/FocusSession.swift |
| PortfolioItem | Core/Models/PortfolioItem.swift |
| CareerInterestResult | Core/Models/CareerInterestResult.swift |
| TCASEntry + TCASChecklistItem | Core/Models/TCASEntry.swift |
| SemesterRecord | Core/Models/SemesterRecord.swift |
| CalendarEvent + CalendarTag + CalendarAttachmentItem | Features/Calendar/CalendarView.swift ⚠️ model ฝังอยู่ในไฟล์ view |

**กฎเหล็ก:** เพิ่ม `@Model` ใหม่ → ต้องเพิ่มใน `Schema([...])` ด้วย ไม่งั้น crash ตอนรัน
และต้องเพิ่มใน `SettingsView.resetAllData()` ด้วย (เคยลืมมาแล้วกับ Calendar 3 ตัว)
`resetAllData()` ลบ `Subject` แล้วเรียก `PrototypeAppApp.seedBuiltInSubjects(in:)` ทันทีเพื่อ reseed 3 วิชาเริ่มต้น — ถ้าเพิ่ม built-in subject ใหม่ ต้องแก้ทั้งสองจุด (seed function + resetAllData ยังคงเรียก function เดิม จุดเดียวพอ)

---

## 4. Navigation (RootTabView.swift)

5 tabs: `dashboard` · `calendar` · `capture` · `schedule` · `settings`

- แท็บ "เพิ่ม" (`.capture`) เป็น `Color.clear` + trick: `onChange` ดีดกลับแท็บเดิมแล้วเปิด **`QuickAddSheet`** เป็น sheet
  → ผู้ใช้เลือกก่อนว่าจะเพิ่มอะไร (งาน / ปฏิทิน / โน๊ต / Portfolio) แล้วค่อยเปิดฟอร์ม
  **นี่คือทางเข้าเดียวของ ปฏิทิน/โน๊ต/Portfolio** — ถ้าเปลี่ยนปุ่มนี้ให้เปิดฟอร์มใดฟอร์มหนึ่งตรงๆ อีก 3 โหมดจะกลายเป็นโค้ดตาย
- Dashboard push ต่อผ่าน `DashboardDestination`: `.assignments` `.gradeCenter` `.tcasPlanner` `.portfolio` `.careerDiscovery` `.focusMode`
- Onboarding gate อยู่ที่ `RootContainerView` (`PrototypeAppApp.swift:53-74`) ใช้ `@AppStorage` 5 ตัวเรียงลำดับหน้า
- แท็บ "ตารางเรียน" (`ScheduleView`) toolbar มี 2 ปุ่ม: นาฬิกา (ซ้าย) เปิด `PeriodShiftSheet` (ร่นคาบ) · `+` (ขวา) เปิด `AddScheduleEntrySheet` (เพิ่ม/แก้คาบ, หรือแตะแถวคาบเพื่อแก้) → ซ้อน `AddSubjectSheet` (เพิ่มวิชาใหม่, เปิดจากปุ่ม "เพิ่มวิชาใหม่" ในฟอร์มคาบ)
- `ScheduleTodayTasksSection` แสดง **เฉพาะการบ้าน** เป็นค่าเริ่มต้น — สลับด้วย `@AppStorage("scheduleShowsPersonalTasks")` (Toggle อยู่ใน Settings section "ตารางเรียน")
- `ScheduleTodayTasksSection`'s "ดูทั้งหมด" push ตรงไป `AssignmentListView()` ด้วย plain `NavigationLink` (ไม่ใช้ `DashboardDestination` enum เพราะ Schedule tab มี `NavigationStack` แยกจาก Dashboard — ปลายทางเดียวไม่คุ้มความซับซ้อนของ enum-based navigation)

---

## 5. Design tokens (Core/DesignSystem/Theme.swift)

```
Theme.Colors:  primary #4A7DFF · danger #FF6B6B · warning #FFB347 · success #4CAF50
               info #00BCD4 · purple #9C27B0 · pink #E91E63 · indigo #3F51B5
               textPrimary #1A1A2E · background #F5F6FA · cardBackground .white
               breakBackground #FFF8E7 · separator #E8EAF0 · textSecondary #6B7280
               subjectPalette / subjectPaletteHex — 8 สีให้เลือกตอนสร้างวิชา (หมุนตามลำดับนี้)
Theme.Spacing: xs 4 · sm 8 · md 12 · lg 16 · xl 20 · xxl 24
Theme.Radius:  card 16 · control 12
Components:    CardContainer<Content>  ·  TierBadge(tier:)
```

**ห้าม hardcode สี/ระยะห่างใน View** — ถ้าโทเคนที่ต้องการยังไม่มี ให้เพิ่มใน Theme ก่อน

---

### ไฟล์ Figma อ้างอิง

**Student OS — UI Frames** · `7qTFOazJhInRwMm7viQbGr` · https://www.figma.com/design/7qTFOazJhInRwMm7viQbGr

18 เฟรมเปล่า (iPhone 16 Pro 402×874) ชื่อตรงกับ struct ใน Swift 1:1 + design tokens 19 ตัวที่ผูกกับ `Theme.swift`
โครง: `01 Screens` (Onboarding 5 / Main Tabs 5) · `02 Sub-screens` (Dashboard 6 / Overlays 2) · `99 Design Tokens`

---

## 6. Entitlements

`EntitlementStore.shared.isUnlocked(.pro)` — ปัจจุบันเป็น toggle ทดสอบใน Settings ยังไม่มี StoreKit จริง
Gated: `PortfolioView`, `TCASPlannerView`

---

## 7. เอกสารในโปรเจกต์ — ระวังของเก่า

| ไฟล์ | สถานะ |
|---|---|
| `StudentOS_รวมเอกสาร.md` | **สโคป/vision — ยังใช้อ้างอิงได้** (เป้าหมาย ไม่ใช่สถานะจริง) |
| `session-2026-07-28-restructure.md` | log เก่า — อธิบายเวอร์ชันที่ยังมี Subject/Chapter/BinderAttachment |
| `PrototypeApp/PrototypeApp_Audit_Report.md` | ⚠️ **ล้าสมัย** อ้างถึง 45 ไฟล์/6,857 บรรทัด และไฟล์ที่ไม่มีแล้ว (`SubjectDetailView`, `DigitalBinderView`, `GPAPlannerView`, `Subject.swift`) — **ห้ามเชื่อโดยไม่ verify กับซอร์สจริง** |
| `PrototypeApp/SchedulePage_Prompt.md` | prompt ของหน้า Schedule |

---

## 8. หนี้ทางเทคนิคที่รู้อยู่แล้ว (ยังไม่ได้แก้)

- ไม่มี `QuickLook` / `ShareLink` — ไฟล์ที่ SmartCapture copy ลง `Documents/SmartCapture/` เปิดดูจาก UI ไม่ได้
- `FocusModeView.swift` อยู่ใน `Features/Portfolio/` (วางผิดที่)
- Calendar models ฝังใน `CalendarView.swift` แทนที่จะอยู่ `Core/Models/`
- ไม่มี unit test จริงเลย (test target เป็น template)
- `QuickAddSheet.swift`'s `calendarFields` มี label ภาษาอังกฤษหลงเหลือ (`Repeat` `Location` `Tags` `Alert` `Note` `Detail`) — ผิดกฎ "UI ทั้งหมดเป็นภาษาไทย" ของสกิล ยกมาทั้งดุ้นจาก `SmartCaptureView` เดิม ยังไม่ได้แก้
- `Features/FocusMode/` เป็นโฟลเดอร์ว่าง (ของเหลือ) — `FocusModeView.swift` ยังอยู่ใน `Features/Portfolio/`
- `ScheduleTodayTasksSection`: แตะแถวงาน ตอนนี้แค่ log อย่างเดียว ยังไม่เปิดฟอร์มแก้ไข (หน้า Todo เปิดได้แล้ว — เหลือแค่การ์ดในตารางเรียน)
- **`PLAN_OCRFix.md` ครบทั้ง 2 รอบแล้ว** เหลืออย่างเดียวคือ **UI ให้ผู้ใช้แก้ช่องที่ติดธง ⚠️**
  `needsReview` / `reviewOptions` ไหลถึง `ScheduleSetupView` แล้วแต่หน้ายังไม่ได้ใช้ → ผู้ใช้ยังไม่รู้ว่าช่องไหนต้องตรวจ
  (ขัดกับหลักของแผนเอง `PLAN_OCRDebug.md` §6.7 "ผู้ใช้ไม่รู้ว่า 3 ช่องผิด = UX ที่แย่") · `ocrFoundNothing` ยังไม่ได้ใช้ `ScheduleOCRResult.problem`
- `refreshAssignmentReminders` ตัดที่ 16 งานแรก (× 3 จุด = 48 pending) กันชน 64 ของ iOS — งานที่กำหนดส่งไกลกว่านั้นจะยังไม่ถูกตั้งจนกว่าจะขยับเข้ามาในหน้าต่าง 14 วัน

**`PLAN_ScheduleView.md` ครบทั้ง 3 รอบแล้ว** (Models/Schema → UI ตาราง+ฟอร์ม → งานวันนี้+ร่นคาบ) — ฟีเจอร์ตารางเรียนถือว่าสมบูรณ์ตามแผน รอ Few verify build จริงก่อนตัดสินใจงานต่อไป
