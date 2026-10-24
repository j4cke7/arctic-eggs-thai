# ซ่อมเฉพาะตัวถอน Arctic Eggs 0.1.0

ใช้เฉพาะม็อดรุ่นเดิมที่ตรวจสอบ ownership ครบแล้ว ไม่ใช่ตัวถอนแบบ standalone และไม่ใช่การรองรับ Steam build ใหม่

- manifest เดิมต้องมี SHA-256 `d7fa3d3647681786add1cb5efc90effab513becfaa2cde822d4e64f2a9767302`
- Patch.ps1 เดิมต้องตรง SHA-256 `4988f27d1781adf33615f3a24a8a591cfa64f9e6706d74d09121543cb943e01e`
- Patch.ps1 ที่แก้แล้วมี SHA-256 `bf358c3499858fb1da221c53f998096bf3513f5abd96b0580c93a9751fcb0cd8`

[ดาวน์โหลด Patch ที่แก้แล้ว](https://github.com/j4cke7/arctic-eggs-thai/releases/download/v0.1.1-build18492481/Patch-v0.1.0-uninstall-fixed.ps1) · [SHA-256](https://github.com/j4cke7/arctic-eggs-thai/releases/download/v0.1.1-build18492481/Patch-v0.1.0-uninstall-fixed.ps1.sha256)

ปิดเกมก่อน ตรวจสมาชิกของโฟลเดอร์ `ArcticEggs-Thai-replace-en` ทุกไฟล์กับ ZIP 0.1.0 เดิม พร้อม manifest, install-state.json และ override.cfg ที่ผูกกับตำแหน่งติดตั้งเดิม หากมีไฟล์ไม่รู้จัก/ถูกแก้ หรือยืนยันชุดเดิมไม่ได้ ให้หยุดและแจ้งปัญหา อย่าเขียนทับเพื่อลองถอน

เมื่อยืนยันชุดเดิมครบแล้ว ให้เปลี่ยนเฉพาะ owned `Patch.ps1` ด้วยไฟล์ที่แก้แล้ว โดยใช้ชื่อ `Patch.ps1` และคง manifest/receipt เดิม จากนั้นเรียก `Uninstall.cmd` ภายในโฟลเดอร์ม็อดที่ติดตั้งไว้ ตัวถอนยังตรวจ ownership ของสมาชิกอื่นก่อนลบ ห้ามเปิดไฟล์ซ่อมจากโฟลเดอร์ Download ที่ไม่มี manifest หรือเอา Uninstall.cmd ของแพ็กคนละรุ่นมาใช้แทน

วิธีนี้ทดสอบในโฟลเดอร์จำลองที่เปลี่ยน build/EXE/PCK แล้ว และยืนยันไฟล์เกมใหม่ไม่เปลี่ยน ยังไม่ใช่การซ่อมเครื่องผู้เล่นโดยอัตโนมัติ ถ้าไม่แน่ใจให้เปิด Issue พร้อมข้อความผิดพลาด โดยไม่ส่งเซฟ/ข้อมูลส่วนตัว
