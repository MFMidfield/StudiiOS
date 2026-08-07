# PLAN — OCR Debug Viewer (รอบ 1: ดูข้อมูลดิบ)

> สร้าง 2026-08-07 · สำหรับรันใน Claude Code
> เป้าหมายของรอบนี้: **เห็นว่า Vision อ่านรูปออกมาเป็นอะไรบ้าง** ยังไม่แตะ heuristic ยังไม่ทำ overlay
> ปลายทางระยะยาว: ผู้ใช้ถ่ายรูปตารางสอนแล้วแอปกรอกให้เอง — รอบนี้คือเครื่องมือที่ทำให้ไปถึงตรงนั้นได้

---

## 0. บริบทที่ต้องรู้ก่อนแก้

### Vision คืนอะไรมา

`VNRecognizeTextRequest` คืน `[VNRecognizedTextObservation]` แต่ละตัว =
**ข้อความ 1 บรรทัด** ที่โมเดลมองว่าติดกัน — **ไม่ใช่ 1 ช่องตาราง**

ช่องที่เขียน 2 บรรทัด (เช่น `คณิตศาสตร์` / `ห้อง 204`) → ได้ **2 observation แยกกัน**

แต่ละตัวมี:

| field | ความหมาย |
|---|---|
| `topCandidates(1).first?.string` | ข้อความ |
| `topCandidates(1).first?.confidence` | ความมั่นใจ 0–1 — **ตอนนี้โค้ดทิ้งทิ้ง ต้องเก็บเพิ่ม** |
| `boundingBox` | `CGRect` normalized 0–1 |

**ระบบพิกัดกลับหัวกับ SwiftUI** — origin อยู่มุม**ซ้ายล่าง**, y ยิ่งมาก = ยิ่งอยู่**บน**
(นี่คือเหตุผลที่ `ScheduleOCRParser` เรียง `$0.y > $1.y` เพื่อให้ได้บน→ล่าง)

**ลำดับที่คืนมาไม่รับประกันอะไรเลย** ไม่ใช่ซ้าย→ขวา ไม่ใช่บน→ล่าง
ทุกอย่างที่ parser ทำจึงอาศัยพิกัดล้วนๆ

### หน้าตา dump ที่ต้องการ (ตัวอย่างสมมติ)

```
🔵 [OCR] ===== Schedule · Vision คืน 23 กล่อง =====
🔵 [OCR] #00  "ตารางเรียน ม.5/2"   x 0.120–0.480  y 0.940  conf 0.98
🔵 [OCR] #01  "คาบ"                x 0.040–0.110  y 0.880  conf 0.95
🔵 [OCR] #02  "จันทร์"             x 0.180–0.300  y 0.880  conf 0.99
🔵 [OCR] #03  "อังคาร"             x 0.340–0.460  y 0.880  conf 0.97
🔵 [OCR] #05  "08:30"              x 0.030–0.120  y 0.800  conf 0.94
🔵 [OCR] #06  "คณิตศาสตร์"         x 0.170–0.310  y 0.800  conf 0.91
🔵 [OCR] #07  "ห้อง 204"           x 0.190–0.290  y 0.770  conf 0.88
🔵 [OCR] ===== จบ =====
```

---

## 1. ไฟล์ที่ต้องแตะ

| ไฟล์ | สถานะ | ทำอะไร |
|---|---|---|
| `PrototypeApp/Core/OCR/OCRTextBox.swift` | **ใหม่** | struct กลางใช้ร่วม 2 parser |
| `PrototypeApp/Core/OCR/ScheduleOCRParser.swift` | แก้ | เก็บ confidence + debug callback + dump |
| `PrototypeApp/Core/OCR/GradeReportOCRParser.swift` | แก้ | เหมือนกัน |
| `PrototypeApp/Features/Settings/OCRDebugView.swift` | **ใหม่** | หน้าทดสอบ |
| `PrototypeApp/Features/Settings/SettingsView.swift` | แก้ | เพิ่ม Section "สำหรับนักพัฒนา" |
| `PROJECT_MAP.md` | แก้ | อัปเดต §2 โครงสร้างไฟล์ ในคอมมิตเดียวกัน |

**ไม่ต้องแตะ:** `Info.plist` (มี `NSCameraUsageDescription` + `NSPhotoLibraryUsageDescription` แล้ว) ·
`.pbxproj` (file-system-synchronized groups) · `Schema` / `resetAllData` (ไม่มี `@Model` ใหม่) ·
`ScheduleSetupView` / `GradeReportSetupView` (param ใหม่มี default ทั้งหมด)

---

## 2. ขั้นตอน

### 2.1 สร้าง `Core/OCR/OCRTextBox.swift`

```swift
//
//  OCRTextBox.swift
//  Shared value type for one line of text recognized by Vision, used by
//  both OCR parsers and by the debug viewer. Vision's coordinate space has
//  its origin at the BOTTOM-left with y increasing upward — the opposite of
//  SwiftUI — so anything drawing these boxes must flip y.
//

import CoreGraphics
import Foundation

struct OCRTextBox: Identifiable {
    let id = UUID()
    let text: String
    /// Normalized 0–1, origin bottom-left (Vision convention).
    let boundingBox: CGRect
    let confidence: Float

    var midX: CGFloat { boundingBox.midX }
    var midY: CGFloat { boundingBox.midY }

    /// One line for the console dump / copy-to-clipboard report.
    func debugLine(index: Int) -> String {
        String(
            format: "#%02d  \"%@\"  x %.3f–%.3f  y %.3f  conf %.2f",
            index,
            text,
            boundingBox.minX,
            boundingBox.maxX,
            boundingBox.midY,
            confidence
        )
    }
}
```

> ลบ `private struct RecognizedTextBox` ออกจาก parser ทั้งสองไฟล์ แล้วใช้ตัวนี้แทน
> ตรวจว่าไม่มีที่อื่นอ้าง `RecognizedTextBox` (มันเป็น `private` อยู่แล้ว → ปลอดภัย)

### 2.2 แก้ `Core/OCR/ScheduleOCRParser.swift`

1. ลบ `private struct RecognizedTextBox` — เปลี่ยนทุกจุดที่ใช้เป็น `OCRTextBox`
2. ตอนสร้างกล่อง เก็บ confidence ด้วย:

```swift
let boxes = observations.compactMap { observation -> OCRTextBox? in
    guard let candidate = observation.topCandidates(1).first else { return nil }
    return OCRTextBox(
        text: candidate.string,
        boundingBox: observation.boundingBox,
        confidence: candidate.confidence
    )
}
```

3. เปลี่ยน signature ของ `parseSchedule` — **เพิ่ม param ที่มี default เท่านั้น ห้ามเปลี่ยนของเดิม**

```swift
static func parseSchedule(
    from image: UIImage,
    onRawBoxes: (([OCRTextBox]) -> Void)? = nil,
    completion: @escaping ([ScheduleDraftEntry]) -> Void
)
```

> ⚠️ `onRawBoxes` ต้องอยู่ **ก่อน** `completion` เพื่อให้ call site เดิมที่ใช้ trailing closure
> (`parseSchedule(from: image) { parsed in ... }` ที่ `ScheduleSetupView.swift:196`) ยังคอมไพล์ได้เหมือนเดิม

4. ใน callback ของ `VNRecognizeTextRequest` หลังได้ `boxes` แล้ว:

```swift
dumpBoxes(boxes, label: "Schedule")
DispatchQueue.main.async { onRawBoxes?(boxes) }
```

5. เพิ่ม helper ในไฟล์ (จะซ้ำใน 2 parser ก็ยอมรับได้ หรือย้ายไป `OCRTextBox.swift` เป็น free function ก็ได้ — เลือกอย่างใดอย่างหนึ่งแล้วทำให้เหมือนกันทั้งสองไฟล์):

```swift
private static func dumpBoxes(_ boxes: [OCRTextBox], label: String) {
    #if DEBUG
    AppLog.action("OCR", "===== \(label) · Vision คืน \(boxes.count) กล่อง =====")
    for (index, box) in boxes.enumerated() {
        AppLog.action("OCR", box.debugLine(index: index))
    }
    AppLog.action("OCR", "===== จบ =====")
    #endif
}
```

**ห้ามแตะ `buildDraftSchedule`** ในรอบนี้ — logic ต้องเหมือนเดิมทุกบรรทัด

### 2.3 แก้ `Core/OCR/GradeReportOCRParser.swift`

เหมือน 2.2 ทุกประการ ต่างแค่:

```swift
static func parseGradeReport(
    from image: UIImage,
    onRawBoxes: (([OCRTextBox]) -> Void)? = nil,
    completion: @escaping ([GradeDraftEntry]) -> Void
)
```

label ใน dump ใช้ `"GradeReport"` · **ห้ามแตะ `buildDraftEntries`**

### 2.4 สร้าง `Features/Settings/OCRDebugView.swift`

ทั้งไฟล์ครอบ `#if DEBUG ... #endif`

**สเปค UI:**

- `Picker` โหมด (`.segmented`): `ตารางเรียน` / `ผลการเรียน (ปพ.)` → กำหนดว่ายิงเข้า parser ตัวไหน
- ปุ่ม **"ถ่ายรูป"** → `ProfileImagePicker(source: .camera, allowsEditing: false) { ... }`
  - แสดงเฉพาะเมื่อ `UIImagePickerController.isSourceTypeAvailable(.camera)` (simulator ไม่มีกล้อง)
- ปุ่ม **"เลือกรูป"** → `ProfileImagePicker(source: .photoLibrary, allowsEditing: false) { ... }`
  - `allowsEditing: false` เพราะ crop ของระบบเป็นสี่เหลี่ยมจัตุรัส จะตัดตารางแนวนอนขาด
- หลังได้รูป: แสดงรูป `.resizable().scaledToFit()` (จำกัดสูงสัก 260) + `ProgressView` ระหว่างรัน
- ลิสต์ผล: `ForEach` กล่องเรียงตาม index ดิบ แต่ละแถวใช้ `box.debugLine(index:)` ฟอนต์ `.system(.caption, design: .monospaced)`
- แถบสรุปบนลิสต์: `"Vision อ่านได้ N กล่อง · parse เป็น M รายการ"`
- ปุ่ม **"คัดลอกทั้งหมด"** → `UIPasteboard.general.string = report` (รวมหัวข้อ + ทุกบรรทัด + จำนวน draft ที่ parse ได้)
- ถ้า `boxes.isEmpty` หลังรันเสร็จ → ข้อความ `"Vision อ่านไม่ได้เลย — ลองถ่ายให้ตรงและสว่างขึ้น"`

**State ที่ต้องมี:**

```swift
@State private var mode: Mode = .schedule
@State private var image: UIImage?
@State private var boxes: [OCRTextBox] = []
@State private var draftCount: Int = 0
@State private var isAnalyzing = false
@State private var picker: ProfileImagePicker.Source?   // ใช้ item-based sheet
```

> ใช้ `.sheet(item:)` กับ enum ที่ conform `Identifiable` แทน bool 2 ตัว จะได้ไม่ต้องจัดการ state ซ้อน
> (`ProfileImagePicker.Source` ยังไม่ conform `Identifiable` — ห่อด้วย wrapper struct เล็กๆ ในไฟล์นี้ อย่าไปแก้ `ProfileImagePicker`)

**การเรียก parser:**

```swift
private func analyze(_ image: UIImage) {
    self.image = image
    boxes = []
    draftCount = 0
    isAnalyzing = true

    switch mode {
    case .schedule:
        ScheduleOCRParser.parseSchedule(from: image) { raw in
            boxes = raw
        } completion: { drafts in
            draftCount = drafts.count
            isAnalyzing = false
        }
    case .gradeReport:
        GradeReportOCRParser.parseGradeReport(from: image) { raw in
            boxes = raw
        } completion: { drafts in
            draftCount = drafts.count
            isAnalyzing = false
        }
    }
}
```

**Design tokens:** ห้าม hardcode สี/ระยะ — ใช้ `Theme.Colors.*` / `Theme.Spacing.*` และ `CardContainer` ถ้าจัดกลุ่ม

**ภาษา:** UI ทั้งหมดภาษาไทย · comment ในโค้ดเป็นอังกฤษได้

### 2.5 แก้ `Features/Settings/SettingsView.swift`

แทรก Section ใหม่ **หลัง** `Section("หลักการออกแบบ")` (บรรทัด ~132) ก่อนปิด `}` ของ `List`

⚠️ `#if DEBUG` วางกลาง `ViewBuilder` ตรงๆ ทำให้ type-check เพี้ยนได้ → **แยกเป็น computed property**

```swift
@ViewBuilder
private var developerSection: some View {
    #if DEBUG
    Section("สำหรับนักพัฒนา") {
        NavigationLink("ทดสอบ OCR") {
            OCRDebugView()
        }
        Text("ดูว่า Vision อ่านรูปออกมาเป็นข้อความอะไรบ้าง — ไม่ขึ้นในเวอร์ชันจริง")
            .font(.caption2)
            .foregroundStyle(.secondary)
    }
    #endif
}
```

แล้วใน `List` เรียก `developerSection` เฉยๆ

### 2.6 อัปเดต `PROJECT_MAP.md`

- §2: เพิ่ม `Core/OCR/OCRTextBox.swift` และ `Features/Settings/OCRDebugView.swift` (ระบุว่า `#if DEBUG`)
- §2: หมายเหตุที่ `Core/OCR/` ว่า parser ทั้งสองมี `onRawBoxes:` callback สำหรับ debug
- ทำในคอมมิตเดียวกัน

---

## 3. สิ่งที่ห้ามทำในรอบนี้

- ห้ามแก้ `buildDraftSchedule` / `buildDraftEntries` — logic การ parse ต้องเหมือนเดิม 100%
- ห้ามแก้ `ScheduleSetupView` / `GradeReportSetupView`
- ห้ามเพิ่ม SPM package
- ห้ามทำ overlay / กรอบสี / เส้นกริด — เก็บไว้รอบ 2 หลังเห็นข้อมูลจริง

---

## 4. ความเสี่ยงที่รู้ล่วงหน้า

| เรื่อง | ผลกระทบ |
|---|---|
| `#if DEBUG` ใน `ViewBuilder` | แก้แล้วด้วย computed property (§2.5) |
| ลำดับ param `onRawBoxes` ก่อน `completion` | ถ้าสลับ trailing closure เดิมจะพัง — ต้องเรียงตามนี้ |
| กล้องรันบน simulator ไม่ได้ | guard ด้วย `isSourceTypeAvailable(.camera)` แล้ว |
| รูปใหญ่มาก | Vision รันบน background queue อยู่แล้ว — UI ไม่ค้าง แต่รูป 12MP อาจใช้เวลา 2–3 วิ |
| `confidence` เป็น `Float` | `String(format: "%.2f")` ต้องรับ `Float` ได้ — cast เป็น `Double` ถ้าคอมไพล์ไม่ผ่าน |

---

## 5. Definition of done

1. `⌘B` ผ่าน
2. Settings → เลื่อนล่างสุด เจอ Section **"สำหรับนักพัฒนา"** → **"ทดสอบ OCR"**
3. เลือกโหมด "ตารางเรียน" → กด **"เลือกรูป"** → เลือกรูปตารางเรียน
4. เห็นรูป + ลิสต์กล่องขึ้นในหน้า พร้อมสรุป `Vision อ่านได้ N กล่อง · parse เป็น M รายการ`
5. Xcode console มีบล็อก `🔵 [OCR] ===== Schedule · Vision คืน N กล่อง =====` ชุดเดียวกัน
6. เครื่องจริง: ปุ่ม **"ถ่ายรูป"** ขึ้นและใช้ได้ · simulator: ปุ่มนี้ไม่ขึ้น
7. กด **"คัดลอกทั้งหมด"** แล้ว paste ที่อื่นได้ข้อความครบ
8. เข้า Onboarding → หน้าตารางเรียน → ถ่าย/เลือกรูป → **ยังทำงานเหมือนเดิมทุกอย่าง** (ไม่ regress)

---

## 6. ผลวิเคราะห์จากตารางจริงใบแรก (บันทึก 2026-08-07)

> เอกสารส่วนนี้เขียนจากดัมป์จริง 141 กล่องของตาราง **ม.5/9 ห้อง 235 · ภาคเรียน 1/2569 · โรงเรียนเมืองสุราษฎร์ธานี**
> **ยังไม่ได้แก้โค้ดอะไรเลย** — เก็บไว้เป็นฐานตัดสินใจของรอบ 2

### 6.1 ข้อค้นพบหลัก — `buildDraftSchedule` สลับแกน

ตารางใบนี้ **วันเป็นแถว คาบเป็นคอลัมน์** แต่โค้ดปัจจุบันสมมติว่าวันเป็นคอลัมน์:

| ตัวแปรในโค้ด | ค่าที่ได้จริง | ผล |
|---|---|---|
| `dayColumns` (midX ของชื่อวัน) | จันทร์ 0.0825 · อังคาร 0.0830 · พฤหัสฯ 0.0815 · ศุกร์ 0.0835 | ชิดขอบซ้ายหมด → ทุกกล่องเลือก "ศุกร์" (x มากสุด) |
| `timeRows` (midY ของกล่องเวลา) | 0.709, 0.709, 0.707, 0.707, 0.706 | อยู่แถวเดียวกันหมด → `firstIndex(where: midY >= $0.y)` ตกทุกกล่องที่ y < 0.706 |

**ข้อมูลวิชาทั้งหมดถูก `continue` ทิ้ง** เหลือแต่กล่องที่ y ≥ 0.706 คือ title + "คาบ" + "เวลา" + เลขคาบ 0–10
= **14 กล่องพอดี ตรงกับ `parse เป็น 14 รายการ` ในดัมป์เป๊ะ**

> สรุป: ตอนนี้วิชาจริงเข้าไป **0 รายการ** ที่เห็น 14 รายการคือหัวตารางล้วนๆ ติดป้ายวันศุกร์ทั้งหมด
> **นี่คือบั๊กที่ต้องแก้ก่อนเรื่อง OCR ทุกเรื่อง**

### 6.2 คุณภาพ OCR แยกเป็นชั้น

| ชั้น | ผล | หมายเหตุ |
|---|---|---|
| พิกัด x, y | **~100% ถูก** | ทุกกล่องตกช่องถูกต้อง — เชื่อพิกัดได้เต็มที่ |
| ข้อความรวม | 141 กล่อง เพี้ยน ~20 = **86% สะอาด** | |
| ห้องเรียน (`\d{3}`) | **0% ผิด** | |
| ชื่อครู | 2 ผิด / 28 ≈ **7%** | `ครวรัญญา` (ตก สระ ู), `ครูจริยา`/`ครูจาริยา` แยกไม่ออกว่าคนเดียวกันไหม |
| **รหัสวิชา** | **11 ผิด / 34 = 32%** | จุดที่แย่ที่สุด แต่แก้ง่ายที่สุด |
| กล่องคร่อมหลายช่อง | 5 กล่อง | #19 (เวลา 8 ช่องรวด), #60, #82, #98, #112 |

### 6.3 รหัสวิชาผิดแบบเดียวกันหมด

พยัญชนะไทย **ตัวแรก** ถูกอ่านเป็นตัวเลข/ละติน — ตัวที่ 2–6 (ตัวเลข) **ถูกทุกตัว**

| อ่านได้ | ที่ถูก | ครั้ง |
|---|---|---|
| `2` | `ว` | 5 (`230243` ×2, `230203` ×2, `230282`, `232281`) |
| `1` | `ท` | 2 (`132201` ×2) |
| `0` | `ง` หรือ `อ` | 2 (`032201`, `032101`) — **แยกไม่ออกด้วยรูปร่างอย่างเดียว** |
| `W` | `พ` | 1 (`W32101`) |
| `3` | `ส` | 1 |

ตารางความสับสนที่ควรมี (ประเมินเพิ่มจากรูปทรง):
`2↔ว` · `0↔ง,อ` · `1↔ท` · `W,w,N↔พ` · `A,6,ด↔ค` · `4↔ง` · `a↔ส` · `n↔ก,ท` · `ค↔ศ`

### 6.4 ทำไม rule-based เอาอยู่ — anchor ในภาพแข็งแรงมาก

**ก) กริดสม่ำเสมอเกือบสมบูรณ์แบบ** → fit เส้นตรงแล้วกู้แถว/คอลัมน์ที่อ่านไม่ออกกลับมาได้

```
"โฮมรูม"  y = 0.673, 0.589, 0.505, 0.421, 0.338   ห่าง 0.084 เท่ากันเป๊ะ ×5
"พัก"     y = 0.677, 0.592, 0.508, 0.424, 0.340   ห่าง 0.084  → anchor สำรอง ไว้ cross-check
เลขคาบ    x = 0.146, 0.215, 0.285, ... , 0.839    ห่าง 0.0693 เท่ากัน
```

> สำคัญ: Vision อ่านชื่อวัน **"พุธ" ไม่ออกเลย** แต่ anchor โฮมรูมให้ครบ 5 แถวโดยไม่ต้องพึ่งชื่อวัน
> → **ห้ามใช้ชื่อวันเป็น anchor หลัก** ให้ใช้เป็นแค่ตัวติดป้ายว่าแถวไหนคือวันอะไร

**ข) sub-row ในแต่ละวันคงที่ทั้ง 5 วัน** → จำแนกฟิลด์แบบ deterministic ไม่ต้องเดา

```
offset จาก anchor แถว:   0.000 = รหัสวิชา  ·  −0.021 = ชื่อครู  ·  −0.047 = ห้อง
```

**ค) ทุกฟิลด์มีไวยากรณ์แคบ** → ตรวจจับ error ได้ 100% แม้ยังซ่อมไม่ได้

```
รหัสวิชา  ^[ก-ฮ]\d{5}$    ตัวแรกใช้จริงแค่ ~9 ตัว: ท ค ว ส พ ศ ง อ ก
ชื่อครู   ^ครู
ห้อง      ^\d{3}$  หรือคำที่รู้จัก (นาฏศิลป์, คณิต 1)
เวลา      \d{2}\.\d{2}-\d{2}\.\d{2}
```

**ง) ข้อมูลซ้ำกันเองในภาพเดียว** → majority vote ฟรี
`ว30203` ถูก 3 ครั้ง / ผิดเป็น `230203` 2 ครั้ง → โหวตชนะ
`ครูวันทนา` คู่กับ `ว30203` ทุกครั้ง → cross-check ครู↔รหัส ได้อีกชั้น

### 6.5 ของถูกที่ควรลองก่อนเขียน logic ซ้อน

1. **`topCandidates(1)` → `topCandidates(5)`** แล้วเลือกตัวแรกที่ผ่าน `^[ก-ฮ]\d{5}$`
   Vision มี candidate สำรองให้ถึง 10 ตัว — ตัวที่ถูกมักอยู่อันดับ 2–3
   ราคา ~10 บรรทัด อาจฆ่า error 32% ไปได้ครึ่งหนึ่งโดยไม่ต้องใช้ตารางความสับสนเลย
2. **A/B `usesLanguageCorrection`** — ตอนนี้เปิดอยู่ กับตารางที่เต็มไปด้วยรหัสและชื่อเฉพาะ มันมีสิทธิ์ทำให้แย่ลง
3. **OCR รายช่อง (2 pass)** — pass 1 หากริด, pass 2 ยิง `regionOfInterest` ทีละช่อง
   แก้ปัญหากล่องคร่อม (#19, #60, #82, #112) ได้หมดในทีเดียว

### 6.6 ทำไมไม่ใช้ on-device LLM

Foundation Models framework ต้องใช้ **iPhone 15 Pro ขึ้นไป** (A17 Pro+) ส่วน Vision OCR ทำงานบนทุกเครื่องที่รัน iOS 26 ได้
นักเรียนไทยส่วนใหญ่อยู่กลุ่มหลัง → **rule-based ไม่ใช่การประนีประนอม แต่เป็นทางเดียวที่ครอบคลุมผู้ใช้จริง**

### 6.7 หลักการออกแบบรอบ 2

> **ซ่อมสิ่งที่พิสูจน์ได้ + ติดธงสิ่งที่พิสูจน์ไม่ได้** — ห้ามตั้งเป้าอัตโนมัติ 100%

ช่องที่เหลือ 2 candidate ถูกต้องทั้งคู่ (เช่น `0` เป็น `ง` หรือ `อ`) แยกไม่ออกจริงๆ ต้องให้คนตัดสิน
ผู้ใช้แตะแก้ 3 ช่อง = UX ที่ยอมรับได้ · ผู้ใช้ไม่รู้ว่า 3 ช่องผิด = UX ที่แย่

คาดการณ์ผลจากรูปใบนี้: **0 รายการ → ~35 รายการ · ถูกเป๊ะ ~30 · ติดธงให้แก้ ~5**

### 6.8 ประมาณงานรอบ 2

| งาน | ประมาณ |
|---|---|
| detect orientation อัตโนมัติ + fit กริดเชิงเส้น + จำแนก sub-row | ~250 บรรทัด (งานหลัก) |
| grammar validator + re-rank `topCandidates` | ~100 |
| ตารางความสับสน + majority vote + cross-check ครู↔รหัส | ~120 |
| แยกกล่องคร่อมตามขอบคอลัมน์ | ~60 |
| รองรับหัววันแบบย่อ (`อ.` `พฤ.` `พฤหัส`) และแยกชื่อห้อง/ชื่อครูไม่ให้ปนเป็นชื่อวิชา | ~40 |
| **Overlay แยกสี** 🔵 anchor แถว · 🟠 anchor คอลัมน์ · 🟢 สำเร็จ · 🔴 ถูกทิ้ง + เส้นกริดที่เดา | — |
| **Error case ให้ผู้ใช้** — ตอนนี้คืน `[]` เงียบสนิท ผู้ใช้เห็นหน้าว่างโดยไม่รู้ว่าต้องถ่ายใหม่ยังไง | — |

**ความเสี่ยงที่รู้ล่วงหน้า:** วิเคราะห์จากตารางใบเดียว — โรงเรียนอื่นอาจวางวันเป็นคอลัมน์
→ ต้องเขียนเป็น **auto-detect orientation** ไม่ใช่ hardcode ว่าวันเป็นแถว

### 6.9 Ground truth ของรูปใบนี้ (ไว้ทำ regression test)

ช่องรูปแบบ `รหัส · ครู · ห้อง` · ⚠️ = ยังไม่ชัด

| คาบ | เวลา | จันทร์ | อังคาร | พุธ | พฤหัสฯ | ศุกร์ |
|---|---|---|---|---|---|---|
| 0 | 08.15–08.30 | โฮมรูม | โฮมรูม | โฮมรูม | โฮมรูม | โฮมรูม |
| 1 | 08.30–09.20 | ส32163 · บัวมาศ · 235 | ท32101 · ณัฏฐนันท์ · 235 | ว30203 · วันทนา · 235 | ว30282 · สิริยากร · 233 | ว32281 · วรัญญา · 238 |
| 2 | 09.20–10.10 | ค32101 · จริยา · 235 | ค32203 · ทัชชกร · 235 | ว30203 · วันทนา · 235 | ว30282 · สิริยากร · 233 | ว32281 · วรัญญา · 238 |
| 3 | 10.10–11.00 | ว30243 · ครรชิต · 235 | พ32101 · ประทุมวรรณ · 235 | ค32203 · ทัชชกร · 235 | ว30223 · เบญจพร · 235 | ⚠️ ว่าง / "สังคม" |
| 4 | 11.00–11.50 | ว30243 · ครรชิต · 235 | อ32101 · ปรางค์ทิพย์ · 235 | ท32101 · ณัฏฐนันท์ · 235 | ว30223 · เบญจพร · 235 | ว30243 · ครรชิต · 235 |
| 5 | 11.50–12.40 | พัก | พัก | พัก | พัก | พัก |
| 6 | 12.40–13.30 | ค32203 · ทัชชกร · 235 | ง32201 · ณัฐพงศ์ · 235 | ⚠️ เบญจพร · คณิต 1 | ก32993 · จาริยา · 235 | ค32203 · ทัชชกร · 235 |
| 7 | 13.30–14.20 | ศ32101 · วุฒินันท์ · นาฏศิลป์ | ว30203 · วันทนา · 327 | ว30223 · เบญจพร · 235 | อบรมระดับ ม.5 · 235 | อ32101 · ปรางค์ทิพย์ · 235 |
| 8 | 14.20–15.10 | อ32101 · อนันต์ · 235 | ว30203 · วันทนา · 327 | ชุมนุม | ⚠️ ส30203 · ที่ปรึกษา ม.5 · 235 | ท32201 · จารุณี · 235 |
| 9 | 15.10–16.00 | — | ส32101 · จันทณา · 235 | ⚠️ อ32201 · "ครู A" · 235 | กิจกรรมในเครื่องแบบ | ท32201 · จารุณี · 235 |
| 10 | 16.00–16.50 | — | — | — | — | — |
