# PLAN — OCR รอบ 2: ทำให้อ่านตารางเรียนได้จริง

> สร้าง 2026-08-07 · ต่อจาก `PLAN_OCRDebug.md` (รอบ 1 เสร็จแล้ว)
> เป้าหมาย: **ไม่ใช่ "แม่น 100%" แต่เป็น "ผิดตรงไหนผู้ใช้รู้และแตะแก้ได้"**
> ข้อมูลอ้างอิง: dump จริง 141 กล่อง จากตารางเรียน ม.5/9 โรงเรียนเมืองสุราษฎร์ธานี

---

## 0. หลักฐานจาก dump จริง — อ่านก่อนเขียนโค้ด

ทุกตัวเลขในหัวข้อนี้นับจาก dump จริง ไม่ใช่การเดา **ใช้เป็น test fixture ได้เลย**

### 0.1 บั๊กแกน — ทำไมได้ 14 รายการที่เป็นหัวตารางล้วน

ตารางจริง: **วันเป็นแถว (แนวตั้ง) · คาบเป็นคอลัมน์ (แนวนอน)**
โค้ดเดิมสมมติกลับกัน

```
#02 "จันทร์"  x 0.065–0.100  y 0.652
#03 "อังคาร"  x 0.064–0.102  y 0.567    ← x เท่ากัน, y ต่างกัน = วันเรียงลงมา
```

`dayColumns` เก็บ `midX` ของทุกวัน → ได้ ≈ 0.082 เท่ากันหมด → `min(by:)` เลือกตัวไหนก็ได้

`timeRegex` จับได้ 5 กล่อง — **y เกือบเท่ากันหมด** เพราะเวลาเป็นหัวคอลัมน์:

```
#07 y 0.709 · #18 y 0.706 · #19 y 0.709 · #31 y 0.707 · #32 y 0.707
```

บรรทัดนี้จึงผ่านเฉพาะกล่องที่ y ≥ 0.706:

```swift
guard let rowIndex = timeRows.firstIndex(where: { box.boundingBox.midY >= $0.y })
```

กล่องที่ผ่าน = "คาบ" · "เวลา" · หัวเรื่อง · เลขคาบ 0–10 (11 ตัว) = **14 พอดี**
อีก 127 กล่องถูก `continue` ทิ้งเงียบ

### 0.2 ⚠️ confidence ใช้คัด candidate ไม่ได้ — มันกลับด้าน

| กล่อง | อ่านได้ | ถูก? | conf |
|---|---|---|---|
| #22 | `230243` | ✗ | **1.00** |
| #52 | `W32101` | ✗ | **1.00** |
| #56 | `230203` | ✗ | **1.00** |
| #88 | `230282` | ✗ | **1.00** |
| #109 | `232281` | ✗ | **1.00** |
| #21 | `ค32101` | ✓ | 0.50 |
| #34 | `ศ32101` | ✓ | 0.50 |

**รหัสวิชาที่ผิดทุกตัวมี conf = 1.00** ส่วน conf 0.50 ถูกหมด

→ **ห้ามใช้ `confidence` เป็นเกณฑ์เลือก candidate เด็ดขาด** ต้องใช้ validator เชิงไวยากรณ์อย่างเดียว
→ นี่คือเหตุผลที่ multi-candidate (ข้อ 3) **ทำเดี่ยวๆ ไม่ได้** ต้องมัดกับ validator (ข้อ 6) ตั้งแต่แรก

### 0.3 Anchor ที่ดีที่สุด — เลขคาบ ไม่ใช่ชื่อวัน / โฮมรูม

**เลขคาบ 0–10 อ่านออกครบ 11 ตัว** บนแถว y ≈ 0.741:

```
#06 "0"  midX 0.146    #24 "5"  midX 0.493
#14 "1"  midX 0.215    #26 "6"  midX 0.564
#15 "2"  midX 0.285    #27 "7"  midX 0.633
#16 "3"  midX 0.355    #28 "8"  midX 0.702
#17 "4"  midX 0.424    #29 "9"  midX 0.771
                       #30 "10" midX 0.840
```

เทียบกับ:
- **ชื่อวัน** — "พุธ" อ่านไม่ออกเลย (มีแค่ จันทร์ อังคาร พฤหัสฯ ศุกร์) → ใช้เป็น anchor แถวเดี่ยวๆ ไม่ได้
- **"โฮมรูม"** — ครบ 5 แถว (#08–#12) แต่ให้แค่คอลัมน์ 0
- **"พัก"** — ครบ 5 แถว (#25 #54 #75 #92 #114) ให้แค่คอลัมน์ 5

→ **เลขคาบ = anchor คอลัมน์** · **โฮมรูม + พัก = anchor แถว** (10 จุด, ครบทั้ง 5 แถว)

### 0.4 กริดเชิงเส้น — พิสูจน์แล้วว่าเป๊ะ

```
คอลัมน์:  x(n) = 0.1445 + 0.0693 · n     n = 0…10   คลาดเคลื่อนสูงสุด 0.0025
แถว:      y(r) = 0.673  − 0.084  · r     r = 0…4    (จันทร์…ศุกร์)
```

ตรวจย้อน: `x(8) = 0.699` = midX ของ #35 เป๊ะ · `y(4) = 0.337` ≈ #109 (0.337) เป๊ะ
โฮมรูม 5 ตัว: y = 0.673 · 0.589 · 0.505 · 0.421 · 0.338 → ต่าง 0.084 ทุกช่วง

**3 บรรทัดในหนึ่งช่อง** (offset จาก `y(r)`):

```
บรรทัด 1 (รหัสวิชา)  y(r) − 0.000
บรรทัด 2 (ชื่อครู)    y(r) − 0.022
บรรทัด 3 (ห้อง)      y(r) − 0.046
```

### 0.5 ตารางความสับสน — นับจาก 11 ตัวที่ผิดจริง

| อ่านได้ | ที่ถูก | ครั้ง | กล่อง |
|---|---|---|---|
| `2` | `ว` | **6** | #22 #56 #72 #88 #109 #113 |
| `W` | `พ` | 1 | #52 |
| `0` | `ง` **หรือ** `อ` | 2 | #35 (ง32101) · #55 (อ32201) |
| `1` | ? | 2 | #117 #137 (ต้นฉบับก็อ่านยาก) |

**`0` ออกได้ทั้ง ง และ อ** → ซ่อมอัตโนมัติไม่ได้ ต้องติดธงให้ผู้ใช้เลือก (= ข้อ 10)
`ท → 1` ที่เคยสงสัย **ไม่พบในภาพนี้** (#50 #74 อ่าน `ท32101` ถูกทั้งคู่) — อย่าใส่ลงตารางจนกว่าจะเจอจริง

### 0.6 กล่องคร่อมหลายช่อง

| กล่อง | ข้อความ | คร่อม |
|---|---|---|
| #19 | `09.20-10.10 10.10-11.00 … 15.10-16.00` | เวลา 8 คอลัมน์ |
| #60 | `ครูประทุมวรรครูปรางค์ทิพย์` | ครู 2 คน (คอลัมน์ 3–4) |
| #98 | `ครูเบญจพร. ครูเบญจพร.` | ครู 2 คน |
| #82 | `คณิต 1 ครูเบญจพร.` | ลายมือเขียนทับ + ชื่อครู |
| #112 | `ครวรัญญา สังคม` | ครู + ลายมือ |

เกณฑ์ตรวจจับ: **ความกว้างกล่อง > 1.5 × column step (0.104)** → เข้าข่ายต้อง split

---

## 1. ลำดับงาน 3 ระยะ

> **หมายเหตุ:** Few เสนอลำดับ 3 → 1+2 → ที่เหลือ
> ผมปรับเป็น (3+6+7) → (1+2+9) → (8+10+4+5) เพราะ §0.2 พิสูจน์ว่า
> ข้อ 3 ที่ไม่มีข้อ 6 มาตัดสิน = เก็บ candidate ไว้เฉยๆ เลือกไม่ถูกอยู่ดี
> ส่วน (3+6+7) รวมกันวัดผลได้ทันทีใน `OCRDebugView` โดยไม่ต้องรอ grid detector

| ระยะ | ข้อในลิสต์ | ผลที่วัดได้ | ขนาด |
|---|---|---|---|
| **A** | 3 · 6 · 7 | รหัสวิชาผิด 32% → คาดว่าเหลือ ~6% | ~90 บรรทัด |
| **B** | 1 · 2 · 9 · 5 | วิชาจริงเข้า 0 → คาดว่า ~50 รายการ | ~200 บรรทัด (เขียนใหม่) |
| **C** | 8 · 10 · 4 | ผู้ใช้เห็นและแก้ช่องที่น่าสงสัยได้ | ~150 บรรทัด |

**ทำทีละระยะ · จบระยะแล้ว build + ทดสอบกับรูปเดิม + commit ก่อนขึ้นระยะถัดไป**

---

## 2. ระยะ A — candidate + validator + ตารางความสับสน

### 2.1 ไฟล์ใหม่ `Core/OCR/SubjectCodeValidator.swift`

```swift
//
//  SubjectCodeValidator.swift
//  Thai school subject codes are always ONE Thai consonant followed by
//  exactly five digits (ว30243, ค32101). Vision frequently misreads the
//  leading consonant as a digit or Latin letter — but never the reverse,
//  because the five trailing digits give the model plenty of context.
//  That asymmetry makes the grammar a reliable 100%-recall error detector.
//
//  NOTE: do NOT use VNRecognizedText.confidence to pick between candidates.
//  Measured on a real timetable, every wrong code had confidence 1.00 while
//  several correct ones had 0.50 — the signal is inverted and useless here.
//

import Foundation

enum SubjectCodeValidator {
    /// Thai consonants ก (U+0E01) … ฮ (U+0E2E)
    private static let thaiConsonants: ClosedRange<UInt32> = 0x0E01...0x0E2E

    /// Confusion pairs observed on real report photos.
    /// Value = every plausible correction, most likely first.
    /// Only entries with EXACTLY ONE candidate get auto-repaired; the rest
    /// are flagged for the user (see `repair`).
    static let confusionMap: [Character: [Character]] = [
        "2": ["ว"],
        "W": ["พ"],
        "w": ["พ"],
        "0": ["ง", "อ"],          // genuinely ambiguous — always flag
        "1": ["ท", "ก", "จ"],     // unconfirmed, flag
    ]

    /// True when `text` is a well-formed subject code.
    static func isValid(_ text: String) -> Bool {
        let t = text.trimmingCharacters(in: .whitespaces)
        guard t.count == 6 else { return false }
        guard let first = t.unicodeScalars.first,
              thaiConsonants.contains(first.value) else { return false }
        return t.dropFirst().allSatisfy(\.isNumber)
    }

    /// True when `text` LOOKS like a subject code slot (6 chars, last five
    /// are digits) regardless of whether the first char is a Thai consonant.
    /// Used to decide "this box was supposed to be a code" before repairing.
    static func looksLikeCode(_ text: String) -> Bool {
        let t = text.trimmingCharacters(in: .whitespaces)
        guard t.count == 6 else { return false }
        return t.dropFirst().allSatisfy(\.isNumber)
    }

    enum Repair {
        case alreadyValid(String)
        case repaired(String)                    // one unambiguous fix
        case ambiguous(options: [String])        // needs the user
        case unknown                             // no idea — needs the user
    }

    /// Step 2 of the pipeline (see §2.3). Only handles the single-character
    /// confusion table; voting across the whole image happens in stage C.
    static func repair(_ text: String) -> Repair {
        let t = text.trimmingCharacters(in: .whitespaces)
        if isValid(t) { return .alreadyValid(t) }
        guard looksLikeCode(t), let first = t.first else { return .unknown }
        guard let options = confusionMap[first] else { return .unknown }
        let tail = t.dropFirst()
        let fixed = options.map { String($0) + tail }
        return fixed.count == 1 ? .repaired(fixed[0]) : .ambiguous(options: fixed)
    }
}
```

### 2.2 แก้ `Core/OCR/OCRTextBox.swift` — เก็บ candidate หลายตัว

เพิ่ม field (ของเดิมไม่ลบ เพื่อไม่ให้ `OCRDebugView` พัง):

```swift
/// Up to 10 alternatives from Vision, best-first. `text` == candidates[0].
let candidates: [String]
```

เพิ่ม init ที่ default `candidates: [text]` เพื่อให้ call site เดิมยังคอมไพล์ได้

### 2.3 แก้ `Core/OCR/ScheduleOCRParser.swift`

**ตอนสร้างกล่อง** — ขอ candidate 10 ตัว:

```swift
let boxes = observations.compactMap { observation -> OCRTextBox? in
    let candidates = observation.topCandidates(10)
    guard let best = candidates.first else { return nil }
    return OCRTextBox(
        text: best.string,
        boundingBox: observation.boundingBox,
        confidence: best.confidence,
        candidates: candidates.map(\.string)
    )
}
```

**เพิ่มฟังก์ชันเลือก candidate** — ลำดับสำคัญ ห้ามสลับ:

```swift
/// Pipeline, in order:
///   1. any candidate that already parses as a valid code wins
///   2. single-option confusion repair on the best candidate
///   3. give up → caller flags the cell for review
/// Confidence is deliberately never consulted (see SubjectCodeValidator docs).
static func resolveSubjectCode(_ box: OCRTextBox) -> (code: String, needsReview: Bool) {
    for candidate in box.candidates where SubjectCodeValidator.isValid(candidate) {
        return (candidate, false)
    }
    switch SubjectCodeValidator.repair(box.text) {
    case .alreadyValid(let c): return (c, false)
    case .repaired(let c):     return (c, false)
    case .ambiguous(let o):    return (o.first ?? box.text, true)
    case .unknown:             return (box.text, true)
    }
}
```

### 2.4 แสดงผลใน `OCRDebugView` — นี่คือวิธีวัดว่าระยะ A ได้ผล

เพิ่มคอลัมน์ท้ายแต่ละแถวในลิสต์:

```
#22  "230243"  x 0.330–0.375  y 0.672  conf 1.00   ⟶ ว30243  ✅ ซ่อมแล้ว
#35  "032101"  x 0.676–0.722  y 0.672  conf 1.00   ⟶ ง32101  ⚠️ กำกวม (ง/อ)
#20  "ส32163"  x 0.192–0.237  y 0.672  conf 1.00   ⟶ —       ✓ ถูกอยู่แล้ว
```

เพิ่มบรรทัดสรุปหัวลิสต์:

```
รหัสวิชา 34 ตัว · ถูกเลย 23 · ซ่อมได้ 7 · ต้องให้คนดู 4
```

**เกณฑ์ผ่านระยะ A:** ยิงรูปเดิมแล้ว "ซ่อมได้" ต้อง ≥ 6 ตัว (`230243` `230203`×2 `230282` `232281` `W32101`)
และ "ต้องให้คนดู" ต้องมี `032101` `032201` `132201`×2 ครบ

### 2.5 ห้ามทำในระยะ A

- ห้ามแตะ `buildDraftSchedule` (ยังพังอยู่ แต่จะรื้อในระยะ B)
- ห้ามแตะ `GradeReportOCRParser` (คนละโครงสร้าง ไว้ทีหลัง)

---

## 3. ระยะ B — เขียน grid detector ใหม่

### 3.1 ไฟล์ใหม่ `Core/OCR/ScheduleGridDetector.swift`

แยกออกจาก `ScheduleOCRParser` เพราะเป็น logic ล้วน ทดสอบแยกได้
(แนวเดียวกับ `PeriodShiftCalculator` / `AssignmentPriorityEngine` ที่มีอยู่)

```swift
struct DetectedGrid {
    /// x(n) = columnOrigin + columnStep * n
    let columnOrigin: CGFloat
    let columnStep: CGFloat
    let columnCount: Int
    /// y(r) = rowOrigin + rowStep * r   (rowStep is NEGATIVE — Vision's y grows upward)
    let rowOrigin: CGFloat
    let rowStep: CGFloat
    let rowCount: Int

    func column(for x: CGFloat) -> Int?   // nil ถ้าห่างเกิน tolerance
    func row(for y: CGFloat) -> Int?
}
```

**ขั้นตอน:**

1. **หา anchor คอลัมน์** — กล่องที่ `Int(text)` อยู่ในช่วง 0…12 และ y อยู่ในกลุ่ม y ที่มีสมาชิกมากสุด
   → ได้คู่ `(period, midX)` (ในรูปตัวอย่างได้ครบ 11 คู่)
2. **fit เชิงเส้น** `x = a + b·period` ด้วย least squares → กู้คอลัมน์ที่หายไปได้
   - fallback ถ้าได้ anchor < 3 คู่: ใช้ "โฮมรูม" (คอลัมน์ 0) + "พัก" (คอลัมน์ 5) → `b = (x_พัก − x_โฮมรูม) / 5`
3. **หา anchor แถว** — กล่อง `"โฮมรูม"` ทุกตัว (คาดว่า x ≈ x(0)) + `"พัก"` ทุกตัว (x ≈ x(5))
   เรียง y จากมากไปน้อย → index = row
   - **ไม่ใช้ชื่อวันเป็น anchor** เพราะ "พุธ" อ่านไม่ออก แต่ยัง**ใช้ยืนยัน**ได้: ถ้าเจอ "จันทร์" ที่ row 0 = ถูกทาง
4. **fit เชิงเส้น** `y = c + d·row`
5. **assign** ทุกกล่องที่เหลือ: `col = round((x − a)/b)` `row = round((y − c)/d)`
   ทิ้งถ้าห่างเกิน **0.4 × step** (กันหัวเรื่อง / ลายเซ็นท้ายกระดาษ #13 #140 หลุดเข้ามา)

### 3.2 แยกกล่องที่คร่อมหลายช่อง (ข้อ 5)

ทำ **ก่อน** assign เข้ากริด:

```swift
/// A box wider than 1.5 column steps almost certainly spans multiple cells.
/// Split it, then hand each fragment a proportional slice of the original
/// x-range so the grid assignment below still works.
```

| ชนิด | วิธีแยก |
|---|---|
| เวลา | regex `\d{1,2}[.:]\d{2}\s*[-–]\s*\d{1,2}[.:]\d{2}` — แต่ละ match = 1 ช่อง |
| ชื่อครู | split ที่ทุกตำแหน่งที่ขึ้นต้น `"ครู"` (ยกเว้นตัวแรก) |
| อื่นๆ | ไม่แยก → ติดธง `needsReview` |

ตำแหน่ง x ของชิ้นย่อย: แบ่งตามสัดส่วนจำนวนอักขระในข้อความเดิม

### 3.3 อ่าน 3 บรรทัดในหนึ่งช่อง

หลัง assign แล้ว ในแต่ละ cell เรียงกล่องตาม y จากมากไปน้อย:

```
บรรทัดที่ 1 → รหัสวิชา   (ตรวจด้วย SubjectCodeValidator)
บรรทัดที่ 2 → ชื่อครู     (ขึ้นต้น "ครู")
บรรทัดที่ 3 → ห้อง        (ตัวเลขล้วน 3 หลัก)
```

ถ้าไม่ตรงรูปแบบ → ใส่ลงตามลำดับที่มีแล้วติดธง

**ช่องพิเศษที่ไม่ใช่รหัสวิชา** — ต้องรับได้โดยไม่ติดธง: `โฮมรูม` `พัก` `ชุมนุม` `อบรมระดับ ม.5` `ที่ปรึกษา ม.5` `กิจกรรมในเครื่องแบบ`

### 3.4 แปลงคาบเป็นเวลา

`ScheduleDraftEntry` ต้องการ `startMinute`/`endMinute` ไม่ใช่เลขคาบ
→ หลังแยกกล่อง #19 แล้ว จะได้ `[คาบ: ช่วงเวลา]` ครบ ใช้ map ตรงๆ
→ คาบไหนไม่มีเวลา (คาบ 10 ในรูปนี้) ให้ **ข้าม** ไม่ใช่เดา

### 3.5 ขยาย `ScheduleDraftEntry`

```swift
struct ScheduleDraftEntry: Identifiable {
    let id = UUID()
    var dayOfWeek: Int
    var startMinute: Int
    var endMinute: Int
    var subjectName: String
    // ── เพิ่มใหม่ ทุกตัวมี default เพื่อไม่ให้ call site เดิมพัง ──
    var subjectCode: String = ""
    var teacherName: String = ""
    var room: String = ""
    var needsReview: Bool = false
    var reviewOptions: [String] = []   // ตัวเลือกให้ผู้ใช้กดเลือก ตอนกำกวม
}
```

⚠️ `ScheduleSetupView.saveAndContinue()` (บรรทัด ~206) วนสร้าง `Subject`/`ScheduleEntry` จาก draft
→ ต้องอ่านโค้ดตรงนั้นก่อนแก้ ว่าจะเอา `subjectCode`/`teacherName` ไปเก็บที่ไหน หรือยังไม่เก็บ
→ **ถ้าจะเพิ่ม property ใน `@Model Subject` ต้องเตือน Few ว่าต้องลบแอปออกจากเครื่องก่อนรันใหม่**

### 3.6 เกณฑ์ผ่านระยะ B

ยิงรูปเดิมแล้วต้องได้:

- `columnStep` ≈ 0.0693 · `columnCount` = 11
- `rowStep` ≈ −0.084 · `rowCount` = 5
- วิชาจริง **≥ 45 รายการ** (ตารางมี ~47 ช่องที่ไม่ใช่โฮมรูม/พัก)
- แถว **พุธ** ต้องมีข้อมูลครบ ทั้งที่ Vision อ่าน "พุธ" ไม่ออก ← ข้อพิสูจน์ว่าเลิกพึ่งชื่อวันสำเร็จ
- #13 (หัวเรื่อง) และ #140 (ลายเซ็น) ต้อง **ไม่** หลุดเข้าไปเป็นวิชา

---

## 4. ระยะ C — โหวต · ธง · UI แก้ไข

### 4.1 โหวตจากข้อมูลซ้ำในภาพ (ข้อ 8)

หลังได้กริดแล้ว จะรู้ว่ารหัสไหนซ้ำกันบ้าง:

```
รหัสที่ตัวแรกน่าสงสัย → หารหัสอื่นในภาพที่ "5 หลักท้ายตรงกัน" และ isValid
  เจอตัวเดียว   → ซ่อมด้วยตัวนั้น
  เจอหลายตัว    → ใช้ชื่อครูช่วยตัดสิน (ครูคนเดียวกัน = วิชาเดียวกัน)
  ยังไม่ชี้ขาด  → ติดธง
```

**ตรวจกับข้อมูลจริง:**

| ผิด | ท้าย 5 หลัก | ตัวที่ valid ในภาพ | ผล |
|---|---|---|---|
| `230243` | `30243` | `ว30243` (#23) | ✅ ซ่อม |
| `230203` | `30203` | `ว30203` (#57 #71) | ✅ ซ่อม |
| `230282` | `30282` | `ว30282` (#89) | ✅ ซ่อม |
| `232281` | `32281` | `ว32281` (#110) | ✅ ซ่อม |
| `032101` | `32101` | ค·ศ·ท·อ·ส32101 **5 ตัว** | ⚠️ ครูอนันต์ โผล่ครั้งเดียว ช่วยไม่ได้ → **ติดธง** |
| `032201` | `32201` | `อ32201` (#131) | ✅ ซ่อม |

→ โหวตแก้ได้ 5 จาก 6 · เหลือ `032101` ที่ต้องให้คนตัดสิน — **นี่คือพฤติกรรมที่ถูกต้อง ไม่ใช่ความล้มเหลว**

### 4.2 ระบบติดธง (ข้อ 10) — สำคัญที่สุดในระยะนี้

ใน `ScheduleSetupView` ช่องที่ `needsReview`:

- ขอบ / พื้นหลัง `Theme.Colors.warning`
- ไอคอน `exclamationmark.triangle.fill`
- แตะแล้วเปิด sheet เล็ก: ถ้ามี `reviewOptions` แสดงเป็นปุ่มให้เลือก (`ง32101` / `อ32101`) พร้อมช่องพิมพ์เอง
- แถบสรุปบนสุด: `"ตรวจแล้ว 47 ช่อง · ต้องยืนยัน 4 ช่อง"` + ปุ่ม "ไปช่องถัดไปที่ต้องดู"

### 4.3 เลิกคืน `[]` เงียบ (ข้อ 4)

`parseSchedule` เปลี่ยนเป็นคืน result ที่บอกเหตุผลได้:

```swift
enum ScheduleOCRResult {
    case success(entries: [ScheduleDraftEntry], flagged: Int)
    case noTextFound                      // Vision อ่านไม่ได้เลย
    case gridNotDetected(boxCount: Int)   // อ่านออกแต่หาโครงตารางไม่เจอ
    case notATimetable                    // ไม่เจอเลขคาบ/โฮมรูม/พัก เลย
}
```

ข้อความที่ผู้ใช้เห็น (ภาษาไทย ตามกฎโปรเจกต์):

| กรณี | ข้อความ |
|---|---|
| `noTextFound` | "อ่านตัวหนังสือในรูปไม่ได้เลย — ลองถ่ายใหม่ให้สว่างและชัดขึ้น" |
| `gridNotDetected` | "อ่านตัวหนังสือได้ N จุด แต่หาโครงตารางไม่เจอ — ลองถ่ายให้เห็นทั้งตารางและถือกล้องให้ตรง" |
| `notATimetable` | "ดูเหมือนไม่ใช่ตารางเรียน — ลองเลือกรูปใหม่ หรือกรอกเองก็ได้" |

ทุกกรณีต้องมีปุ่ม **"กรอกเอง"** เสมอ — ห้ามให้ผู้ใช้ตัน

---

## 5. สิ่งที่ห้ามทำตลอดแผนนี้

- ห้ามใช้ `VNRecognizedText.confidence` ตัดสินใจอะไรทั้งสิ้น (§0.2)
- ห้ามเพิ่ม SPM package / โมเดล ML ภายนอก — offline-first + ไม่มี dependency
- ห้ามใส่ `ท → 1` ลง `confusionMap` จนกว่าจะเจอในรูปจริง (§0.5)
- ห้ามเดาเวลาให้คาบที่ไม่มีข้อมูลเวลา
- ห้าม hardcode สี/ระยะ — ใช้ `Theme.*`
- ห้ามข้ามระยะ — จบระยะแล้ว build + ทดสอบ + commit ก่อนขึ้นระยะถัดไป

---

## 6. เอกสารที่ต้องอัปเดตตอนจบ

- `PROJECT_MAP.md` §2 — ไฟล์ใหม่ `SubjectCodeValidator.swift` · `ScheduleGridDetector.swift`
- `PROJECT_MAP.md` §8 — ตัด "OCR คืน [] เงียบ" ออกจากหนี้ทางเทคนิค เมื่อระยะ C จบ
- commit แยกตามระยะ: `feat: OCR ระยะ A — validator + candidate สำรอง` เป็นต้น

---

## 7. ข้อมูลทดสอบอ้างอิง

รูปตารางเรียน ม.5/9 โรงเรียนเมืองสุราษฎร์ธานี ภาคเรียน 1/2569

```
Vision อ่านได้            141 กล่อง
รหัสวิชาทั้งหมด            ~34 ตัว
รหัสวิชาที่อ่านผิด          11 ตัว (32%)
ช่องที่มีวิชาจริง           ~47 ช่อง (ไม่รวมโฮมรูม 5 + พัก 5)
parser เดิม parse ได้      14 รายการ (หัวตารางล้วน — วิชาจริง 0)
```

**เป้าหมายรวมเมื่อจบระยะ C:** วิชาจริง ≥ 45 · รหัสถูกอัตโนมัติ ≥ 32/34 · ที่เหลือติดธงให้ผู้ใช้ยืนยัน ไม่มีตัวไหนผิดแบบเงียบ
