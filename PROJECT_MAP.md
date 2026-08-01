# PROJECT_MAP — Student OS (PrototypeApp)

> แผนที่โปรเจกต์ที่ใช้แทนการ grep/read ซ้ำทุก session
> **อัปเดตล่าสุด:** 2026-08-01 · **ตรวจสอบด้วย:** `find` + `grep` บนซอร์สจริง
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

## 2. โครงสร้างไฟล์จริง (38 ไฟล์ Swift, ~4,666 บรรทัด)

```
PrototypeApp/                      ← โฟลเดอร์ซอร์ส (ชั้นในของ repo)
├── App/
│   ├── PrototypeAppApp.swift      (72)  @main + Schema + RootContainerView
│   └── RootTabView.swift          (84)  5-tab shell + DashboardDestination
├── Core/
│   ├── DesignSystem/
│   │   ├── Theme.swift            (68)  design tokens + CardContainer + TierBadge
│   │   └── ProUpsellView.swift
│   ├── Entitlements/FeatureTier.swift  (62)  Free/Pro/Plus + EntitlementStore.shared
│   ├── Extensions/
│   │   ├── Color+Hex.swift
│   │   └── Date+Thai.swift              วันที่ไทย/พ.ศ.
│   ├── Models/                          (11 ไฟล์ — ดูตาราง §3)
│   ├── OCR/
│   │   ├── ScheduleOCRParser.swift      (140)
│   │   └── GradeReportOCRParser.swift   (147)
│   └── Profile/StudentProfileStore.swift (71)
└── Features/
    ├── Calendar/CalendarView.swift        (687) ← ไฟล์ใหญ่สุด
    ├── CareerDiscovery/CareerDiscoveryView.swift (163)
    ├── Dashboard/DashboardView.swift      (350)
    ├── GradeCenter/GradeCenterView.swift  (183)
    ├── Onboarding/  (6 ไฟล์: Welcome→Profile→Schedule→GradeReport→Summary + ProfileImagePicker)
    ├── Portfolio/   PortfolioView.swift (89) + FocusModeView.swift (133) ⚠️ FocusMode วางผิดโฟลเดอร์
    ├── Schedule/ScheduleView.swift
    ├── Settings/SettingsView.swift        (357)
    ├── SmartCapture/SmartCaptureView.swift (314)
    ├── SubjectHub/AssignmentListView.swift (64)
    └── TCASPlanner/TCASPlannerView.swift  (142)
```

---

## 3. SwiftData Models (15 @Model — ทั้งหมดต้องอยู่ใน Schema)

Schema ประกาศที่ `App/PrototypeAppApp.swift:15-31`

| Model | ไฟล์ |
|---|---|
| Assignment | Core/Models/Assignment.swift |
| Note | Core/Models/Note.swift |
| Flashcard | Core/Models/Flashcard.swift |
| GradeComponent | Core/Models/GradeComponent.swift |
| ExamEvent | Core/Models/ExamEvent.swift |
| ScheduleEntry | Core/Models/ScheduleEntry.swift |
| FocusSession | Core/Models/FocusSession.swift |
| PortfolioItem | Core/Models/PortfolioItem.swift |
| CareerInterestResult | Core/Models/CareerInterestResult.swift |
| TCASEntry + TCASChecklistItem | Core/Models/TCASEntry.swift |
| SemesterRecord | Core/Models/SemesterRecord.swift |
| CalendarEvent + CalendarTag + CalendarAttachmentItem | Features/Calendar/CalendarView.swift ⚠️ model ฝังอยู่ในไฟล์ view |

**❗ ไม่มี `Subject` model แล้ว** — เมื่อก่อนเคยเป็นโมเดลศูนย์กลาง ตอนนี้ถูกถอดออก
`Chapter` และ `BinderAttachment` ก็ไม่มีแล้วเช่นกัน

**กฎเหล็ก:** เพิ่ม `@Model` ใหม่ → ต้องเพิ่มใน `Schema([...])` ด้วย ไม่งั้น crash ตอนรัน
และต้องเพิ่มใน `SettingsView.resetAllData()` ด้วย (เคยลืมมาแล้วกับ Calendar 3 ตัว)

---

## 4. Navigation (RootTabView.swift)

5 tabs: `dashboard` · `calendar` · `capture` · `schedule` · `settings`

- แท็บ "เพิ่ม" (`.capture`) เป็น `Color.clear` + trick: `onChange` ดีดกลับแท็บเดิมแล้วเปิด `SmartCaptureView` เป็น sheet
- Dashboard push ต่อผ่าน `DashboardDestination`: `.assignments` `.gradeCenter` `.tcasPlanner` `.portfolio` `.careerDiscovery` `.focusMode`
- Onboarding gate อยู่ที่ `RootContainerView` (`PrototypeAppApp.swift:53-74`) ใช้ `@AppStorage` 5 ตัวเรียงลำดับหน้า

---

## 5. Design tokens (Core/DesignSystem/Theme.swift)

```
Theme.Colors:  primary #4A7DFF · danger #FF6B6B · warning #FFB347 · success #4CAF50
               info #00BCD4 · purple #9C27B0 · pink #E91E63 · indigo #3F51B5
               textPrimary #1A1A2E · background #F5F6FA · cardBackground .white
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

- ไม่มี `UNUserNotificationCenter` เลย — reminder ของ CalendarEvent เก็บค่าแต่ไม่เคยยิงจริง (`Info.plist` ประกาศ `remote-notification` ไว้แล้ว)
- ไม่มี `QuickLook` / `ShareLink` — ไฟล์ที่ SmartCapture copy ลง `Documents/SmartCapture/` เปิดดูจาก UI ไม่ได้
- `SettingsView.resetAllData()` เคยลืมลบโมเดล Calendar — ตรวจซ้ำทุกครั้งที่เพิ่ม model
- `FocusModeView.swift` อยู่ใน `Features/Portfolio/` (วางผิดที่)
- Calendar models ฝังใน `CalendarView.swift` แทนที่จะอยู่ `Core/Models/`
- ไม่มี unit test จริงเลย (test target เป็น template)
