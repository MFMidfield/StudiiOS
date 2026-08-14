# PROJECT_MAP — Student OS (StudiiOS)

> แผนที่โปรเจกต์ที่ใช้แทนการ grep/read ซ้ำทุก session
> **อัปเดตล่าสุด:** 2026-08-14 — **PLAN_Redesign.md Wave 1** (branch `redesign`): token terracotta ชุดใหม่ +
> `Theme.Font` + คอมโพเนนต์ `PillLabel`/`IconTile`/`SectionHeader` + Dashboard ทั้งหน้า + tab bar
> (ดู §5 Design tokens · Dashboard ใน §2 · §4 Navigation) — วันเดียวกัน: รีแบรนด์ทั้งโปรเจกต์จาก PrototypeApp
> เป็น **Studii OS** (target/project/bundle ID เปลี่ยนเป็น `StudiiOS`/`mfmidfield.StudiiOS`,
> `CFBundleDisplayName` = "Studii OS") — ก่อนหน้านั้น 2026-08-10 —
> Dashboard redesign: dark mode (Theme.Colors adaptive ทั้งหมด) + คาบเรียนถัดไป
> + ติ๊กงานเสร็จตรงจากการ์ด + animation เข้าหน้า (ดู §5 Design tokens + Dashboard ใน §2) · ก่อนหน้านั้น
> PLAN_TCASPlanner ครบทั้ง 4 รอบแล้ว — models ใหม่ → TCASScoreEngine/เทสต์ → ลิสต์คณะ/ตั้งน้ำหนัก/คะแนนของฉัน →
> SOPEditorView/SOPGuideSheet · โมดูล TCAS Planner ถือว่าสมบูรณ์ตามแผน รอ Few verify build จริง
> **ไฟล์แผนทั้งหมด (`PLAN_*.md` / `PROMPT_*.md`) ย้ายไปอยู่ใน `claude plan/` แล้ว** — ยกเว้น `PLAN_Redesign.md`
> ที่ยังทำอยู่ (อยู่รากrepo) · สเปคหน้าจอ Wave 2 อยู่ใน `docs/redesign/`
> **ตรวจสอบด้วย:** `find` + `grep` บนซอร์สจริง
> ถ้าแก้โครงสร้าง (เพิ่ม/ลบไฟล์, เพิ่ม @Model, เปลี่ยน tab) → อัปเดตไฟล์นี้ในคอมมิตเดียวกัน

---

## 1. สเปคเทคนิค (ยืนยันจาก project.pbxproj)

| รายการ | ค่า |
|---|---|
| Deployment target | **iOS 26.5** |
| SWIFT_VERSION | 5.0 |
| Bundle ID | `mfmidfield.StudiiOS` |
| Framework | SwiftUI + SwiftData (ไม่มี dependency ภายนอกเลย) |
| Xcode project | objectVersion 77, ใช้ **file-system-synchronized groups** |
| Test targets | `StudiiOSTests`, `StudiiOSUITests` (ยังเป็น template เปล่า) |

**ผลจาก file-system-synchronized groups:** สร้างไฟล์ `.swift` ใหม่ในโฟลเดอร์ = เข้า target อัตโนมัติ **ไม่ต้องแก้ `.pbxproj` เลย** อย่าไปยุ่งกับ pbxproj โดยไม่จำเป็น

**ผลจาก iOS 26.5:** API ของ iOS 17/18/26 ใช้ได้หมด รวม Liquid Glass, `@Observable`, `NavigationStack`, `.scrollTargetBehavior`, SwiftData รุ่นใหม่ — **ไม่ต้องเขียน availability check ย้อนหลัง**

---

## 2. โครงสร้างไฟล์จริง (~60 ไฟล์ Swift)

```
StudiiOS/                      ← โฟลเดอร์ซอร์ส (ชั้นในของ repo)
├── App/
│   ├── StudiiOSApp.swift      (72)  @main + Schema + RootContainerView + NotificationManager.shared bootstrap + seed Subject
│   └── RootTabView.swift          (87)  5-tab shell (หน้าแรก·งาน·+·ตารางสอน·ตั้งค่า) + DashboardDestination
├── Core/
│   ├── DesignSystem/
│   │   ├── Theme.swift           (180)  design tokens + Theme.Font + CardContainer + TierBadge + PressScaleButtonStyle
│   │   ├── PillLabel.swift        (78)  ป้ายแคปซูล 5 tone (accent/neutral/danger/warning/custom)
│   │   ├── IconTile.swift         (56)  SF Symbol บนพื้นสี่เหลี่ยมมน — ปรับ size/tint/background/radius ได้
│   │   ├── SectionHeader.swift    (76)  หัวข้อ section + trailing ViewBuilder + SectionMoreLabel
│   │   └── ProUpsellView.swift
│   ├── Entitlements/FeatureTier.swift  (62)  Free/Pro/Plus + EntitlementStore.shared
│   ├── Extensions/
│   │   ├── Color+Hex.swift
│   │   └── Date+Thai.swift              วันที่ไทย/พ.ศ. + thaiShortNoYear/thaiDayMonthYear
│   ├── Grades/                          Level 1 GPAX (PLAN_GPA.md) — ตัวเลขคำนวณจากเทอมที่กรอกเองเท่านั้น
│   │   │                                ไม่แตะ GradeComponent/SemesterRecord (คนละ Level กัน ดู §12 ของแผน)
│   │   ├── GPAXCalculator.swift  (166)  math ล้วน ไม่ import SwiftUI/SwiftData — เทสต์ได้โดยไม่ต้องมี ModelContainer
│   │   │                                `TermInput` เป็น struct เปล่าคัดลอกจาก Term.gpa/totalCredits (ไม่ใช่ Term เอง)
│   │   │                                `calculate(terms:currentSortKey:target:cumulative:)` คืน `Result` (gpax/floor/ceiling/
│   │   │                                requiredAverage/state/provenance) · `state` เป็น `State?` — nil เฉพาะกรณีมีข้อมูลแล้ว
│   │   │                                แต่ยังไม่ตั้งเป้า (ไม่ใช่ `.noData`) · ปัดเลขแสดงผลผ่าน `.formatted`/`.rounded` เท่านั้น
│   │   │                                ห้ามปัดเลขระหว่างคำนวณ (§3.5 ของแผน)
│   │   └── GPAXSettings.swift    (106)  จุดเดียวที่รู้จัก UserDefaults key ของ GPAX (`Key.*`) เหมือน PomodoroSettings
│   │                                    `currentGradeLevel`/`currentTermNumber` = เทอม**จริง**ของนักเรียน (D7) — คนละตัวกับ
│   │                                    `TermStore.activeTermKey` (เทอมที่กำลังเปิดดู) **ห้ามใช้แทนกันเด็ดขาด** ไม่งั้น
│   │                                    จำนวนเทอมที่เหลือจะเพี้ยนแบบเงียบๆ (ไม่ crash) · `entryMode` สลับ perTerm/cumulative
│   │                                    (D3/D4) · ทุก View ที่ต้องรีเฟรชตามค่าพวกนี้ต้องประกาศ `@AppStorage(GPAXSettings.Key.*)`
│   │                                    ของตัวเองไว้เป็น "ping" แม้ไม่ได้อ่านค่าตรงๆ — ไม่งั้น SwiftUI ไม่รู้ว่า UserDefaults
│   │                                    เปลี่ยน (ดูตัวอย่างที่ GradeCenterView/DashboardView/SettingsView)
│   ├── Logging/AppLog.swift             print-based console log (🔵🟠🔴)
│   ├── Models/                          (15 ไฟล์ — ดูตาราง §3, รวม Term.swift + TermSubject.swift)
│   ├── Career/                          RIASEC screening inventory v2 (PLAN_RIASEC.md) — logic ล้วน ไม่มี View
│   │   ├── RIASECDimension.swift        enum R/I/A/S/E/C (CaseIterable — **ลำดับ declaration คือลำดับ tie-break หลัก**) + thaiName/groupName/color/symbolName
│   │   ├── RIASECItem.swift             18 ข้อ (`.all`) + Likert label 1-5 — น้ำหนัก secondary balance ทุกมิติรวม 1.0 (RIASECScorerTests คุ้ม invariant นี้)
│   │   ├── RIASECScorer.swift           **ห้าม import SwiftUI/SwiftData** — `RIASECScorer.score(answers:) -> RIASECProfile` ล้วน pure function
│   │   │                                testable โดยไม่ต้องมี ModelContainer · ห้ามวน `Dictionary` เพื่อสร้างลำดับ ranked ต้อง build จาก `.allCases` เท่านั้น
│   │   └── FacultyMapping.swift         ตาราง dimension → คณะ TCAS + focusSubjects — expert mapping ไม่ใช่ empirical research (บอกไว้ในคอมเมนต์หัวไฟล์)
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
│   ├── Portfolio/PortfolioImageStore.swift  รูป Portfolio ไม่เก็บใน SwiftData — เก็บแค่ filename (PortfolioImage model)
│   │                                        ไฟล์จริงอยู่ Documents/PortfolioImages, ตามแบบ StudentProfileStore
│   │                                        `save` ย่อรูปให้ด้านยาวสุด ≤2000px ก่อนเขียน · `loadThumbnail` ใช้ CGImageSource
│   │                                        thumbnail (max 400px) + NSCache — ห้าม decode รูปเต็มในกริด/แถบเลือกรูป
│   │              + DocumentScannerView.swift  wrapper `VNDocumentCameraViewController` (ตาม `ProfileImagePicker` เดิม)
│   │                                        **ใช้บน simulator ไม่ได้** guard ด้วย `.isSupported` ก่อนเปิดเสมอ (มี alert ไทยสำรอง)
│   ├── Profile/StudentProfileStore.swift (71)
│   ├── Schedule/  logic ล้วน ไม่มี View เลยทั้งโฟลเดอร์
│   │   ├── TermStore.swift               **จุดเดียว**ที่ find/create/switch/delete Term — ห้าม View เขียน
│   │   │                                 activeTermID หรือ insert Term เอง · เทอมสร้างแบบ lazy (D4 ใน
│   │   │                                 PLAN_TermSystem) — DB เริ่มด้วย Term 0 แถว, มีแค่ 12 ตัวเลือกคงที่ในโค้ด
│   │   │                                 `bootstrap(in:)` เรียกจาก RootContainerView.task ครั้งเดียว: การันตี
│   │   │                                 active term มีอยู่เสมอ + ดึงแถว term==nil เข้าเทอม active (D7) +
│   │   │                                 sync TermSubject · เรียกซ้ำได้ปลอดภัย
│   │   │                                 `inTerm(_:)` extension บน [ScheduleEntry]/[Assignment]/[GradeComponent]
│   │   │                                 อยู่ท้ายไฟล์นี้ — ทุก View กรองข้อมูลตามเทอมผ่านจุดนี้จุดเดียว
│   │   │                                 ⚠️ ScheduleEntry ไม่มีเทอม = ซ่อน (บั๊ก) · Assignment/GradeComponent
│   │   │                                 ไม่มีเทอม = ยังโชว์อยู่จนกว่า bootstrap จะดึงเข้าเทอม (D7, จงใจไม่สมมาตร)
│   │   ├── PeriodShiftCalculator.swift   date(forDay:in:) + apply(override:to:) → [ResolvedPeriod]
│   │   │                                 ร่นจาก `override.startPeriodNumber` เป็นต้นไป — แถวก่อนหน้า**ถูกซ่อน**
│   │   │                                 (ไม่คืนใน result เลย) · **คาบพักถูกร่นและย่อด้วย** ไม่ข้ามแล้ว
│   │   ├── ThaiSubjectCatalog.swift      ไวยากรณ์รหัสวิชาไทยในรูปข้อมูล — ThaiSubjectStrand 13 สาย
│   │   │                                 (`korean` ถูกแทนด้วย `activity` = กิจกรรมพัฒนาผู้เรียน พยัญชนะ ก)
│   │   │                                 `breakKeywords` เหลือแค่ พัก/กลางวัน/โฮมรูม — แนะแนว/ชุมนุม/กิจกรรม
│   │   │                                 เป็น**วิชาปกติ** มีคาบและถูกร่น
│   │   │                                 (พยัญชนะนำ → ชื่อ/ไอคอน/สี ทุกสีอยู่ใน subjectPaletteHex)
│   │   │                                 `generatedName` คืน**หมวด** ("วิทยาศาสตร์เพิ่มเติม") ไม่ใช่ชื่อวิชาจริง
│   │   │                                 เพราะรหัสแยก ฟิสิกส์/เคมี/ชีวะ ไม่ได้ → ผู้เรียกต้องติดธง nameIsGuessed
│   │   │                                 `commonSubjects` = dropdown ให้ผู้ใช้เลือกชื่อจริง · `isBreakLabel`/`breakAppearance`
│   │   ├── ScheduleImport.swift          `ImportedPeriod` (struct ธรรมดา **ไม่ใช่ @Model**) + `ImportReviewPayload`
│   │   │                                 + `ScheduleImportBuilder.build` แปลง [ScheduleDraftEntry] → [ImportedPeriod]
│   │   │                                 ธง 3 ตัวแยกกันเด็ดขาด: codeNeedsReview · timeIsGuessed · nameIsGuessed
│   │   │                                 (หน้าตรวจแสดงคำอธิบายคนละแบบ รวมเป็นตัวเดียวเมื่อไหร่ = เสียข้อมูล)
│   │   └── ScheduleImportCommitter.swift **จุดเดียวที่เขียนผลนำเข้าลง SwiftData** — `commit(_:into:in:)`
│   │                                     รับ `Term` เป็น argument ตอนนี้ — ลบ ScheduleEntry **เฉพาะของเทอมนั้น**
│   │                                     ในวันที่รูปมี แล้วใส่ใหม่ · วันที่ไม่มีในรูป/เทอมอื่นไม่แตะเลย
│   │                                     ⚠️ ลืม scope ด้วย term = นำเข้าเทอมหนึ่งลบตารางอีกเทอมทิ้งแบบเงียบๆ
│   │                                     จับคู่วิชา: รหัสก่อน → ชื่อ → ไม่เจอค่อยสร้าง (fetch Subject ครั้งเดียว)
│   │                                     ⚠️ **ห้ามลบ Subject** — Assignment.subjectName ผูกด้วยชื่อแบบ lookup
│   └── Tasks/AssignmentPriorityEngine.swift  logic ล้วน: priority(kind:dueDate:) + daysUntil() + dueLabel() — สูตรความสำคัญอัตโนมัติที่เดียว
└── Features/
    ├── Calendar/CalendarView.swift        (~900+) ← ไฟล์ใหญ่สุด — ยังไม่แยกไฟล์ ตามที่ PROMPT_Calendar_MonthView.md §13 เตือนไว้ว่าต้องแยกก่อนทำ Ghost Event (Round 4)
    │   └── CalendarItem.swift             เพิ่ม 10 ส.ค. 2569 (Round 2) — struct รวม CalendarEvent+Assignment ไม่ใช่ @Model
    ├── CareerDiscovery/  RIASEC v2 (PLAN_RIASEC.md) — 18 ข้อ Likert แทนที่ chip picker เดิม
    │   ├── CareerDiscoveryView.swift     หน้า hub: intro card เริ่มแบบสำรวจ + การ์ดผลล่าสุด + ประวัติ 5 รายการ
    │   │                                 ทุกลิงก์ push `RIASECResultView(result:)` ที่สร้างจากแถวที่บันทึกไว้ ไม่ re-run scorer
    │   ├── RIASECQuizView.swift          1 คำถามต่อหน้า บังคับตอบครบ 18 ไม่มีปุ่มข้าม auto-advance 0.2s
    │   │                                 จบแล้วสลับเป็น RIASECResultView ผ่าน `@State` (ไม่ push ซ้อน) → back จากผลลัพธ์กลับ hub ตรงๆ
    │   └── RIASECResultView.swift        รับได้ทั้ง `RIASECProfile` (สดจากแบบสำรวจ) และ `CareerInterestResult` (ประวัติ) ผ่าน 2 initializer
    │                                     มี inconclusive state (`sd < 0.30`) แยกจาก borderline state (top1-top3 ห่างกัน <8%)
    ├── Dashboard/DashboardView.swift      root — ประกอบ section ต่างๆ, ทักทายตามเวลาจริง (เช้า/บ่าย/เย็น/ดึก
    │                                    แทน hardcode "สวัสดีตอนเช้า" เดิม) + entrance fade/offset ตอนเข้าหน้า
    │                                    (2026-08-10 dark mode redesign) แต่ละ section แยกไฟล์กันไฟล์นี้
    │                                    ยาวเกิน type-check timeout — เพิ่ม section ใหม่ = เพิ่มไฟล์ใหม่ ไม่ inline ที่นี่
    │                                    ลำดับ (14 ส.ค. 2569): Header → NextClass → Stats → Menu → Pending → GPAX
    │                                    `HeaderSection(date:)` กลืนการ์ดวันที่เดิมเข้ามาเป็นบรรทัดบน — `DateBadge` ถูกลบแล้ว
    │                                    พื้นหลังใช้ `.background(...ignoresSafeArea())` ไม่ใช่ padding(.top, 60) ชดเชยเอง
    │              + GPAXDashboardCard.swift  สรุป GPAX 1 บรรทัด + แถบความคืบหน้าเทียบเป้า → `NavigationLink(value: .gradeCenter)`
    │                                    คืน `EmptyView` ทั้งตอนยังไม่ตั้งเทอมจริงและตอนยังไม่มีเกรดเลย (ซ่อนสะอาด ไม่โชว์การ์ดว่าง)
    │              + DashboardNextClassCard.swift  การ์ด hero "คาบเรียนถัดไป/กำลังเรียน" — ใช้
    │                                    `PeriodShiftCalculator.apply` ตัวเดียวกับ ScheduleView (เคารพการร่นคาบ)
    │                                    `TimelineView(.periodic(from:by:60))` รีเฟรชนาทีละครั้งแทน Timer เอง
    │                                    **ไม่ใช่ NavigationLink** (ตั้งใจ — Dashboard tab ไม่มีทางสลับไป Schedule
    │                                    tab จาก NavigationStack ของตัวเอง ถ้าจะทำต้องเพิ่ม tab-switch plumbing ใน
    │                                    RootTabView ก่อน ยังไม่ทำรอบนี้)
    │              + DashboardStatsCard.swift      กริด 2×2 การ์ดเล็ก 4 ใบ: โฟกัสวันนี้ · งานค้าง · ส่งพรุ่งนี้ ·
    │                                    นับถอยหลังสอบ — ตัวเลข `.contentTransition(.numericText())` เวลาเปลี่ยน
    │                                    ไม่มีงาน `kind == .exam` → ช่องที่ 4 กลายเป็นปุ่มเปิด `AddTaskSheet(presetKind: .exam)`
    │              + DashboardMenuGrid.swift       เมนูหลัก 3 คอลัมน์ 7 ช่อง (ปฏิทิน·ศูนย์เกรด·TCAS·พอร์ต·ค้นหาอาชีพ·
    │                                    โหมดโฟกัส·งานทั้งหมด) ไอคอนใช้ `IconTile` ชุดสีเดียวกันหมด (primaryDeep บน
    │                                    primarySoft) ไม่ใช่สีต่อฟีเจอร์ · ปุ่มใช้ `PressScaleButtonStyle`
    │              + DashboardPendingCard.swift    งานค้าง — ติ๊กเสร็จได้ตรงจากการ์ด (เขียน `Assignment.isDone`
    │                                    รูปแบบเดียวกับ `AssignmentListView.toggleDone`) ประกาศ `EmptyRow` (ใช้ร่วม
    │                                    ในโมดูล Dashboard เท่านั้น) แถวมีขีดสีวิชา (lookup จากชื่อวิชา — `Assignment`
    │                                    เก็บวิชาเป็น String ไม่ใช่ relation) + ป้ายวันเป็น `PillLabel`
    ├── FocusMode/   โหมดโฟกัส/Pomodoro — ย้ายออกจาก Portfolio แล้ว
    │                ⚠️ **ไม่มีหน้าจอล็อกในแอปแล้ว** — `FocusLockOverlay.swift` ถูกลบตามคำสั่ง Few
    │                  (2026-08-09) เหลือการบล็อกแอปอื่นผ่าน Screen Time API อย่างเดียว
    │                  ห้ามใส่กลับโดยไม่ถามก่อน · โค้ดเดิมอยู่ใน commit `4626607`
    │   ├── PomodoroSettings.swift   (76)  **จุดเดียวที่รู้จัก UserDefaults key ของ Pomodoro**
    │   │                                  ห้ามเขียน key ตรงๆ ที่อื่น · duration(for:) แปลง phase → วินาที
    │   ├── PomodoroEngine.swift     (362) `@Observable @MainActor` singleton — **หัวใจของโหมดโฟกัส**
    │   │                                  ⚠️ **นับจาก `deadline: Date` ไม่ใช่นับ tick** ห้ามกลับไปใช้
    │   │                                    `secondsRemaining -= 1` เด็ดขาด (ของเดิมพังเพราะข้อนี้ —
    │   │                                    Timer หยุดตอนแอปเข้า background → เวลาค้าง)
    │   │                                  Timer 0.5 วิ ใช้แค่กระตุ้นให้ View วาดใหม่ (`tickToken`)
    │   │                                  สถานะทั้งหมด mirror ลง UserDefaults (`pomodoroState*`) เพื่อกู้
    │   │                                    หลัง force-quit — **จำเป็น** เพราะการบล็อกแอปเป็นค่าระดับระบบ
    │   │                                  `syncToNow()` ไล่ช่วงที่หมดเวลาไปแล้ว · กลับมาช้ากว่า 5 นาที =
    │   │                                    เลิกรอบ ไม่ไล่ต่อ (กันสร้าง FocusSession ปลอมสิบกว่าอัน)
    │   ├── AppBlockManager.swift    (~200) `@Observable @MainActor` singleton — Screen Time API จริง
    │   │                                  FamilyControls (ขออนุญาต) + ManagedSettings (shield) +
    │   │                                    DeviceActivity (ตาข่ายกันพลาด)
    │   │                                  ⚠️ **ใช้บน Simulator ไม่ได้** · ต้องเปิด Capability
    │   │                                    "Family Controls" ใน Xcode ก่อน (dev entitlement ใช้ได้เลย
    │   │                                    ไม่ต้องรอ Apple — ที่ต้องขออนุมัติคือตอนขึ้น App Store)
    │   │                                  ทุก method ออกแบบให้ล้มเหลวแบบเงียบ ไม่ crash
    │   │                                  `reconcile()` เรียกจาก RootContainerView ตอน .active —
    │   │                                    **ห้ามลบ** ไม่งั้นแอปอื่นถูกบล็อกค้างถาวร
    │   └── FocusModeView.swift      (~430) UI ล้วน ไม่เก็บเวลาเอง · body แบ่ง 2 ชั้น (mainContent
    │                                      + presentation) จงใจ กัน type-check timeout
    ├── GradeCenter/GradeCenterView.swift  (~60) GPAX summary + per-term list เท่านั้น — `GradeBreakdownCard`/
    │                                    `TargetScoreCalculatorCard`/`ThaiGrading` (Level 3 เดิม) ถูกลบแล้ว (2026-08-10,
    │                                    PLAN_2026-08-10_Fixes Task 4) `GradeComponent` model **ยังอยู่** (เก็บไว้เพื่อ
    │                                    ความเข้ากันได้ของ store เท่านั้น ไม่มี UI แล้ว) Level 1 GPAX อ่านเทอมจริง
    │                                    ผ่าน `GPAXSettings.currentSortKey` เท่านั้น (D7 — ดู comment ที่จุดเรียกในไฟล์)
    │              + GPAXSummaryCard.swift    (~210) การ์ดสรุป: ตัวเลข GPAX + range bar (พื้น/เพดาน/เป้า) + ข้อความ state
    │                                    `.tight` ที่ gpax >= 3.995 ขึ้นข้อความ/สีเขียวแทนส้ม (เพิ่งแก้)
    │                                    ยังมี `TargetQuickSetter` (private) ฝังอยู่ — ตั้งเป้าแบบเร็วๆ ชั่วคราว ตัวเต็มควรย้ายไป
    │                                    Settings ตอนขัดดีไซน์รอบหน้า (ตอนนี้มี 2 ที่ตั้งเป้าได้: การ์ดนี้ + Settings)
    │              + TermGradeListSection.swift (~135) 6 แถวคงที่ ม.4–ม.6 เสมอ · **แตะได้เฉพาะเทอมที่จบไปแล้ว**
    │                                    (`sortKey < currentSortKey`) เป็น `NavigationLink` **push** ไป `TermGradeEditView`
    │                                    (ไม่ใช่ sheet แล้ว) · เทอมที่กำลังเรียนอยู่และเทอมอนาคตกดไม่ได้
    │                                    ⚠️ เทอมปัจจุบันกดไม่ได้**โดยตั้งใจ**: `GPAXCalculator` นับเฉพาะ `sortKey < currentSortKey`
    │                                    เป็นเทอมที่จบแล้ว เกรดที่กรอกให้เทอมปัจจุบันจึงถูกเมินทั้งหมด (ข้อมูลหายเงียบๆ)
    │                                    จะกรอกได้ต่อเมื่อกด "ขึ้นชั้นแล้ว" ใน Settings เพื่อเลื่อนเทอมจริงก่อน
    │              + TermGradeEditView.swift  (~330) แทนที่ `TermGradeEditSheet` เดิม — pushed page มี Toggle "กรอกละเอียด"
    │                                    บนสุด · โหมดปกติ: กรอก gpa/totalCredits ตรงๆ (prefill 2.00 ถ้าเทอมยังไม่มีข้อมูล)
    │                                    · โหมดละเอียด (`Term.usesDetailedGrades`): List ของ `TermGradeSubject` ต่อวิชา
    │                                    (ชื่อ/หน่วยกิต Stepper 0.5–4.0/เกรด Stepper 8-step ไทย) seed จาก ScheduleEntry
    │                                    ของเทอมนั้นครั้งแรกที่เปิดโหมดนี้ (ข้าม isBreak) ปุ่ม "ดึงวิชาจากตารางสอนอีกครั้ง"
    │                                    เพิ่มเฉพาะชื่อที่ยังไม่มี ไม่เคยลบ · ทุกการแก้ไข autosave แล้วคำนวณ
    │                                    `term.gpa`/`totalCredits` ใหม่ทันที (ผลรวมถ่วงน้ำหนักหน่วยกิต) — ทุกจุดสร้าง
    │                                    `Term` ผ่าน `TermStore.findOrCreate` เท่านั้น
    │              + GradeLevelSheet.swift     (99)  Screen 1 (§6.1) ตั้ง `GPAXSettings.currentGradeLevel/currentTermNumber`
    │                                    เปิดจาก 2 ที่: การ์ดว่างของ GPAXSummaryCard ครั้งแรก · Settings "แก้ระดับชั้น"
    │              + CumulativeGPAXSheet.swift (87)  Screen 4 (§6.4) "จำเกรดไม่ได้" — ตัวเลือก 1 เขียน
    │                                    `GPAXSettings.setCumulative` + entryMode `.cumulative` (D3) · ตัวเลือก 3 สร้าง
    │                                    `CalendarEvent` เตือนขอ ปพ.1 จริง (ผ่าน initializer เดิม ไม่ได้แก้ CalendarView.swift)
    ├── Onboarding/  (6 ไฟล์: Welcome→Profile→Schedule→GradeReport→Summary + ProfileImagePicker)
    ├── Portfolio/   PortfolioView.swift (grid 2 คอลัมน์ + chip กรองหมวดหมู่, `.navigationDestination(for: PortfolioItem.self)`) · PortfolioCard.swift (การ์ดกริด ไม่ใช้ CardContainer เพราะรูปต้อง bleed ถึงขอบบน)
    │                + PortfolioItemSheet.swift (สร้าง/แก้ไข ใช้ `Mode` เดียวกัน — รูปที่เลือกอยู่ staged ใน memory จนกด "บันทึก" ถึงเขียนไฟล์+insert
    │                  ปุ่ม "เพิ่มรูป" เปิด `.confirmationDialog` 4 ทาง: สแกนเอกสาร (`DocumentScannerView`) · ถ่ายรูป (`ProfileImagePicker(.camera, allowsEditing:false)`)
    │                  · เลือกจากคลังรูป (`.photosPicker` แบบ programmatic) · เลือกจากไฟล์ (`.fileImporter` [.image, .pdf], PDF หน้าแรกเรนเดอร์ด้วย PDFKit)
    │                  สแกน/กล้อง เช็ค `.isSupported`/`.isSourceTypeAvailable(.camera)` ก่อนเปิดเสมอ — ไม่มี guard = crash บน simulator)
    │                + PortfolioDetailView.swift (gallery `TabView(.page)` โหลดรูปเต็ม + แก้ไข/ลบ — ลบจะลบทั้งแถว SwiftData และไฟล์บนดิสก์)
    ├── Schedule/  ScheduleView.swift (root) + ScheduleConstants.swift
    │                (visibleDays/dayLabels · `findOrCreateSubject` ใช้โดย onboarding เท่านั้น
    │                 · `resolveSubject(named:code:in:)` ใช้โดยฟอร์มคาบ — รหัสก่อน→ชื่อ, สี/ไอคอนจาก ThaiSubjectCatalog)
    │              + ScheduleDayPickerBar · ScheduleTimetableSection (ใช้ [ResolvedPeriod]) · SchedulePeriodRow · ScheduleBreakRow
    │              + SubjectPickerFields (กลุ่มสาระ→รายวิชา+ชื่อ+รหัส — **แถวล้วน ไม่มี Section**
    │                ใช้ร่วมกันโดย AddScheduleEntrySheet และ ScheduleImportRowEditSheet ห้ามแยกกลับ)
    │              + PeriodNumberField (ตัวเลือก "คาบที่" 0–10 + กำหนดเอง — ใช้ร่วมทั้ง 2 หน้าเหมือนกัน)
    │              + AddScheduleEntrySheet (add/edit ใช้ร่วม · section เรียง วิชา→เวลา→รายละเอียด ตรงกับหน้า import)
    │              + AddSubjectSheet
    │              + ScheduleImportReviewSheet · ScheduleImportRowEditSheet
    │                (หน้าตรวจผลอ่านตารางจากรูป — ไม่เขียน SwiftData เอง ส่ง [ImportedPeriod]
    │                 กลับทาง onSave ให้ AddScheduleEntrySheet เรียก ScheduleImportCommitter)
    │              + ScheduleTodayTasksSection (งาน/การบ้านวันนี้ ผูก Assignment.subjectName แบบ lookup ชื่อ)
    │              + PeriodShiftBanner (แถบบอกว่าวันนี้ถูกร่นอยู่) · PeriodShiftSheet (ฟอร์มร่นคาบจริง —
    │                ใช้ PeriodShiftCalculator ที่เดียว ไม่มีสูตรซ้ำใน View · เปิดจาก ScheduleSettingsSheet เท่านั้น
    │                ไม่ได้เปิดตรงจาก ScheduleView แล้ว)
    │              + ScheduleSettingsSheet (เปิดจากปุ่มเฟือง toolbar — แทนปุ่มนาฬิกาเดิม: สลับเทอมด้วย
    │                segmented ม.ต้น/ม.ปลาย + menu 6 ช่อง, เลือกเทอม→ TermStore.findOrCreate+setActive+
    │                syncTermSubjects **ทันที ไม่ dismiss sheet**, มีปุ่ม "ร่นคาบวันนี้" เปิด PeriodShiftSheet
    │                ซ้อนข้างใน + ลิงก์ "จัดการเทอมทั้งหมด" push TermManagementView)
    ├── QuickAdd/QuickAddSheet.swift       (~340) half-sheet เมนู "เพิ่มอะไรดี?" (กริดไอคอน) ที่เด้งตอนกดปุ่ม `+` กลาง tab
    │                                              งาน → AddTaskSheet · ปฏิทิน/โน๊ต/Portfolio → CaptureDetailSheet (private ในไฟล์เดียวกัน)
    │                                              **เพิ่มโหมดใหม่ = เพิ่ม 1 บรรทัดใน `options`** (แทน SmartCaptureView เดิมที่ถูกลบ)
    ├── Settings/
    │   ├── SettingsView.swift             (585) section "สำหรับนักพัฒนา" อยู่ใน `developerSection`
    │   │                                         (computed property เพราะ `#if DEBUG` ใน ViewBuilder ทำ type-check เพี้ยน)
    │   │                                         section "ระดับชั้นและเป้า GPAX": ระดับชั้นจริง+ปุ่ม "ขึ้นชั้นแล้ว"
    │   │                                         (เขียนผ่าน `GPAXSettings.setCurrentTerm` เท่านั้น) · เป้า GPAX/entryMode
    │   │                                         bind ตรงกับ `@AppStorage(GPAXSettings.Key.*)` (ไม่ผ่าน setter) · เปิด
    │   │                                         `GradeLevelSheet`/`CumulativeGPAXSheet` ซ้ำจาก GradeCenter ไม่สร้างใหม่
    │   │                                         **ไม่ได้แก้ resetAllData() ให้ล้าง GPAX UserDefaults** — ตั้งใจ ตรงกับ
    │   │                                         convention เดิมที่ preference อื่น (Pomodoro, scheduleShowsPersonalTasks)
    │   │                                         ก็รอดจากการรีเซ็ตเหมือนกัน (คนละกรณีกับกฎ "@Model ใหม่ต้องลง resetAllData")
    │   ├── TermManagementView.swift        List เทอมที่**มีอยู่จริงในฐานข้อมูล**เท่านั้น (เทอมสร้างแบบ lazy) เรียงตาม
    │   │                                   `sortKey` · แตะแถว = TermStore.setActive + dismiss · ปัดซ้าย = alert ยืนยัน
    │   │                                   บอกจำนวนคาบ/งาน/คะแนนที่จะหาย แล้ว TermStore.delete + TermStore.bootstrap
    │   │                                   (การันตีมีเทอม active เสมอแม้ลบเทอมสุดท้าย) · เปิดจาก Settings และจาก
    │   │                                   ScheduleSettingsSheet ("จัดการเทอมทั้งหมด")
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
    └── TCASPlanner/  ระบบคิดคะแนนย้อนกลับ + SOP ต่อคณะ แทน readiness checklist เดิม (PLAN_TCASPlanner.md
        │            ครบทั้ง 4 รอบแล้ว) · ทุกจุดคะแนน/เกณฑ์การรับจริงเปิด mytcas.com แทนเก็บเอง (§0.3 กฎเหล็ก)
        │            · Free ทั้งหมด ไม่ gate
        ├── TCASPlannerView.swift        ลิสต์: Section "คะแนนสอบของฉัน" (→ MyScoresView) + Section
        │                                "คณะเป้าหมาย" (แถวคณะ ปัดซ้ายลบ → TCASEntryDetailView, แถว
        │                                "เพิ่มคณะเป้าหมาย" ท้ายลิสต์ → NewTCASEntrySheet — **ไม่มีปุ่ม + บน
        │                                toolbar แล้ว** ตาม §0.1) เรียงตาม `TCASEntry.sortOrder`
        ├── NewTCASEntrySheet.swift      กรอกคณะ/มหาลัย/รอบ → บันทึก → push ต่อ TCASWeightSetupView ทันที
        │                                (`showsSkipButton: true`, ปุ่ม "ข้ามก่อน"/"เสร็จ" ปิด sheet ทั้งชุด)
        ├── TCASWeightSetupView.swift    ตั้งน้ำหนัก % — สลับ 2 โหมด (รายวิชา/กลุ่ม) ได้ตลอด ทั้งสองโหมดเขียน
        │                                ลง `TCASScoreWeight` ชุดเดียวกัน (แยกกันด้วย `groupName` ว่าง/ไม่ว่าง)
        │                                โหมดกลุ่ม = เลือก `TCASExamGroup` (TGAT/TPAT/A-Level) ทั้งกลุ่มเสมอ
        │                                (ไม่ใช่ตั้งชื่อกลุ่มเอง — ตัดสินใจเอง ดูหมายเหตุท้าย PLAN_TCASPlanner.md)
        │                                แล้วหารเท่ากันผ่าน `TCASScoreEngine.setGroupPercent` เสมอ · แก้ %
        │                                วิชาเดิมซ้ำ = `context.delete` ของเก่าก่อนเสมอ (กันแถวค้าง)
        ├── TCASScoreCard.swift          การ์ดอ่านอย่างเดียวบนสุดของ TCASEntryDetailView (ห่อด้วย
        │                                NavigationLink ไป TCASWeightSetupView) — คะแนนช่วงปัจจุบัน–เพดาน
        │                                (มีป้าย "ปัจจุบัน – เพดาน" กำกับตาม §4.4) · คำเตือนน้ำหนักไม่ครบ 100 ·
        │                                gap ถ้าตั้งเป้า · **leverage 3 อันดับแรกคู่กับ headroom เสมอ** (§4.2 —
        │                                ห้ามโชว์ leverage เดี่ยว วิชาที่คุ้มแต่ได้คะแนนสูงแล้วเหลือให้ดันน้อย) ·
        │                                ผลโหมดล็อกถ้ามีวิชา hasTaken แสดง**ครบ 5 บรรทัดตามตัวอย่าง §4.3**
        │                                (ล็อกแล้ว/เป้าหมาย/ที่เหลือต้องช่วยอีก/น้ำหนักที่ยังไม่สอบ/ต้องได้เฉลี่ย)
        │                                >100% ใช้ Theme.Colors.warning + ข้อความจาก §4.3 เป๊ะ ห้ามใช้สีแดง
        │                                ทุกตัวเลขผ่าน `TCASScoreEngine` ล้วน
        ├── TCASEntryDetailView.swift    การ์ดคะแนน + TextField `targetScore` (0 = ไม่ระบุ — จุดเดียวที่ตั้งเป้าได้
        │                                ตอนนี้, ตัดสินใจเอง แผนไม่ได้ระบุตำแหน่ง UI) + แถว "SOP" (→
        │                                SOPEditorView) + TextField `admissionURL` (ลิงก์ระเบียบการที่ผู้ใช้
        │                                แปะเอง — ยังไม่มีใน UI ตอนสร้างคณะ) + ปุ่ม "เปิดดูเกณฑ์ใน mytcas"
        │                                (เปิด admissionURL ถ้ามี ไม่งั้น mytcas.com เฉยๆ) + โน้ต
        ├── MyScoresView.swift           คะแนนสอบของผู้ใช้ ชุดเดียวใช้ร่วมทุกคณะ (`TCASScoreRecord` ค้นด้วย
        │                                `examCode`) — List ทุกวิชาใน `TCASExamCatalog.grouped` ตรงๆ (24 แถว)
        │                                แต่ละแถว TextField คะแนน + Toggle "สอบไปแล้ว" เขียนตรงทันที
        ├── SOPEditorView.swift          1 ฉบับ/คณะ (`TCASSOP` ผ่าน `entry.sop` computed) — เลือกโหมด
        │                                "ก้อนเดียว"/"6 ช่อง" ได้ครั้งเดียวตอนเริ่ม · ปุ่ม "รวมเป็นฉบับเดียว"
        │                                (โหมด 6 ช่องเท่านั้น) → **`.alert`** เตือนก่อนเสมอ (§5.1 แยกไว้ชัด:
        │                                merge = alert · ออกโดยไม่บันทึก = confirmationDialog ห้ามสลับ) →
        │                                `isMerged = true` ถาวร (กลับไปแก้ทีละส่วนไม่ได้อีก) · ข้อความรวม =
        │                                6 ส่วนคั่น `\n\n` ข้ามช่องว่าง ไม่มีหัวข้อกำกับ · ปุ่ม "บันทึก" มุมขวาบน
        │                                ไม่ autosave ระหว่างพิมพ์ · ออกโดยยังไม่บันทึก → confirmationDialog
        │                                เตือน (ผ่านปุ่ม back เอง — ซ่อน default back button ด้วย
        │                                `navigationBarBackButtonHidden`; **swipe-back gesture ของ
        │                                NavigationStack ยังไม่ถูกดักไว้** ข้ามการเตือนได้ ตัดสินใจเอง/รู้จุดอ่อน)
        │                                · นับตัวอักษรมุมล่าง · ปุ่มคัดลอกทั้งฉบับ (`UIPasteboard` + toast)
        │                                · ลิสต์ 13 หัวข้อคำแนะนำท้ายหน้า → SOPGuideSheet
        ├── SOPGuideSheet.swift          `TabView(.page)` 13 หน้า ปัดซ้ายขวา + page dots เริ่มที่หน้าที่กด
        ├── `Core/TCAS/TCASExamCatalog.swift`   ~24 วิชาสอบ, logic ล้วน (⚠️ ยังไม่ verify กับ mytcas จริง)
        ├── `Core/TCAS/TCASScoreEngine.swift`   logic ล้วน ไม่ import SwiftData — รับ/คืน struct เปล่า
        │                                  `TCASWeightInput`/`TCASScoreInput`/`TCASSubjectBreakdown` ไม่ใช่
        │                                  @Model ตรงๆ เทียบเคียง GPAXCalculator · `StudiiOSTests/
        │                                  TCASScoreEngineTests.swift` ครอบ 10 เคส รวม worked example จาก
        │                                  §4.2/§4.3 ของแผนเป๊ะ
        └── `Core/TCAS/SOPGuideContent.swift`   13 หน้าคำแนะนำ static let เนื้อหาจาก Few 2026-08-10 ตรงๆ
                                            logic ล้วน ไม่มี View/SwiftData (เทียบเคียง TCASExamCatalog)
                                            ⚠️ หน้า 11 "โครงสร้างที่แนะนำ" คำอธิบายรายส่วนผมเขียนเสริมเอง
                                            (แผน §6.2 สั่งให้มี "คำอธิบายว่าแต่ละส่วนควรมีอะไร" แต่ไม่ได้ให้ข้อความ)
```

---

## 3. SwiftData Models (23 @Model — ทั้งหมดต้องอยู่ใน Schema)

Schema ประกาศที่ `App/StudiiOSApp.swift:15-36`

| Model | ไฟล์ |
|---|---|
| Assignment | Core/Models/Assignment.swift — `subjectName: String` (default "") · `kindRaw` (การบ้าน/งานทั่วไป/**สอบ** — เพิ่ม `.exam` 10 ส.ค. 2569, Round 2 ของ PROMPT_Calendar_MonthView.md) · `examScopeRaw: String = ""` → `examScope: ExamScope?` (กลางภาค/ปลายภาค/เก็บคะแนน, เฉพาะ `.exam`) · `hasDueDate` (default **true**, บังคับ `true` เสมอเมื่อ `.exam`) · `isPriorityManual` · `remindersEnabled` · `uid` (เติมด้วย `ensureUID()`) · `term: Term?` (term-scoped, D5)<br>**อ่านวันส่งผ่าน `resolvedDueDate` เท่านั้น** (nil = ไม่กำหนด) · ความสำคัญใช้ `effectivePriority` (auto จาก `AssignmentPriorityEngine`, ห้าม cache ลง `priorityRaw` — `.exam` ได้ bonus +2 สูงกว่า `.homework` +1) |
| Note | Core/Models/Note.swift |
| Flashcard | Core/Models/Flashcard.swift |
| GradeComponent | Core/Models/GradeComponent.swift — `term: Term?` (term-scoped, D5) |
| ExamEvent | Core/Models/ExamEvent.swift |
| ScheduleEntry | Core/Models/ScheduleEntry.swift — เวลาเป็น `startMinute`/`endMinute: Int` (ไม่ใช่ Date แล้ว) + `subject: Subject?` + `term: Term?` relationship (term-scoped, D5 ใน PLAN_TermSystem) |
| Subject | Core/Models/Subject.swift — วิชา/ช่วงพัก (`isBreak`), seed 3 ตัวตอนเปิดแอปครั้งแรก |
| DayScheduleOverride | Core/Models/DayScheduleOverride.swift — ร่นคาบเฉพาะวัน จัดการผ่าน `PeriodShiftSheet`/`PeriodShiftBanner`, คำนวณผ่าน `PeriodShiftCalculator` เท่านั้น (ไม่แก้ `ScheduleEntry` จริง)<br>`startPeriodNumber: Int = 1` = คาบที่เริ่มร่น — **คาบก่อนหน้าถูกซ่อนทั้งวัน** และคาบพักตั้งแต่จุดนี้ไปถูกร่น+ย่อเหลือ `periodLengthMinutes` เท่าคาบอื่น |
| Term | Core/Models/Term.swift — ระดับชั้น (1-6) + เทอม (1-2), ไม่มีปี พ.ศ. (D3) · สร้างแบบ lazy เท่านั้น (D4) — ห้ามมี `@Relationship` array ชี้ลง children, จัดการทั้งหมดผ่าน `TermStore` เท่านั้น<br>`gpa: Double?` / `totalCredits: Double?` (default `nil` ทั้งคู่, additive migration) — ใช้โดย `GPAXCalculator` เท่านั้น เขียนได้จาก `TermGradeEditView` ผ่าน `TermStore.findOrCreate` เท่านั้น (ไม่ว่าโหมดง่ายหรือละเอียด)<br>`usesDetailedGrades: Bool = false` (additive) — true = เทอมนี้กรอกเกรดรายวิชาผ่าน `TermGradeSubject` แทนกรอก gpa ตรงๆ |
| TermSubject | Core/Models/TermSubject.swift — join `Term` ↔ `Subject`, มี `creditHours`/`gradePoint` รอรอบ GPA (§9 ใน PLAN_TermSystem) · sync อัตโนมัติผ่าน `TermStore.syncTermSubjects` ทุกครั้งที่ ScheduleEntry ถูกบันทึกเข้าเทอม · **ไม่ใช่** ตัวเดียวกับ `TermGradeSubject` ด้านล่าง |
| TermGradeSubject | Core/Models/TermGradeSubject.swift — เพิ่ม 2026-08-10 (PLAN_2026-08-10_Fixes Task 5) วิชา+เกรดรายวิชาของโหมด "กรอกละเอียด" ต่อเทอม แยกจาก `TermSubject` โดยตั้งใจ (กันข้อมูลเกรดหายเงียบๆ ถ้าคาบถูกลบจากตาราง) `name`/`code`/`creditHours`/`gradePoint`/`sortOrder` — seed จาก `ScheduleEntry` ของเทอมนั้นครั้งแรกที่เปิดโหมดละเอียด แก้ไข/ลบผ่าน `TermGradeEditView` เท่านั้น |
| FocusSession | Core/Models/FocusSession.swift — `kindRaw` (โฟกัส/พักสั้น/พักยาว, อ่านผ่าน `phase`) · `endedAt: Date?` · `wasLocked` (3 ตัวนี้มี default ครบ → migrate ของเดิมได้)<br>⚠️ **ช่วงพักถูกบันทึกเป็น FocusSession ด้วย** — สถิติ "นาทีโฟกัส" ต้องกรอง `phase == .focus` เสมอ (Dashboard + FocusModeView ทำแล้ว)<br>ไฟล์นี้ยังเป็นที่ประกาศ `enum PomodoroPhase` ด้วย |
| PortfolioItem | Core/Models/PortfolioItem.swift — `startDate`/`endDate: Date?` (rename จาก `date` เดิม — breaking, ต้องลบแอปก่อนติดตั้งรุ่นนี้) · `images: [PortfolioImage]` (cascade) · `coverImage` = ตัวแรกตาม `sortOrder` · `dateRangeText` ใช้ `Date+Thai.swift` · `PortfolioCategory.color` ใหม่ (ใช้ `Theme.Colors`, ผูกกับ pill ในการ์ด) |
| PortfolioImage | Core/Models/PortfolioImage.swift — เก็บแค่ `filename`/`sortOrder`/`createdAt` ตัวไฟล์จริงอยู่ `PortfolioImageStore` (Core/Portfolio/) |
| CareerInterestResult | Core/Models/CareerInterestResult.swift — 5 field เดิม (`interestTags`/`recommendedCareer`/`recommendedFaculty`/`recommendedSkills`/`takenAt`) + field ใหม่จาก RIASEC v2 (additive, มี default ครบ): `scoreR..scoreC: Int`, `hollandCode: String`, `isInconclusive: Bool`, `answers: [Int]` (18 คำตอบ Likert เรียงตาม item id, ไว้ re-score ย้อนหลังได้โดยไม่ต้องให้ทำแบบสำรวจใหม่) · `riasecScores` computed property คืน `[RIASECDimension: Int]` |
| TCASEntry | Core/Models/TCASEntry.swift — `roundRaw`/`sortOrder`/`targetScore`/`admissionURL` (default ครบ) · `weights: [TCASScoreWeight]` (cascade) · `sopStore: [TCASSOP]` (cascade, มีได้ 0-1 ตัว) · `sop` computed คืน `sopStore.first` (SwiftData ยังงอแงกับ to-one optional relationship) |
| TCASScoreWeight | Core/Models/TCASScoreWeight.swift — น้ำหนัก % รายวิชาต่อคณะ ผู้ใช้กรอกเอง · `groupName`/`groupPercent` เก็บซ้ำทุกแถวในกลุ่มแทนแยก model `TCASWeightGroup` (ตั้งใจ, ดู PLAN_TCASPlanner.md §2.2) — แก้ % กลุ่มต้องผ่าน `TCASScoreEngine.setGroupPercent(...)` จุดเดียว ห้าม View เขียนตรง |
| TCASScoreRecord | Core/Models/TCASScoreRecord.swift — คะแนนสอบของผู้ใช้ ชุดเดียวใช้ร่วมทุกคณะ (ค้นด้วย `examCode`) **ไม่ผูก relationship กับ TCASEntry** · `hasTaken` ใช้ในโหมดล็อก "สอบไปแล้ว" |
| TCASSOP | Core/Models/TCASSOP.swift — 1 ฉบับต่อ 1 คณะ · โหมด `single`/`sections` (6 ช่อง) · `isMerged = true` แล้วกลับไปแก้ทีละส่วนไม่ได้อีก |
| SemesterRecord | Core/Models/SemesterRecord.swift |
| CalendarEvent + CalendarTag + CalendarAttachmentItem | Features/Calendar/CalendarView.swift ⚠️ model ฝังอยู่ในไฟล์ view |

`CalendarView` (10 ส.ค. 2569, Round 2) รวม `CalendarEvent` + `Assignment.inTerm(activeTerm)` เป็น `CalendarItem` (struct ธรรมดา ไม่ใช่ `@Model` — `Features/Calendar/CalendarItem.swift`) index เป็น `[Date: [CalendarItem]]` คีย์ `startOfDay` ครั้งเดียวต่อ render (ไม่ใช่วน filter 42 รอบแบบเดิม) — ช่องวันแสดง pill สูงสุด 2 + "+X" เรียง สอบ→การบ้าน/งานทั่วไป→กิจกรรม, assignment ที่ `hasDueDate == false` ไม่ขึ้นในปฏิทิน

**Round 3 (10 ส.ค. 2569):** `CalendarEvent` เพิ่ม `subjectName: String = ""` (เหมือน `Assignment.subjectName` — ใช้แทน title ใน pill/shortLabel เมื่อมีค่า) · `EventFormSheet` เพิ่มช่องสถานที่/โน้ต(`TextEditor` 80pt)/วิชา(`Picker` แบบเดียวกับ `AddTaskSheet`, **ไม่ใช่** `SubjectPickerFields` — ตัวนั้นออกแบบมาสำหรับสร้างวิชาใหม่พร้อมกลุ่มสาระ/รหัส ไม่ใช่เลือกวิชาที่มีอยู่)/แท็ก (chip เลือก/สร้างใหม่ ผูก `CalendarTag` ผ่านชื่อ) · จานสีอ้างจาก `Theme.Colors.subjectPalette` ตรง (8 สี ไม่ hardcode ซ้ำ) · `.presentationDetents([.medium, .large])` + auto-focus ช่องชื่อ<br>`CalendarView` เอา custom `topBar`/ปุ่ม test-notification/ปัดเปลี่ยนเดือนออกทั้งหมด (ชนกับ scroll ตามที่พรอมต์เตือน) ครอบด้วย `.navigationTitle(monthTitle)` + `.toolbar`(‹ ›/วันนี้) แทน — **อาศัย `NavigationStack` ที่ `RootTabView` ครอบไว้ให้แล้ว ไม่ได้เพิ่มอันใหม่ซ้อน** · เพิ่ม `.searchable` ค้นทั้ง event+assignment จัดกลุ่มตามเดือน แตะแล้ว `jumpToSearchResult` เคลียร์ค้นหา+ตั้ง `currentMonth`/`selectedDate`<br>ไฟล์ยาวขึ้นเป็น ~1080 บรรทัด — ยังไม่แยกไฟล์ ตาม §13 ของพรอมต์ที่เตือนว่าต้องแยกก่อน Round 4 (Ghost Event)

**Round 4 (10 ส.ค. 2569):** ก่อนเริ่ม Ghost Event แยก `CalendarView.swift` ออกเป็น 3 ไฟล์ — `CalendarModels.swift` (EventAlert/CalendarTag/CalendarAttachmentItem/CalendarEvent), `EventFormSheet.swift`, `GhostEventLayer.swift` (แค่ `GhostPillView` — visual ล้วน) ตัว `CalendarView.swift` เหลือ ~963 บรรทัด (โค้ด Ghost Event ใหม่ยาวพอๆกับที่ตัดออกไป) **ตัดสินใจไม่แยก gesture/state logic ของ Ghost Event ออกไฟล์แยกเพิ่ม** เพราะต้อง cascade เปลี่ยน `private`→internal ทั้ง @State และ helper function จำนวนมากที่ Ghost logic เรียกใช้ (modelContext, cal, calendarDays, itemsFor, activeSheet, CalendarSheet เอง ฯลฯ) เสี่ยงพลาดจุดใดจุดหนึ่งโดยไม่มี compiler ยืนยันในนี้ — เก็บไว้เป็น extension ในไฟล์เดียวกันแทน ปลอดภัยกว่า<br>Ghost gesture: `LongPressGesture(0.5).sequenced(before: DragGesture(minimumDistance:0, coordinateSpace:.named("monthGrid")))` แนบที่ `monthGrid` ด้วย `.simultaneousGesture` (ไม่ใช้ `.gesture` เฉยๆ กัน block `dayCell`'s `.onTapGesture`) วัดขนาดกริดครั้งเดียวด้วย `.onGeometryChange` แล้วคำนวณ cell ด้วยเลขคณิตล้วน (`cellIndex`/`cellCenter`/`hitTestItem` — ค่าคงที่ 27/16 ผูกกับ layout จริงใน `dayCell`/`dayPills` ห้ามแก้ที่เดียวไม่แก้อีกที่) เอา `dayCell`'s เดิม `.onLongPressGesture` (เปิด add sheet ตรงๆ) ออกแล้ว เพราะ mode A drop-in-same-cell ทำหน้าที่แทนอยู่แล้ว<br>⚠️ **จุดเสี่ยงที่ยังไม่ได้ทดสอบจริง**: tap (เลือกวัน) ที่ `dayCell` กับ long-press-drag ที่ `monthGrid` เป็น gesture recognizer คนละตัวคนละระดับ — ถ้ากดค้างแล้วปล่อยโดยไม่ลาก อาจ fire ทั้ง `selectedDate` (จาก tap) และเปิด sheet สร้างกิจกรรมใหม่ (จาก ghost) พร้อมกัน ต้องให้ Few ทดสอบจริงบนเครื่อง<br>สร้างกิจกรรมจากการลากใช้ `CalendarSheet.editNewGhost(CalendarEvent)` แยกจาก `.edit` ปกติ — `EventFormSheet` มี `deleteOnCancel: Bool` param กด "ยกเลิก" แล้วลบ event ที่สร้างไว้ล่วงหน้าทิ้ง<br>ย้าย event/assignment ที่มีอยู่: เก็บ `originalStart/originalEnd`/`originalDue` ไว้ก่อน mutate เพื่อรองรับปุ่ม "เลิกทำ" ใน toast (`@State toastUndo`, auto-dismiss 4 วิด้วย `Task.sleep`)<br>Assignment ที่ `hasDueDate == false` ไม่เคยขึ้นเป็น pill ในกริดอยู่แล้ว (กรองออกตั้งแต่ Round 2) จึงลากไม่ได้โดยธรรมชาติ ไม่ต้องเขียน guard/haptic `.warning` เพิ่ม (unreachable case)

**กฎเหล็ก:** เพิ่ม `@Model` ใหม่ → ต้องเพิ่มใน `Schema([...])` ด้วย ไม่งั้น crash ตอนรัน (Term/TermSubject/TermGradeSubject ทำแล้ว — ลบ TermSubject **และ** TermGradeSubject **ก่อน** Term เสมอ, และเคลียร์ `TermStore.activeTermKey` ออกจาก UserDefaults ด้วย)
และต้องเพิ่มใน `SettingsView.resetAllData()` ด้วย (เคยลืมมาแล้วกับ Calendar 3 ตัว)
`resetAllData()` ลบ `Subject` แล้วเรียก `StudiiOSApp.seedBuiltInSubjects(in:)` ทันทีเพื่อ reseed 3 วิชาเริ่มต้น — ถ้าเพิ่ม built-in subject ใหม่ ต้องแก้ทั้งสองจุด (seed function + resetAllData ยังคงเรียก function เดิม จุดเดียวพอ)

---

## 4. Navigation (RootTabView.swift)

5 tabs: `dashboard` · `tasks` · `capture` · `schedule` · `settings`
(หน้าแรก · งาน · **+** · ตารางสอน · ตั้งค่า — 14 ส.ค. 2569: แท็บ 2 เปลี่ยนจาก ปฏิทิน เป็น `AssignmentListView`)

- แท็บ "เพิ่ม" (`.capture`) เป็น `Color.clear` + trick: `onChange` ดีดกลับแท็บเดิมแล้วเปิด **`QuickAddSheet`** เป็น sheet
  → ผู้ใช้เลือกก่อนว่าจะเพิ่มอะไร (งาน / ปฏิทิน / โน๊ต / Portfolio) แล้วค่อยเปิดฟอร์ม
  **นี่คือทางเข้าเดียวของ ปฏิทิน/โน๊ต/Portfolio** — ถ้าเปลี่ยนปุ่มนี้ให้เปิดฟอร์มใดฟอร์มหนึ่งตรงๆ อีก 3 โหมดจะกลายเป็นโค้ดตาย
- Dashboard push ต่อผ่าน `DashboardDestination`: `.assignments` `.calendar` `.gradeCenter` `.tcasPlanner` `.portfolio` `.careerDiscovery` `.focusMode`
  **`CalendarView` เข้าได้ทางเมนูหลักทางเดียวแล้ว** (ไม่มีแท็บของตัวเอง) — push เข้า NavigationStack ของ Dashboard
- Onboarding gate อยู่ที่ `RootContainerView` (`StudiiOSApp.swift:53-74`) ใช้ `@AppStorage` 5 ตัวเรียงลำดับหน้า
- แท็บ "ตารางสอน" (`ScheduleView`) toolbar มี 2 ปุ่ม: เฟือง (ซ้าย) เปิด `ScheduleSettingsSheet`
  (สลับเทอม + ร่นคาบ — เดิมนาฬิกาเปิด `PeriodShiftSheet` ตรงๆ, ตอนนี้ย้ายไปซ้อนข้างในแล้ว)
  · `+` (ขวา) เปิด `AddScheduleEntrySheet` (เพิ่ม/แก้คาบ, หรือแตะแถวคาบเพื่อแก้) → ซ้อน `AddSubjectSheet`
  (เพิ่มวิชาใหม่, เปิดจากปุ่ม "เพิ่มวิชาใหม่" ในฟอร์มคาบ)
- **ระบบเทอม (`TermStore`)**: ทุก View ที่แสดง/บันทึก `ScheduleEntry`/`Assignment`/`GradeComponent`
  ต้องมี trio `@AppStorage(TermStore.activeTermKey)` + `@Query private var terms: [Term]` +
  `activeTerm` computed แล้วกรองข้อมูลผ่าน `.inTerm(activeTerm)` — สลับเทอมทำได้จาก `ScheduleSettingsSheet`
  หรือ Settings → "เทอมปัจจุบัน" → `TermManagementView` (สลับ/ลบเทอมที่มีอยู่จริง)
  `TermStore.bootstrap(in:)` รันครั้งเดียวใน `RootContainerView.task` ก่อน `.onChange(of: scenePhase)`
- **ทางเข้าอ่านตารางจากรูปอยู่ใน `AddScheduleEntrySheet` เฉพาะโหมดเพิ่ม** (`editing == nil`) — โหมดแก้ไขไม่มีปุ่มนี้
  ปุ่ม "ถ่ายตารางสอน" → alert เตือนว่าอ่านผิดได้ → confirmationDialog ถ่าย/คลังภาพ → `ProfileImagePicker`
  → `ScheduleOCRParser` → `ScheduleImportBuilder` → `ScheduleImportReviewSheet` → `ScheduleImportCommitter`
  presentation **ทั้ง 4 ชั้นแขวนจาก NavigationStack ของ `AddScheduleEntrySheet` ตัวเดียว** ห้ามยกไปไว้ใน child view
  `AddScheduleEntrySheet(editing:defaultDay:onImported:)` — `onImported` ส่งวันแรกที่นำเข้ากลับให้ `ScheduleView` เด้ง `selectedDay`
- `ScheduleTodayTasksSection` แสดง **เฉพาะการบ้าน** เป็นค่าเริ่มต้น — สลับด้วย `@AppStorage("scheduleShowsPersonalTasks")` (Toggle อยู่ใน Settings section "ตารางเรียน")
- `ScheduleTodayTasksSection`'s "ดูทั้งหมด" push ตรงไป `AssignmentListView()` ด้วย plain `NavigationLink` (ไม่ใช้ `DashboardDestination` enum เพราะ Schedule tab มี `NavigationStack` แยกจาก Dashboard — ปลายทางเดียวไม่คุ้มความซับซ้อนของ enum-based navigation)

---

## 5. Design tokens (Core/DesignSystem/Theme.swift)

```
Theme.Colors — โทน terracotta (เปลี่ยนจากส้ม E1802F เดิม 14 ส.ค. 2569, Wave 1 ของ PLAN_Redesign.md):
Accent (2 ระดับ ห้ามสลับใช้ผิดที่ — ดูกฎด้านล่าง):
               primary C96F4A/E8A06B (light/dark) — ใช้เป็น "พื้น" เท่านั้น (fill/highlight/opacity fill)
               primaryDeep A85236/E8A06B — ใช้กับ "ข้อความ/ไอคอน" เท่านั้น
               onPrimary FFFFFF/1A1512 — สีข้อความ/ไอคอนบน primaryDeep (หรือ primary แบบ solid fill ไม่มี opacity)
               primarySoft F5E7DD/332720 — พื้นไอคอนเมนู/chip/ป้าย (primaryDeep อ่านออกบนพื้นนี้)
Hero (การ์ดคาบเรียนบน Dashboard เท่านั้น — ที่เดียวในแอปที่พื้นเป็นสีเข้มทึบ):
               heroFill C96F4A/8F4A2C · onHero FFFFFF/FFF1E6 · onHeroMuted F7DFD2/F0CBB5
Semantic: danger C0503F/E8756A (เปลี่ยนจาก FF6B6B — สดเกินไปบนพื้นครีม) · warning #FFB347
               success #4CAF50 · info #00BCD4 · purple #9C27B0 · pink #E91E63 · indigo #3F51B5
Surfaces/text (adaptive light/dark ผ่าน Color(light:dark:) ใน Color+Hex.swift):
               textPrimary 2A2320/F4EEE7 · textSecondary 8A7B6D/A79A8B · background FBF7F2/14110E
               cardBackground FFFFFF/1F1B17 · surfaceRaised F6F0E8/2A241E (การ์ดซ้อนบนการ์ด, unselected fill)
               breakBackground FDF3E0/2A2416 · separator EDE3D6/3A322A
               cardStroke EDE3D6/3A322A (เส้นขอบบางบนการ์ด — แบก edge definition แทนเงาในโหมดมืด)
subjectPalette / subjectPaletteHex — 8 สี warm muted [C96F4A,7D8F69,C25B4E,6B7FA3,8E6B9E,B08D57,5F8A8B,C2703C]
               ใช้ร่วมกันทั้งสีวิชา (Schedule) และสีกิจกรรม (Calendar event picker) — ตัวแรกคือ primary เอง
               ⚠️ วิชาที่สร้างก่อน 14 ส.ค. 2569 เก็บ hex เดิม E1802F ไว้ใน DB — เปลี่ยน palette ไม่ย้อนหลัง
Theme.Spacing: xs 4 · sm 8 · md 12 · lg 16 · xl 20 · xxl 24 · xxxl 32
Theme.Radius:  card 18 · control 12 · hero 20 · icon 11 (พื้นไอคอน) · pill 999
Theme.Font:    IBM Plex Sans Thai (UIAppFonts ใน Info.plist, ไฟล์อยู่ StudiiOS/Resources/Fonts/)
               **fallback เป็น system font อัตโนมัติถ้าไม่พบไฟล์** — ดู log [Theme] ตอนเปิดแอป
               title 24 semibold · heading 19 semibold · body 15 · label 13 · caption 11
               number(size) semibold + monospacedDigit — ใช้คู่กับ .contentTransition(.numericText())
Components:    CardContainer<Content>(padding:) (stroke(cardStroke) + เงานุ่ม ตัดเงาในโหมดมืด) · TierBadge(tier:)
               PillLabel(_:systemImage:tone:) · IconTile(systemName:size:tint:background:cornerRadius:)
               SectionHeader(_:systemImage:trailing:) + SectionMoreLabel · PressScaleButtonStyle
               ทั้งหมดอยู่ใน Core/DesignSystem/ (PressScaleButtonStyle ย้ายมาจาก DashboardMenuGrid.swift แล้ว)
```

**ห้าม hardcode สี/ระยะห่างใน View** — ถ้าโทเคนที่ต้องการยังไม่มี ให้เพิ่มใน Theme ก่อน
**กฎ primary vs primaryDeep (ผิดง่าย ต้องจำ):** ขาวบน `primary` (light mode) contrast แค่ 2.86 → ห้ามวางข้อความ/ไอคอนบน `primary` fill ตรงๆ เด็ดขาด จุดที่ fill ทึบ+มีข้อความ/ไอคอนสีขาวข้างใน (วงกลม "วันนี้", FAB, chip ที่เลือกอยู่) ต้องแก้คู่กันเสมอ: fill = `primaryDeep`, ข้อความ/ไอคอน = `Theme.Colors.onPrimary` (**ห้าม hardcode `.white`** เพราะ `onPrimary` ต้องพลิกเป็นสีเข้มในโหมดมืด — `primaryDeep` โหมดมืดเท่ากับ `primary` ที่สว่างอยู่แล้ว)
**Dark mode**: `Theme.Colors` ทั้งหมด adaptive แล้ว hardcoded `Color.white`/`Color(.system*)` ถูกเก็บหมดแล้วใน Round 1 (10 ส.ค. 2569) ยกเว้น 2 กรณีที่ตั้งใจปล่อยไว้ตรงๆ: `Color(hex: colorHex)` ที่อ่านสีที่ผู้ใช้เลือกเอง (`Subject`/`CalendarEvent`) และสีบน scrim/overlay ทับรูปภาพหรือ PDF render ที่ไม่ควรขึ้นกับธีม (`PortfolioCard`, `PortfolioItemSheet`)

---

### ไฟล์ Figma อ้างอิง

**Student OS — UI Frames** · `7qTFOazJhInRwMm7viQbGr` · https://www.figma.com/design/7qTFOazJhInRwMm7viQbGr

18 เฟรมเปล่า (iPhone 16 Pro 402×874) ชื่อตรงกับ struct ใน Swift 1:1 + design tokens 19 ตัวที่ผูกกับ `Theme.swift`
โครง: `01 Screens` (Onboarding 5 / Main Tabs 5) · `02 Sub-screens` (Dashboard 6 / Overlays 2) · `99 Design Tokens`

---

## 6. Entitlements

`EntitlementStore.shared.isUnlocked(.pro)` — ปัจจุบันเป็น toggle ทดสอบใน Settings ยังไม่มี StoreKit จริง
Gated: `PortfolioView`
`TCASPlannerView` เป็น **Free ทั้งหมด** (PLAN_TCASPlanner.md §0.4 — โค้ดจริงไม่เคย gate มาก่อน เอกสารเดิมผิด)

---

## 7. เอกสารในโปรเจกต์ — ระวังของเก่า

| ไฟล์ | สถานะ |
|---|---|
| `StudentOS_รวมเอกสาร.md` | **สโคป/vision — ยังใช้อ้างอิงได้** (เป้าหมาย ไม่ใช่สถานะจริง) |
| `session-2026-07-28-restructure.md` | log เก่า — อธิบายเวอร์ชันที่ยังมี Subject/Chapter/BinderAttachment |
| `StudiiOS/StudiiOS_Audit_Report.md` | ⚠️ **ล้าสมัย** อ้างถึง 45 ไฟล์/6,857 บรรทัด และไฟล์ที่ไม่มีแล้ว (`SubjectDetailView`, `DigitalBinderView`, `GPAPlannerView`, `Subject.swift`) — **ห้ามเชื่อโดยไม่ verify กับซอร์สจริง** |
| `StudiiOS/SchedulePage_Prompt.md` | prompt ของหน้า Schedule |

---

## 8. หนี้ทางเทคนิคที่รู้อยู่แล้ว (ยังไม่ได้แก้)

- ไม่มี `QuickLook` / `ShareLink` — ไฟล์ที่ SmartCapture copy ลง `Documents/SmartCapture/` เปิดดูจาก UI ไม่ได้
- ~~`FocusModeView.swift` อยู่ใน `Features/Portfolio/`~~ **แก้แล้ว** — ย้ายมา `Features/FocusMode/` และเขียนใหม่ทั้งโมดูล
- **ระบบบล็อกแอปยังไม่มี `DeviceActivityMonitor` extension** — ถ้าผู้ใช้บังคับปิด Student OS ทิ้ง แอปที่บล็อกไว้จะยังถูกบล็อกจนกว่าจะเปิด Student OS อีกครั้ง (`reconcile()` ปลดให้) มีปุ่มปลดฉุกเฉินใน ตั้งค่า Pomodoro เป็นทางออกสำรอง
- **แจ้งเตือนจบ Pomodoro ยังไม่ใช่ `.timeSensitive`** — เด้งทะลุโหมดห้ามรบกวนไม่ได้ ต้องเพิ่ม capability "Time Sensitive Notifications" ก่อน
- Calendar models ฝังใน `CalendarView.swift` แทนที่จะอยู่ `Core/Models/`
- ~~ไม่มี unit test จริงเลย~~ **มีแล้วบางส่วน** — `StudiiOSTests/GPAXCalculatorTests.swift` (152 บรรทัด) ครอบ `GPAXCalculator`
  ทั้ง 6 state + fixture §3.3 ของ PLAN_GPA.md + cumulative mode · `StudiiOSTests/RIASECScorerTests.swift` ครอบ `RIASECScorer`
  9 เคส (worked example §3.3, invariant น้ำหนักรวม, flat profiles, straight-lining, missing answer, deterministic tie-break)
  ของ PLAN_RIASEC.md · `StudiiOSTests/TCASScoreEngineTests.swift` ครอบ `TCASScoreEngine` 10 เคส (คะแนนปกติ,
  gap, น้ำหนักไม่ครบ 100, โหมดกลุ่ม × 2, โหมดล็อกตรงกับ worked example §4.3, required > 100%, ล็อกครบทุกวิชา,
  ไม่มีคะแนนเลย) ของ PLAN_TCASPlanner.md ส่วนที่เหลือของแอปยังไม่มีเทสต์
- **`CareerInterestResult` เพิ่ม field ใหม่ (RIASEC v2)** — ถ้าเครื่อง/simulator มีแถวเก่าอยู่แล้วต้อง **ลบแอปก่อนติดตั้งรุ่นนี้**
  (lightweight migration เพิ่ม property ปกติมักผ่าน แต่ไม่การันตี 100% — ดู PLAN_RIASEC.md §4)
- `QuickAddSheet.swift`'s `calendarFields` มี label ภาษาอังกฤษหลงเหลือ (`Repeat` `Location` `Tags` `Alert` `Note` `Detail`) — ผิดกฎ "UI ทั้งหมดเป็นภาษาไทย" ของสกิล ยกมาทั้งดุ้นจาก `SmartCaptureView` เดิม ยังไม่ได้แก้
- `Features/FocusMode/` เป็นโฟลเดอร์ว่าง (ของเหลือ) — `FocusModeView.swift` ยังอยู่ใน `Features/Portfolio/`
- `ScheduleTodayTasksSection`: แตะแถวงาน ตอนนี้แค่ log อย่างเดียว ยังไม่เปิดฟอร์มแก้ไข (หน้า Todo เปิดได้แล้ว — เหลือแค่การ์ดในตารางเรียน)
- **`Features/Onboarding/ScheduleSetupView.swift` ยังมีทางถ่ายรูปของตัวเองอยู่คนละเส้นกับของใหม่** — ไม่ผ่าน
  `ScheduleImportBuilder` / `ScheduleImportReviewSheet` เลย จึงยังไม่แสดงธง ⚠️ ให้ผู้ใช้แก้ และยังไม่ได้ใช้
  `ScheduleOCRResult.problem` (`ocrFoundNothing` เป็น Bool ล้วน) · `PLAN_ScheduleOCRImport.md` §0.4 สั่งไม่ให้แตะไว้ก่อน
  → งานที่เหลือคือย้าย onboarding มาใช้เส้นเดียวกัน แล้วลบโค้ดถ่ายรูปซ้ำทิ้ง
- **`resolveSubject` มีตรรกะซ้ำ 2 ที่**: `ScheduleConstants.resolveSubject` (ฟอร์มคาบ) กับ `ScheduleImportCommitter.resolveSubject` (นำเข้า, มี `inout` cache ของตัวเอง) — กติกาเดียวกัน (รหัสก่อน→ชื่อ) แต่คนละ signature จงใจไม่รวมในรอบนี้
- `refreshAssignmentReminders` ตัดที่ 16 งานแรก (× 3 จุด = 48 pending) กันชน 64 ของ iOS — งานที่กำหนดส่งไกลกว่านั้นจะยังไม่ถูกตั้งจนกว่าจะขยับเข้ามาในหน้าต่าง 14 วัน
- **GPAX `.outOfReach` ยังไม่มีปุ่ม forward action** (§6.5/§11 ของ PLAN_GPA.md ต้องการอย่างน้อย 2 ปุ่ม เช่น ลิงก์ TCASPlannerView/PortfolioView/ปรับเป้า) — ตอนนี้การ์ดโชว์แค่ข้อความ copy เฉยๆ
- **ช่องตั้งเป้า GPAX ตั้งได้ 2 ที่**: `GPAXSummaryCard`'s `TargetQuickSetter` (ชั่วคราว ใส่ไว้ให้ verify build order step 4 ได้ก่อน Settings เสร็จ) กับ Settings ตัวเต็ม (มี `targetSource`) — ทำงานถูกต้องทั้งคู่เพราะ bind key เดียวกัน แต่ UI ซ้ำซ้อน ควรลบตัวแรกทิ้งตอนขัดดีไซน์รอบหน้า

**`PLAN_GPA.md` ครบทั้ง 7 step แล้ว** (logic+เทสต์ → model → read-only display → input → Dashboard → Settings → เอกสารนี้) — ฟีเจอร์ GPAX Level 1 ถือว่าสมบูรณ์ตามแผน รอ Few verify build จริงก่อนตัดสินใจงานต่อไป (Level 2/3 อยู่ใน §12 ของแผน ยังไม่เริ่ม)

**`PLAN_ScheduleView.md` ครบทั้ง 3 รอบแล้ว** (Models/Schema → UI ตาราง+ฟอร์ม → งานวันนี้+ร่นคาบ) — ฟีเจอร์ตารางเรียนถือว่าสมบูรณ์ตามแผน รอ Few verify build จริงก่อนตัดสินใจงานต่อไป

**`PLAN_TCASPlanner.md` ครบทั้ง 4 รอบแล้ว** (Models/Schema+resetAllData → TCASScoreEngine+เทสต์ → ลิสต์คณะ/ตั้งน้ำหนัก/คะแนนของฉัน → SOPEditorView/SOPGuideSheet) — โมดูล TCAS Planner ทั้งหมดถือว่าสมบูรณ์ตามแผน รอ Few verify build จริงก่อนตัดสินใจงานต่อไป (จุดอ่อนที่รู้อยู่แล้ว: swipe-back gesture ใน SOPEditorView ยังไม่ถูกดักด้วย confirmationDialog เตือนไม่บันทึก, ต้องใช้ปุ่ม back ที่ทำเองถึงจะเตือน — ดู §2 บรรทัด SOPEditorView.swift)
