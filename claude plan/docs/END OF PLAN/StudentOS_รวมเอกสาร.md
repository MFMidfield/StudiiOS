# Student OS — เอกสารรวม (Project Scope + Business Model)

## วิสัยทัศน์ (Vision)

Offline-first operating system สำหรับชีวิตนักเรียนไทย
ครอบคลุมตั้งแต่การจัดการการเรียน การวางแผนอาชีพ ไปจนถึงการเตรียมเข้ามหาวิทยาลัย

## กลุ่มเป้าหมาย (Target Users)

- นักเรียนไทยระดับ ม.1–ม.6
- iPhone/iPad
- ใช้งานได้เต็มรูปแบบแบบ Offline

## หลักการออกแบบ (Core Principles)

- Offline-first
- Privacy-first
- Thai-first
- Zero setup
- Subject-centric

---

## โมดูลหลัก (Core Modules)

### Dashboard

- งานค้าง
- งานที่ต้องส่งวันนี้
- คาบถัดไป
- สอบที่กำลังจะมาถึง
- Semester Progress
- Productivity Summary

### Subject Hub

แต่ละวิชาประกอบด้วย
- Assignments
- Notes
- Flashcards
- PDFs
- Photos
- Formula Sheet
- Grades
- Exams

### Smart Capture

- Photo
- PDF
- Voice
- Note
- OCR (Vision Framework)
- สร้าง Assignment และจัดหมวดหมู่แบบออฟไลน์

### School Timeline

- ตารางเรียน
- ตารางสอบ
- กิจกรรม
- การบ้าน

### Focus Mode

- Pomodoro
- Focus Timer
- Reading Statistics

### Exam Mode

- Countdown
- Exam Planner
- Suggested Study Tasks

### Digital Binder

จัดเก็บตามรายวิชา
- รูป
- PDF
- ชีท
- การบ้าน
- โน้ต

---

## ฟีเจอร์เฉพาะสำหรับนักเรียนไทย ⭐ (Thai Student Features)

### Grade Center

- คำนวณคะแนนรวม
- คำนวณเกรด
- คำนวณคะแนนที่ต้องทำในกลางภาค/ปลายภาคเพื่อให้ได้เกรดเป้าหมาย
- รองรับระบบคะแนนของโรงเรียนไทย

### GPA Planner

- คำนวณ GPAX
- จำลองผลการเรียนในอนาคต
- วางแผนให้ถึง GPAX เป้าหมาย

### TCAS Planner

- บันทึกคณะและมหาวิทยาลัยที่สนใจ
- ติดตามความพร้อม
- เช็กลิสต์การเตรียมตัว
- Roadmap ม.4–ม.6

### Portfolio Hub

- เก็บเกียรติบัตร
- กิจกรรม
- จิตอาสา
- การแข่งขัน
- โปรเจกต์
- จัดหมวดหมู่สำหรับ Portfolio

### Career Discovery

- สำรวจความสนใจ
- แนะนำสายอาชีพ
- แนะนำคณะ
- แนะนำทักษะที่ควรเรียน
- สร้าง Learning Roadmap

### Thai School Schedule

รองรับ
- คาบเรียน
- หน้าเสาธง
- ชุมนุม
- ลูกเสือ
- แนะแนว
- กิจกรรมโรงเรียน

### Chapter-based Learning

- ผูกโน้ตกับบทเรียน
- Flashcards ตามบท
- รูปและชีทตามบท

---

## กฎอัจฉริยะ (Smart Rules)

- จัดลำดับความสำคัญงาน
- เตือน Deadline
- เตือนวิชาที่ไม่ได้ทบทวน
- เข้า Exam Mode อัตโนมัติ

## เทคโนโลยีที่ใช้ (Tech Stack)

- SwiftUI
- SwiftData
- Vision Framework
- PDFKit
- UserNotifications
- Swift Charts

## สิ่งที่ไม่รวมใน V1 (V1 Excludes)

- Login
- Cloud Sync
- Online AI
- Social
- Chat

## จุดเด่นที่แตกต่าง (Differentiation)

- ออกแบบตามระบบการศึกษาไทย
- Subject-centric
- Offline-first
- รวมทุกข้อมูลการเรียนไว้ในแอปเดียว
- ช่วยวางแผนตั้งแต่ ม.1 จนถึงเข้ามหาวิทยาลัย

---

# โมเดลธุรกิจ (Business Model Addendum)

## กลยุทธ์การสร้างรายได้ (Monetization Strategy)

### แนวคิดหลัก (Philosophy)

- ฟีเจอร์การเรียนรู้หลักจะฟรีเสมอ
- ฟีเจอร์ Offline-first ไม่ควรต้องสมัครสมาชิกเพื่อใช้งาน
- ฟีเจอร์ที่เสียเงินจะเน้นไปที่ Productivity ขั้นสูง, การปรับแต่งส่วนตัว และการทำรายงาน

### เวอร์ชันฟรี (Free Version)

- Dashboard
- Subject Hub
- Notes
- To-do
- Timeline
- Grade Calculator
- GPA Calculator
- Flashcards
- Focus Timer
- OCR (basic)
- Notifications

### Student OS Pro (แนะนำเป็นแบบซื้อครั้งเดียว)

**ฟีเจอร์พรีเมียม (Premium Features)**

- Advanced Analytics
- Grade / GPAX Simulation
- Study Insights
- Portfolio Builder
- PDF Report Export
- Extra Widgets
- Premium Themes
- Career Roadmap+
- Advanced Statistics

**ราคาแนะนำ:**
- Lifetime: 199–299 บาท

### Student OS+ (แบบสมัครสมาชิกเสริม)

เฉพาะสำหรับบริการที่มีต้นทุนต่อเนื่อง:
- Cloud Sync
- Automatic Backup
- Cross-device Sync
- ฟีเจอร์ AI ในอนาคต
- อัปเดตฟีเจอร์ก่อนใคร (Priority feature updates)

**ราคาแนะนำ:**
- Monthly: 29–49 บาท
- Yearly: 199–299 บาท

## เหตุผลของโมเดลนี้ (Why This Model)

- เป็นธรรมกับนักเรียน
- เหมาะกับผลิตภัณฑ์แบบ Offline-first
- ค่าสมัครสมาชิกผูกกับต้นทุนการดำเนินงานที่เกิดขึ้นจริงเท่านั้น
