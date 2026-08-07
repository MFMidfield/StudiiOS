# Session Log — 2026-07-28 — Project Restructure + Feature Scaffold

## บริบท

โปรเจกต์เริ่มต้นจาก Xcode SwiftData template เปล่าๆ (มีแค่ `Item.swift` และ dashboard UI ต้นแบบใน `ContentView.swift`) พร้อมเอกสารสโคป `StudentOS_รวมเอกสาร.md` ที่นิยาม "Student OS" — แอป offline-first สำหรับนักเรียนไทย ม.1–ม.6

**คำขอ:** แก้โครงสร้างโปรเจกต์ให้พัฒนาง่าย และมีทุกฟีเจอร์ตามไฟล์ .md
**ขอบเขตที่เลือก:** โครงสร้างโปรเจกต์ + Data models + stub ทุกโมดูล (ให้ build/navigate ได้จริง แต่ logic บางส่วนยังเป็นพื้นฐาน)

## สิ่งที่ทำ

### 1. โครงสร้างโปรเจกต์ใหม่
Xcode ใช้ file-system-synchronized groups อยู่แล้ว (objectVersion 77) — ไฟล์/โฟลเดอร์ใหม่ถูกดึงเข้า target อัตโนมัติโดยไม่ต้องแก้ `.pbxproj`

```
PrototypeApp/
  App/                  → entry point, RootContainerView, RootTabView (5 tabs)
  Core/
    Models/             → SwiftData @Model ทั้งหมด
    DesignSystem/        → Theme, CardContainer, TierBadge, ProUpsellView
    Entitlements/        → FeatureTier + EntitlementStore (Free/Pro/Plus)
    Extensions/           → Color(hex:), Thai/Buddhist date formatting
  Features/              → 1 โฟลเดอร์ต่อ 1 โมดูลจาก .md
```

### 2. SwiftData Models (Core/Models/)
Subject (ศูนย์กลาง), Chapter, Assignment, Note, Flashcard, BinderAttachment,
GradeComponent, ExamEvent, ScheduleEntry, FocusSession, PortfolioItem,
CareerInterestResult, TCASEntry + TCASChecklistItem, SemesterRecord

### 3. Feature Modules ที่ scaffold ครบ (build ผ่าน, มี CRUD จริงบางส่วน)
- **Dashboard** — งานค้าง/วันนี้, คาบถัดไป, สอบใกล้ถึง, Productivity summary (ดึงข้อมูลจริงจาก SwiftData)
- **Subject Hub** — รายวิชา + sub-tabs: Assignments/Notes/Flashcards/ไฟล์/เกรด/สอบ
- **Smart Capture** — sheet เลือก Photo/PDF/Voice/Note (ฟอร์มบันทึกชื่อ, ยังไม่ผูกกล้อง/OCR จริง)
- **School Timeline** — ตารางเรียนรายสัปดาห์ (รองรับ หน้าเสาธง/ชุมนุม/ลูกเสือ/แนะแนว), ตารางสอบ, การบ้าน
- **Digital Binder** — ไฟล์แยกตามรายวิชา
- **Focus Mode** — Pomodoro timer ทำงานจริง + Reading Statistics
- **Exam Mode** — Countdown, Exam Planner, auto-suggest งานที่ควรทบทวน
- **Grade Center** — คำนวณคะแนนรวม/เกรดไทย + คำนวณคะแนนที่ต้องทำเพื่อถึงเกรดเป้าหมาย
- **GPA Planner** — คำนวณ GPAX จากรายวิชาจริง + จำลองผลการเรียน
- **TCAS Planner** (Pro-gated) — คณะ/มหาวิทยาลัยที่สนใจ + checklist + roadmap ม.4–ม.6
- **Portfolio** (Pro-gated) — เกียรติบัตร/กิจกรรม/จิตอาสา/แข่งขัน/โปรเจกต์
- **Career Discovery** — quiz สำรวจความสนใจ → แนะนำอาชีพ/คณะ/ทักษะ (rule-based, offline)
- **Settings** — สถานะ Free/Pro/Plus (toggle ทดสอบ), เปิดดู onboarding ซ้ำได้
- **Onboarding (เพิ่มภายหลัง)** — WelcomeView 4 หน้า แสดงครั้งแรกที่เปิดแอป (`@AppStorage("hasCompletedOnboarding")`)

### 4. สิ่งที่ยังเป็น stub ตั้งใจ (รอต่อยอด)
- Smart Capture: ยังไม่เรียกกล้อง/PDF importer/voice recorder จริง, field `ocrText` เตรียมไว้แต่ยังไม่เรียก Vision Framework
- ไม่มี StoreKit purchase flow จริง (ปุ่ม Pro upsell มี TODO)
- ยังไม่ผูก UserNotifications (เตือน deadline ตาม Smart Rules)

### 5. บั๊กที่เจอระหว่างทดสอบและแก้แล้ว
- **RootTabView**: แท็บ "เพิ่ม" ใช้ `Color.clear` + `onAppear` เปิด sheet แต่ TabView ไม่มี `selection` binding ทำให้ปิด sheet แล้วค้างที่แท็บว่าง → แก้เป็น `TabView(selection:)` + `.onChange(of: selectedTab)` ดีดกลับแท็บเดิมทันทีก่อนเปิด sheet
- **WelcomeView**: ใช้ `.tabViewStyle(.page(indexPrefix: .never))` ผิด API (ไม่มี param นี้ใน iOS 18 SDK ที่ใช้) → แก้เป็น `.tabViewStyle(.page)`

## สถานะปัจจุบัน
`xcodebuild -scheme PrototypeApp -sdk iphonesimulator` → **BUILD SUCCEEDED**

## Next steps ที่แนะนำ
1. ผูกกล้อง + PDFKit importer + AVAudioRecorder ให้ Smart Capture ใช้งานได้จริง
2. เรียก Vision Framework (VNRecognizeTextRequest) เพื่อเติม `BinderAttachment.ocrText`
3. ผูก UserNotifications สำหรับ Smart Rules (เตือน deadline, เตือนวิชาที่ไม่ได้ทบทวน, auto เข้า Exam Mode)
4. เพิ่ม StoreKit 2 สำหรับซื้อ Pro (one-time) และสมัคร Plus (subscription)
