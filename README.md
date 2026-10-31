<a href="https://store.steampowered.com/app/2763670/Arctic_Eggs/"><img src="https://shared.akamai.steamstatic.com/store_item_assets/steam/apps/2763670/library_hero.jpg" alt="Arctic Eggs บน Steam" width="100%"></a>

<h1 align="center">Arctic Eggs ภาษาไทย | Thai Mod</h1>

<p align="center">ม็อดแปลไทยจากแฟนเกม ใช้แทนภาษา English ในเกม ภาษาอื่นยังเลือกได้<br>
<sub>Fan-made Thai translation mod for Arctic Eggs on Steam (Windows). It replaces the English language slot.</sub></p>

<h2 align="center"><a href="https://github.com/j4cke7/arctic-eggs-thai/releases/download/v1.0.1-build18492481/Arctic-Eggs-Thai-replace-en-build18492481.zip">⬇️ ดาวน์โหลดม็อด (.zip, 272 KiB)</a></h2>

<p align="center">
<b>รุ่น 1.0.1</b> · อัปเดต 28 ต.ค. 2569 · ใช้กับ Steam (Windows) build 18492481<br>
<sub>ใช้ลิงก์นี้เท่านั้น ปุ่ม Code สีเขียวของ GitHub ไม่ใช่ไฟล์ม็อด</sub>
</p>

<p align="center">
<a href="#ติดตั้ง">วิธีติดตั้ง</a> · <a href="https://github.com/j4cke7/arctic-eggs-thai/releases/tag/v1.0.1-build18492481">มีอะไรใหม่</a> · <a href="https://store.steampowered.com/app/2763670/Arctic_Eggs/">หน้าเกมบน Steam</a> · <a href="https://github.com/j4cke7/arctic-eggs-thai/issues">แจ้งปัญหา</a> · <a href="https://github.com/j4cke7">ม็อดเกมอื่น</a>
</p>

## ติดตั้ง

1. ปิดเกม แล้วแตกไฟล์ ZIP ทั้งหมดไว้ที่ไหนก็ได้ อย่าเปิด `Install.cmd` จากในไฟล์ ZIP โดยตรง
2. ดับเบิลคลิก `Install.cmd` แล้วรอจนขึ้นว่าเสร็จ ถ้าตัวติดตั้งหาเกมไม่เจอ จะเปิดหน้าต่างให้เลือกโฟลเดอร์เกม
3. เปิดเกมจาก Steam ตามปกติ แล้วเลือกภาษา **English** ข้อความที่แปลไว้จะแสดงเป็นไทย

## ถอนม็อด

ปิดเกม แล้วดับเบิลคลิก `Uninstall.cmd` ในโฟลเดอร์ที่แตกไว้ จึงควรเก็บโฟลเดอร์นี้ไว้

<details>
<summary><b>อัปเดตจากรุ่นก่อน</b></summary>

ปิดเกม แล้วใช้ `Uninstall.cmd` จากโฟลเดอร์ที่ใช้ติดตั้งรุ่นเดิมถอนม็อดก่อน จากนั้นติดตั้งรุ่นนี้ตามขั้นตอนด้านบน ตัวติดตั้งจะไม่เขียนทับม็อดคนละรุ่น

</details>

<details>
<summary><b>เคยติดตั้งรุ่น 0.1.0</b></summary>

ถอนด้วย ZIP รุ่น 0.1.0 เดิมก่อน แล้วจึงติดตั้งรุ่นนี้ หาก Steam อัปเดตจนตัวถอน 0.1.0 หยุด ให้ใช้ [วิธีซ่อมตัวถอนรุ่นเดิม](repair-v0.1.0/README-th.md)

</details>

<details>
<summary><b>ขอบเขตของรุ่นนี้</b></summary>

ใช้บทแปลชุดที่ตรวจแล้วและฟอนต์ Sarabun บทสนทนาคงลูกเล่นขึ้นทีละตัวอักษรเดิม บางข้อความยังอาจเป็นภาษาอังกฤษ ข้อความที่ยังยืนยันต้นฉบับหรือจุดแสดงผลไม่ได้ยังไม่ถูกเดาเติม รุ่นนี้ยังไม่ได้รับรองว่าทุกฉากและทุกขนาดหน้าจอผ่านการเล่นครบแล้ว

</details>

<details>
<summary><b>ติดตั้งไม่ได้?</b></summary>

- Windows ขึ้นหน้าต่างเตือนตอนเปิด `Install.cmd`: กด **More info** แล้ว **Run anyway** ตัวติดตั้งเป็นสคริปต์ที่อ่านได้ในหัวข้อตรวจไฟล์ด้านล่าง
- ม็อดนี้ทำมาสำหรับเกมบน Steam (Windows) เท่านั้น
- รองรับเฉพาะ build ที่ระบุในหน้านี้ หากเกมอัปเดตเป็นรุ่นอื่น ให้รอแพ็กที่รองรับ
- หากมี `override.cfg` หรือไฟล์ของม็อดอื่นที่ชนกัน ตัวติดตั้งจะหยุดพร้อมระบุสาเหตุ ให้เก็บไฟล์เดิมไว้ ไม่ต้องลบทิ้งเพื่อบังคับติดตั้ง
- หากการติดตั้งถูกขัดจังหวะ ให้ปิดเกมแล้วเรียก `Install.cmd` อีกครั้ง
- หากต้องย้ายโฟลเดอร์เกม ให้ถอนม็อดก่อน แล้วติดตั้งใหม่หลังย้ายเสร็จ
- ยังไม่หาย: [แจ้งปัญหา](https://github.com/j4cke7/arctic-eggs-thai/issues)

</details>

<details>
<summary><b>ตรวจไฟล์และสัญญาอนุญาต</b></summary>

- ตัวติดตั้งเป็นสคริปต์ PowerShell ที่อ่านได้: [Patch.ps1](source/Patch.ps1)
- SHA-256 ของ ZIP: `2a9217f5f4224120aa6815b28452ee53a628426c0444f0b836e7b094d8bde089`
- [สัญญาอนุญาตฟอนต์](licenses/): Sarabun ใช้ SIL OFL

</details>

---

<p align="center"><a href="https://github.com/j4cke7"><b>ดูม็อดภาษาไทยของเกมอื่น</b></a></p>

<p align="center"><sub>ม็อดนี้เป็นงานแปลโดยแฟนเกม ไม่มีส่วนเกี่ยวข้องกับผู้พัฒนาหรือผู้จัดจำหน่าย Arctic Eggs</sub></p>
