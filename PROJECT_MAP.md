# PROJECT_MAP — Student OS (PrototypeApp)

> แผนที่โปรเจกต์ที่ใช้แทนการ grep/read ซ้ำทุก session
> **อัปเดตล่าสุด:** 2026-08-03 · **ตรวจสอบด้วย:** `find` + `grep` บนซอร์สจริง
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

## 2. โครงสร้างไฟล์จริง (53 ไฟล์ Swift, ~6,600+ บรรทัด)

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
│   ├── Notifications/NotificationManager.swift  จัดการ UNUserNotificationCenter: schedule/cancel ตาม CalendarEvent + ปุ่มทดสอบแจ้งเตือน
│   ├── OCR/
│   │   ├── ScheduleOCRParser.swift      (130)  ScheduleDraftEntry ใช้ startMinute/endMinute (Int)
│   │   └── GradeReportOCRParser.swift   (147)
│   ├── Profile/StudentProfileStore.swift (71)
│   └── Schedule/PeriodShiftCalculator.swift  logic ล้วน (ไม่มี View): date(forDay:in:) + apply(override:to:) → [ResolvedPeriod]
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
    ├── Settings/SettingsView.swift        (357)
    ├── SmartCapture/SmartCaptureView.swift (314+)  มี Picker "วิชา" ใน assignmentFields แล้ว (ไม่บังคับ, default "ไม่ระบุ")
    ├── SubjectHub/AssignmentListView.swift (64)
    └── TCASPlanner/TCASPlannerView.swift  (142)
```

---

## 3. SwiftData Models (17 @Model — ทั้งหมดต้องอยู่ใน Schema)

Schema ประกาศที่ `App/PrototypeAppApp.swift:15-33`

| Model | ไฟล์ |
|---|---|
| Assignment | Core/Models/Assignment.swift — มี `subjectName: String` (default "") |
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

- แท็บ "เพิ่ม" (`.capture`) เป็น `Color.clear` + trick: `onChange` ดีดกลับแท็บเดิมแล้วเปิด `SmartCaptureView` เป็น sheet
- Dashboard push ต่อผ่าน `DashboardDestination`: `.assignments` `.gradeCenter` `.tcasPlanner` `.portfolio` `.careerDiscovery` `.focusMode`
- Onboarding gate อยู่ที่ `RootContainerView` (`PrototypeAppApp.swift:53-74`) ใช้ `@AppStorage` 5 ตัวเรียงลำดับหน้า
- แท็บ "ตารางเรียน" (`ScheduleView`) toolbar มี 2 ปุ่ม: นาฬิกา (ซ้าย) เปิด `PeriodShiftSheet` (ร่นคาบ) · `+` (ขวา) เปิด `AddScheduleEntrySheet` (เพิ่ม/แก้คาบ, หรือแตะแถวคาบเพื่อแก้) → ซ้อน `AddSubjectSheet` (เพิ่มวิชาใหม่, เปิดจากปุ่ม "เพิ่มวิชาใหม่" ในฟอร์มคาบ)
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
- `SmartCaptureView.swift`'s `calendarFields` มี label ภาษาอังกฤษหลงเหลือ (`Repeat` `Location` `Tags` `Alert` `Note` `Detail`) — ผิดกฎ "UI ทั้งหมดเป็นภาษาไทย" ของสกิล พบระหว่างแก้รอบ 3 แต่ไม่ได้อยู่ในสโคปที่ขอ ยังไม่ได้แก้
- `ScheduleTodayTasksSection`: แตะแถวงาน ตอนนี้แค่ log อย่างเดียว ยังไม่ push ไปหน้ารายละเอียด (ตั้งใจเก็บไว้ทำทีหลังตาม `PROMPT_ScheduleView_Round3.md`)

**`PLAN_ScheduleView.md` ครบทั้ง 3 รอบแล้ว** (Models/Schema → UI ตาราง+ฟอร์ม → งานวันนี้+ร่นคาบ) — ฟีเจอร์ตารางเรียนถือว่าสมบูรณ์ตามแผน รอ Few verify build จริงก่อนตัดสินใจงานต่อไป
