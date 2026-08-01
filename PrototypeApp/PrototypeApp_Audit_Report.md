# PrototypeApp (Student OS) — Code Audit Report

ขอบเขต: ตรวจสอบทั้งโปรเจกต์ (App, Core, Features) รวม 45 ไฟล์ Swift ~6,857 บรรทัด — SwiftUI + SwiftData, iOS, ไม่มีการแก้โค้ดใดๆ ในรายงานนี้

---

## 1. Feature ที่ใช้งานได้จริง (Working)

**Onboarding wizard (Welcome → Profile → Schedule → Grade → Summary)**
`App/PrototypeAppApp.swift` (`RootContainerView`, บรรทัด 53-74) ใช้ `@AppStorage` 5 ตัวสลับหน้าตามลำดับ และแต่ละหน้าตั้งค่า flag ของตัวเองถูกต้อง (`WelcomeView.swift:67`, `ProfileSetupView.swift:138`, `ScheduleSetupView.swift:234`, `GradeReportSetupView.swift:216`, `SetupSummaryView.swift:82`) เชื่อมต่อกันครบเป็น chain เดียว ไม่มีจุดตกหล่น

**OCR Import (ตารางเรียน + ใบ ปพ.)**
`Core/OCR/ScheduleOCRParser.swift` และ `GradeReportOCRParser.swift` ถูกเรียกจริงจาก `ScheduleSetupView.analyze()` (บรรทัด 195-206) และ `GradeReportSetupView.analyze()` (บรรทัด 191-202) ผลลัพธ์ไหลเข้า `@State draftEntries` → ผู้ใช้ตรวจ/แก้ → `saveAndContinue()` แปลงเป็น `Subject`/`ScheduleEntry`/`SemesterRecord` จริงผ่าน `modelContext` ครบวงจร

**Subject Hub (CRUD ครบ: งาน/โน้ต/การ์ด/เกรด/สอบ)**
`SubjectDetailView.swift` มี 6 แท็บ แต่ละแท็บ insert/delete ผ่าน `context` ตรงกับ `@Relationship(deleteRule: .cascade)` ใน `Subject.swift` (บรรทัด 19-41) การลบ Subject จะ cascade ลบทุกอย่างที่ผูกไว้ถูกต้อง

**GradeCenter + GPA Planner (คำนวณ)**
สูตรคำนวณเกรดไทย (`ThaiGrading` enum, `GradeCenterView.swift:182-201`) และสูตร GPAX (`GPAPlannerView.swift:19-24`) เป็น pure function ตรวจสอบ logic ได้ตรงไปตรงมา ไม่มี dependency ภายนอกที่พัง

**Entitlement gating สำหรับ Pro features (Portfolio, TCAS Planner)**
`PortfolioView.swift:17`, `TCASPlannerView.swift:18` เช็ค `EntitlementStore.shared.isUnlocked(.pro)` จริงก่อนแสดง unlocked content — ไม่ใช่แค่ badge ตกแต่ง

**Calendar เดือน/วัน (grid, event CRUD, tag, attachment metadata)**
`CalendarView.swift` — `EventFormSheet.save()` (บรรทัด 830-884) เขียนเข้า `CalendarEvent`/`CalendarAttachmentItem`/`CalendarTag` ถูกต้องตาม schema, `@Query` ผูกกับ grid indicator (`indicatorsForDate`) และ day-detail sheet ใช้งานจริง

---

## 2. Feature ที่ไม่ทำงาน / พังแล้ว (Broken)

**Digital Binder แสดงไฟล์ไม่ได้เลย เพราะจุดเดียวที่สร้าง `BinderAttachment` ไม่เคยผูก `subject`**
จุดที่พัง: `Features/SmartCapture/SmartCaptureView.swift:367`
```swift
context.insert(BinderAttachment(title: "\(title) - \(file.name)", kind: file.kind, fileName: file.name))
```
ทั้งโปรเจกต์มีจุดสร้าง `BinderAttachment` อยู่จุดเดียว (grep ยืนยันแล้ว) และ `portfolioFields` ใน `SmartCaptureView` ไม่มี `subjectPicker` เลย (ต่างจาก `assignmentFields`/`noteFields` ที่มี) ผลคือ `subject` ของทุก `BinderAttachment` เป็น `nil` เสมอ แต่ `DigitalBinderView.swift` (list ตาม `subject.attachments`) และ `SubjectDetailView.SubjectBinderTab` (บรรทัด 181-205, filter จาก `subject.attachments`) จะไม่มีทางเจอไฟล์เหล่านี้เลย — "สมุด" (Digital Binder) ที่โฆษณาไว้ในคอมเมนต์ต้นไฟล์ว่า "organized by subject" จึงว่างเปล่าถาวรไม่ว่าผู้ใช้จะบันทึกไฟล์กี่ครั้งก็ตาม

**ไฟล์ที่แนบ (photo/pdf) ไม่มีทางเปิดดูได้จากที่ไหนในแอปเลย**
`SubjectBinderTab` (`SubjectDetailView.swift:191-193`) และ `SubjectBinderDetailView` (`DigitalBinderView.swift:59-61`) render แค่ `Label(item.title, ...)` เป็น text เฉยๆ ไม่มี `NavigationLink`, `QuickLook`, หรือ `ShareLink` (grep ทั้งโปรเจกต์ไม่พบ `QuickLook`/`QLPreview`/`ShareLink` เลย) ทั้งที่ `SmartCaptureView` มีโค้ด copy ไฟล์จริงลง `Documents/SmartCapture/` (บรรทัด 465-500) — ไฟล์ถูกเก็บจริงแต่ไม่มี UI ใดเปิดดูได้

**การแจ้งเตือน (reminder) ของ Calendar Event ไม่เคยถูกส่งจริง**
`CalendarEvent.alertRaw`/`customAlertMinutes` (`CalendarView.swift:71-72`) ถูกเก็บค่าจาก UI (`alertSection`, บรรทัด 735-747) ครบถ้วน แต่ grep ทั้งโปรเจกต์ไม่พบ `UNUserNotificationCenter` หรือการ schedule local notification ที่ใดเลย — ผู้ใช้เลือก "แจ้งเตือนก่อน 1 ชั่วโมง" ได้ ข้อมูลถูกบันทึก แต่ไม่มีอะไรเกิดขึ้นจริงเมื่อถึงเวลา ทั้งที่ `Info.plist` ประกาศ `UIBackgroundModes: remote-notification` ไว้ (แสดงว่าตั้งใจจะทำ แต่ยังไม่ได้ implement)

**ช่อง "Repeat" และ "Tags" ใน Smart Capture → กิจกรรมปฏิทิน กรอกแล้วข้อมูลหายเงียบๆ**
`SmartCaptureView.swift` มี `@State repeatOption`, `@State tags` และ `calendarFields` (บรรทัด 244-255) ให้ผู้ใช้กรอก แต่ใน `save()` case `.calendar` (บรรทัด 348-361) ไม่มีการส่งค่าทั้งสองตัวนี้เข้า `CalendarEvent` เลย ส่วน computed property `calendarNotes` (บรรทัด 387-399) ที่ดูเหมือนตั้งใจจะรวมค่าพวกนี้ไว้ใน notes ก็ไม่เคยถูกเรียกใช้จริง (dead code) — ผู้ใช้กรอกแล้วกด "บันทึก" ข้อมูล Repeat/Tags หายไปโดยไม่มี error หรือ warning ใดๆ

**"ล้างข้อมูลทั้งหมด" ใน Settings ไม่ได้ลบข้อมูล Calendar**
`SettingsView.resetAllData()` (บรรทัด 134-158) เรียก `deleteAll()` 15 ครั้งครอบคลุมทุกโมเดล ยกเว้น `CalendarEvent`, `CalendarTag`, `CalendarAttachmentItem` (3 โมเดลนี้ถูกประกาศใน schema ที่ `PrototypeAppApp.swift:31-33` แต่ไม่อยู่ในลิสต์ที่ลบ) ข้อความ confirm dialog บอกผู้ใช้ว่า "ข้อมูลทั้งหมดในแอป...จะถูกลบถาวร" (บรรทัด 110) ซึ่งไม่จริง — เหตุการณ์นี้เป็น root cause ชัดเจน: โมเดล Calendar ถูกเพิ่มเข้ามาทีหลัง (ดูจากตำแหน่งท้าย schema list) แต่ไม่มีใครอัปเดตฟังก์ชัน reset ให้ตามทัน

---

## 3. Feature ที่เขียนไว้แต่ไม่ได้ถูกใช้งานจริง (Dead code / Unused)

**`Chapter` model ทั้งโมเดล**
`Core/Models/Chapter.swift` มี relationship ผูกกับ `Assignment.chapter`, `Flashcard.chapter`, `Note.chapter`, `Subject.chapters` ครบ แต่ grep ทั้งโปรเจกต์ไม่พบการเรียก `Chapter(...)` เพื่อสร้าง instance ที่ไหนเลยนอกไฟล์โมเดลเอง และไม่มีหน้าจอใดให้ผู้ใช้สร้าง/เลือก Chapter — ฟีเจอร์ "Chapter-based Learning" ที่ระบุในคอมเมนต์หัวไฟล์ยังไม่ถูกสร้าง UI เลยแม้แต่น้อย

**`BinderAttachment.ocrText`**
ประกาศไว้ (`BinderAttachment.swift:43`) แต่จุดเดียวที่สร้าง `BinderAttachment` (`SmartCaptureView.swift:367`) ไม่เคยส่งค่านี้ และไม่มีหน้าจอไหน read/search จากฟิลด์นี้เลย — เป็นฟีเจอร์ "ค้นหาในเอกสารที่ scan" ที่ตั้งใจไว้แต่ยังไม่ต่อสาย

**`FeatureTier.plus` / `EntitlementStore.hasPlus`**
`FeatureTier` enum และ `EntitlementStore` รองรับ tier `.plus` เต็มรูปแบบ (label, color, UserDefaults key, `isUnlocked`) แต่ไม่มี feature ใดในแอปที่ gate ด้วย `.plus` เลย (ทุกจุด gate ใช้ `.pro` เท่านั้น) และ `SettingsView` ก็มีแค่ Toggle ทดสอบของ `hasPro` ไม่มี Toggle ของ `hasPlus` — โครงสร้าง subscription tier ถูกเตรียมไว้แต่ยังไม่ผูกกับอะไรเลย

**`RootTabView.previousTab`**
`RootTabView.swift:30` ประกาศ `@State private var previousTab` และ set ค่าที่บรรทัด 63 แต่ไม่เคยถูกอ่านใช้งานที่ไหนอีกเลยในไฟล์เดียวกันหรือไฟล์อื่น — dead state

**`AssignmentListView.subjects`**
`AssignmentListView.swift:12` มี `@Query(sort: \Subject.name) private var subjects: [Subject]` แต่ตัวแปรนี้ไม่ถูกอ้างอิงที่ไหนในตัว view เลย (สีของ subject ที่แสดงต่อแถวดึงจาก `assignment.subject` โดยตรง ไม่ผ่าน `subjects` query นี้)

**`SmartCaptureView.normalizedStartDate` / `calendarNotes`**
สอง computed property นี้ (บรรทัด 383-399) ถูกเขียนขึ้นมาโดยตั้งใจให้ normalize วันที่ all-day และรวม field ที่ผู้ใช้กรอก แต่ `save()` ไม่เรียกใช้ทั้งคู่ — เขียนไว้เฉยๆ ไม่มีผลกับพฤติกรรมจริง

---

## 4. จุดที่เสี่ยงจะเกิดบัคในอนาคต (Risky / Fragile)

**Schema/reset list ต้อง sync กันเองด้วยมือ — ระดับความเสี่ยง: สูง**
`PrototypeAppApp.swift` (schema, บรรทัด 15-34), `SettingsView.resetAllData()` (บรรทัด 135-149) และรายการ `.modelContainer(for:)` ใน `#Preview` ของแต่ละไฟล์ ล้วนเป็น "รายชื่อโมเดล" ที่ต้องจำ sync กันเองแบบ manual ไม่มี compiler บังคับ พิสูจน์แล้วว่าเคยพลาดจริง (Calendar models หลุดจาก reset — ดูข้อ 2) ถ้าเพิ่มโมเดลใหม่ในอนาคตมีโอกาสสูงที่จะพลาดจุดใดจุดหนึ่งอีก

**Event creation logic ซ้ำกันคนละที่ระหว่าง `SmartCaptureView` กับ `CalendarView.EventFormSheet` — ระดับความเสี่ยง: สูง**
มี 2 เส้นทางสร้าง `CalendarEvent` ที่เป็นอิสระต่อกัน: `CaptureDetailSheet.save()` (`SmartCaptureView.swift:348-361`) และ `EventFormSheet.save()` (`CalendarView.swift:830-884`) ทั้งสองมี field set ไม่ตรงกัน (ฝั่ง Smart Capture ไม่มี `tags`/`repeatOption` persist ตามข้อ 2, ไม่มี attachment, alert option เป็นแค่ subset) แก้ business rule ที่จุดเดียวจะไม่ sync กับอีกจุด เหมือนที่เกิดขึ้นแล้วกับ Repeat/Tags

**Global `CalendarTag` ถูกลบแบบ global ผ่านเมนูที่ดูเหมือน scope เฉพาะ event เดียว — ระดับความเสี่ยง: กลาง**
`EventFormSheet.deleteTag()` (`CalendarView.swift:906-909`) เรียก `modelContext.delete(tag)` ตรงๆ จาก context menu ของ chip ใน `tagSection` ที่ loop จาก `@Query allTags` (บรรทัด 553, แสดงแท็กทั้งหมดในระบบ ไม่ใช่แค่ของ event นี้) ผลคือผู้ใช้กด "ลบแท็ก" ตอนแก้ event ใดก็ได้ จะลบแท็กนั้นออกจากทุก event ในระบบทันทีโดยไม่มีคำเตือนว่ากระทบ event อื่นด้วย

**Debug artifact หลงเหลือใน production code path — ระดับความเสี่ยง: ต่ำ**
`CalendarView.swift:878-881` มี `print("✅ บันทึกเสร็จ")` และ print ค่า title/startDate/allTags ทุกครั้งที่ save event สำเร็จ เป็นโค้ด debug ที่หลุดเข้ามาใน path การใช้งานจริง ไม่กระทบ functionality แต่บ่งชี้ว่าโค้ด path นี้ยังไม่ผ่านการ cleanup ก่อน ship

**Info.plist usage-description ไม่ครอบคลุมการใช้งานจริงของกล้อง/คลังภาพ — ระดับความเสี่ยง: กลาง**
`NSCameraUsageDescription`/`NSPhotoLibraryUsageDescription` (`Info.plist:9-12`) เขียนว่า "ใช้กล้องเพื่อถ่ายรูปโปรไฟล์ของคุณ" / "เลือกรูปจากคลังภาพเพื่อใช้เป็นรูปโปรไฟล์" แต่กล้อง/คลังภาพถูกใช้จริงอีก 3 จุดที่ไม่เกี่ยวกับโปรไฟล์เลย: ถ่ายตารางเรียน (`ScheduleSetupView`), ถ่ายใบ ปพ. (`GradeReportSetupView`), และแนบไฟล์ Portfolio (`SmartCaptureView`) iOS จะโชว์ข้อความนี้ทุกครั้งไม่ว่าจริงๆ จะใช้เพื่ออะไร ทำให้ผู้ใช้สับสนตอนถ่ายตารางเรียนแต่เจอข้อความ "ถ่ายรูปโปรไฟล์" และมีความเสี่ยงต่อ App Store review เพราะ purpose string ไม่ตรงกับการใช้งานจริงทั้งหมด

**Entitlements ประกาศ CloudKit + remote-notification แต่ไม่มีโค้ดใดใช้งานเลย — ระดับความเสี่ยง: ต่ำ**
`PrototypeApp.entitlements` (บรรทัด 5-14) เปิด `aps-environment` และ `com.apple.developer.icloud-services: CloudKit` ทั้งที่คอมเมนต์ในหลายไฟล์ยืนยันว่า V1 เป็น "offline-first, no cloud sync, no login" (`FeatureTier.swift:6`, `SettingsView.swift:3-5`) grep ยืนยันไม่มี `CKContainer`/`UNUserNotificationCenter`/`registerForRemoteNotifications` ที่ใดเลย — entitlement เกินความจำเป็นเทียบกับโค้ดจริง อาจทำให้ provisioning/App Store review สับสน หรือเป็นสัญญาณว่า capability ถูกเปิดไว้ล่วงหน้าโดยไม่ได้ตั้งใจ

**Onboarding OCR flow ไม่มี error handling กรณี Vision ล้มเหลวแบบเงียบ — ระดับความเสี่ยง: กลาง**
`GradeReportOCRParser.parseGradeReport` และ `ScheduleOCRParser.parseSchedule` (ทั้งคู่บรรทัด ~28-52 ของไฟล์ตัวเอง) เรียก `try? handler.perform([request])` — ถ้า Vision request ล้มเหลว (เช่น permission ผิด, ภาพเสีย) จะ throw error ที่ถูก `try?` กลืนหายไปเงียบๆ, callback ก็ไม่ถูกเรียกเลยเพราะ error เกิดก่อนถึง completion handler ผลคือ `isAnalyzingPhoto` (ตั้งเป็น `true` ใน `analyze()`) จะค้างอยู่ตลอดไป เพราะไม่มี path ไหน set กลับเป็น `false` เมื่อ `perform` throw — UI จะติด spinner "กำลังอ่านตารางเรียน..." ค้างถาวรโดยไม่มีทางออกอื่นนอกจากปิดแอป

---

## จุดที่ควรแก้ก่อนเป็นอันดับแรก (เรียงตามผลกระทบ)

1. **ต่อสาย `subject` ให้ `BinderAttachment` ใน Smart Capture (`SmartCaptureView.swift:367`)** — Digital Binder เป็นฟีเจอร์หลักที่โฆษณาไว้ (เมนู "สมุด" อยู่ในหน้า Dashboard) แต่ใช้งานไม่ได้เลยแม้แต่ครั้งเดียวในสถานะปัจจุบัน เพราะไม่มีทางเชื่อมไฟล์เข้ากับวิชา นี่คือ user-facing bug ที่ severity สูงสุดเพราะกระทบ "ทำอะไรไม่ได้เลย" ไม่ใช่แค่ edge case

2. **แก้ `resetAllData()` ให้ลบ `CalendarEvent`/`CalendarTag`/`CalendarAttachmentItem` ด้วย (`SettingsView.swift:134-158`)** — ฟังก์ชันนี้ผูกกับคำสัญญาที่ชัดเจนต่อผู้ใช้ ("ลบข้อมูลทั้งหมดและเริ่มใหม่") การที่มันไม่ทำตามที่พูดเป็นความเสี่ยงด้าน data privacy/trust โดยตรง และเป็นสัญญาณว่า pattern การ sync รายการโมเดลด้วยมือกำลังจะพังซ้ำอีกเรื่อยๆ ถ้าไม่แก้ที่ระบบ (เช่น เปลี่ยนเป็น derive รายการโมเดลจาก schema เดียวแทนที่จะพิมพ์ซ้ำ 3 ที่)

3. **ใช้งาน local notification จริงสำหรับ Calendar Event reminder หรือเอา UI ออกไปก่อน** — ตอนนี้ผู้ใช้ตั้งค่าการแจ้งเตือนได้เต็มรูปแบบ (custom minutes ด้วยซ้ำ) แต่ไม่มีอะไรเกิดขึ้นจริง สำหรับแอปจัดการชีวิตนักเรียนที่เน้นเรื่อง deadline/exam การแจ้งเตือนที่ไม่ทำงานคือความเสี่ยงที่ทำให้ผู้ใช้พลาดกำหนดส่งงานจริงและเสียความเชื่อถือทันทีที่รู้

4. **เพิ่ม subject picker และแก้ save() ให้ persist tags/repeat ใน Smart Capture calendar flow (`SmartCaptureView.swift:236-260, 348-361`)** — ข้อมูลที่ผู้ใช้กรอกแล้วหายเงียบๆ โดยไม่มี error เป็นรูปแบบบัคที่อันตรายที่สุดประเภทหนึ่ง (silent data loss) เพราะผู้ใช้เข้าใจผิดว่าบันทึกสำเร็จแล้ว

5. **แก้ OCR error path ให้ reset `isAnalyzingPhoto = false` เมื่อ `perform` ล้มเหลว (`ScheduleOCRParser.swift`, `GradeReportOCRParser.swift`)** — แม้ probability ต่ำกว่ากรณีอื่น แต่ effect คือ UI ค้างถาวรระหว่างขั้นตอน onboarding ซึ่งเป็นด่านแรกที่ผู้ใช้ใหม่ต้องผ่าน ถ้าเกิดตรงนี้ผู้ใช้อาจเลิกใช้แอปตั้งแต่ยังไม่ทันเข้าไปถึงฟีเจอร์หลัก
