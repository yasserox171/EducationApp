# عقد الـ API المتوقَّع

هذا ما ينتظره التطبيق من الخادم. **إن كان الباك-اند يستعمل أسماء حقول
مختلفة، عدّل هذا الملف وأخبرني** — التعديل في التطبيق يكون في
`lib/data/models/` و`lib/core/network/api_endpoints.dart` فقط.

- كل المسارات تُضاف إلى `BASE_URL` (مثال: `BASE_URL=https://api.example.com/v1`).
- المصادقة: `Authorization: Bearer <token>` في كل طلب عدا `/auth/login`.
- التطبيق يقبل الرد بشكلين: `{...}` مباشرة أو ملفوفًا في `{"data": {...}}`.
- التواريخ بصيغة ISO-8601 بتوقيت UTC (`2026-09-06T12:30:00Z`).
- الأخطاء: `{"message": "نص عربي للعرض", "errors": {"email": ["..."]}}`.

---

## المصادقة

### `POST /auth/login`
```json
// الطلب
{ "email": "eleve@example.com", "password": "······" }

// الرد 200
{
  "token": "eyJhbGciOi...",
  "user": {
    "id": "42",
    "full_name": "أحمد بن علي",
    "email": "eleve@example.com",
    "role": "student"          // "student" | "teacher"
  }
}
```
`401` = بيانات خاطئة. لا يوجد تسجيل ذاتي: حسابات التلاميذ يُنشئها الأستاذ.

### `GET /auth/me` → نفس كائن `user`.
### `POST /auth/logout` → `204`. (فشلها لا يمنع الخروج المحلي.)

**انتهاء الجلسة:** أي رد `401` من أي مسار يعني للتطبيق أن الرمز انتهى، فيُخرج
المستخدم. لا يوجد refresh token في هذه النسخة — استعمل مدة صلاحية طويلة
(30 يومًا مثلًا) لأن التلاميذ يستعملون التطبيق أوفلاين لفترات.

---

## المحتوى (قراءة — للطرفين)

### `GET /subjects`
```json
[
  {
    "id": "1",
    "title": "الرياضيات",
    "description": "…",
    "position": 0,
    "lessons_count": 12,
    "updated_at": "2026-09-01T10:00:00Z"
  }
]
```

### `GET /subjects/{id}/lessons?level=middle`
`level` اختياري، وقيمه الطور الدراسي: `middle` = متوسط، `secondary` = ثانوي.
التطبيق يسحب كل الأطوار ويفلتر محليًا ليتمكّن التلميذ من تغيير طوره بلا اتصال.
```json
[
  {
    "id": "10",
    "subject_id": "1",
    "title": "المعادلات من الدرجة الثانية",
    "summary": "…",
    "level": "middle",
    "position": 0,
    "blocks_count": 7,
    "is_published": true,
    "updated_at": "2026-09-02T09:00:00Z"
  }
]
```
للتلميذ: أعِد الدروس المنشورة فقط. للأستاذ: أعِدها كلها.

### `GET /lessons/{id}/blocks`
الفقرات مرتّبة بـ `position`. الحقل `data` يختلف حسب `type`:
```json
[
  {
    "id": "100", "lesson_id": "10", "position": 0, "type": "text",
    "data": { "heading": "مقدمة", "body": "نص الفقرة…" }
  },
  {
    "id": "101", "lesson_id": "10", "position": 1, "type": "video",
    "data": {
      "title": "شرح مرئي",
      "url": "https://cdn.example.com/videos/abc.mp4",
      "thumbnail_url": "https://cdn.example.com/thumbs/abc.jpg",
      "duration_seconds": 420,
      "size_bytes": 48234123,
      "attachments": [
        {
          "id": "7",
          "file_name": "ملخص الدرس.pdf",
          "url": "https://cdn.example.com/files/summary.pdf",
          "file_size": 384219,
          "created_at": "2026-09-02T09:00:00Z"
        }
      ]
    }
  },
  {
    "id": "102", "lesson_id": "10", "position": 2, "type": "quiz",
    "data": {
      "questions": [
        {
          "id": "q1",
          "question": "ما هو حل المعادلة؟",
          "options": [
            { "id": "a", "text": "٢" },
            { "id": "b", "text": "٣" }
          ],
          "correct_option_id": "b",
          "explanation": "لأن…"
        },
        {
          "id": "q2",
          "question": "سؤال آخر في نفس الفقرة",
          "options": [
            { "id": "a", "text": "نعم" },
            { "id": "b", "text": "لا" }
          ],
          "correct_option_id": "a"
        }
      ]
    }
  }
]
```

> **فقرة الكويز تحمل عدة أسئلة.** التطبيق يقبل أيضًا الشكل القديم
> (`question` و`options` و`correct_option_id` في جذر `data`) ويقرأه كسؤال
> واحد معرّفه هو معرّف الفقرة، فلا تنكسر البيانات القائمة. الأسئلة الجديدة
> تحتاج `id` ثابتًا داخل الفقرة (`q1`, `q2`…) لأن محاولات التلاميذ تُربط به.

> **`attachments`** ملفات PDF مرفقة بفقرة الفيديو. `file_size` مهم: يُستعمل
> لحساب المساحة قبل تحميل الدرس. الروابط تُطلب مباشرة عند التحميل، ويُفضَّل
> دعم `Range` فيها كما في الفيديو.

> **مهم لعمل الكويز أوفلاين:** `correct_option_id` يجب أن يصل مع الفقرة،
> لأن التصحيح فوري على الجهاز حتى بدون إنترنت. إن كان إخفاؤه مطلوبًا
> لاعتبارات الغش، أخبرني — البديل هو تصحيح على الخادم يعطّل الكويز أوفلاين.

> `size_bytes` مهم أيضًا: التطبيق يستعمله لحساب المساحة المطلوبة وعرض شريط
> تقدم دقيق قبل بدء التحميل.

**تحميل ملفات الفيديو:** التطبيق يطلب `url` مباشرة بترويسة `Range` لدعم
الاستئناف. يُفضَّل أن يدعم الخادم/الـ CDN طلبات `206 Partial Content`، وأن
يعمل الرابط بترويسة `Authorization` أو أن يكون رابطًا موقّعًا طويل الأمد.

---

## المحتوى (كتابة — الأستاذ فقط)

| المسار | الوصف |
|---|---|
| `POST /subjects` | `{title, description}` → المادة المُنشأة |
| `PUT /subjects/{id}` | `{title, description}` |
| `DELETE /subjects/{id}` | `204` |
| `POST /lessons` | `{subject_id, title, level, summary}` |
| `PUT /lessons/{id}` | `{title?, level?, summary?, is_published?}` |
| `DELETE /lessons/{id}` | `204` |
| `POST /subjects/{id}/lessons/reorder` | `{"lesson_ids": ["10","12","11"]}` |
| `POST /lessons/{id}/blocks` | `{type, data, position?}` → الفقرة المُنشأة |
| `PUT /blocks/{id}` | `{data}` |
| `DELETE /blocks/{id}` | `204` |
| `POST /lessons/{id}/blocks/reorder` | `{"block_ids": ["100","102","101"]}` |

### `POST /uploads/video`
`multipart/form-data` بحقل `file`. التطبيق يعرض شريط تقدم من
`onSendProgress` ويسمح بالإلغاء.
```json
{
  "url": "https://cdn.example.com/videos/abc.mp4",
  "thumbnail_url": "https://cdn.example.com/thumbs/abc.jpg",
  "duration_seconds": 420,
  "size_bytes": 48234123
}
```
التطبيق يرفض محليًا أي ملف أكبر من `MAX_VIDEO_UPLOAD_MB` (300 م.ب افتراضيًا)
قبل بدء الرفع. تأكّد أن حدّ الخادم (`client_max_body_size`) لا يقلّ عن ذلك.

### `POST /blocks/{blockId}/attachments`

رفع ملف PDF مرفق بفقرة فيديو، `multipart/form-data` بحقل `file`.

```json
{
  "id": "7",
  "file_name": "ملخص الدرس.pdf",
  "url": "https://cdn.example.com/files/summary.pdf",
  "file_size": 384219,
  "created_at": "2026-09-02T09:00:00Z"
}
```

**تحقّقات مطلوبة على الخادم:** أن يكون الملف PDF فعلًا (لا بالامتداد وحده
بل بفحص التوقيع `%PDF-`)، وألا يتجاوز `MAX_ATTACHMENT_MB` (٢٠ م.ب افتراضيًا).
التطبيق يتحقّق من الامتداد والحجم قبل الرفع، لكن هذا لا يغني عن تحقّق الخادم.

### `DELETE /attachments/{id}` → `204`

يحذف الملف من التخزين. إزالة المرفق من الفقرة تتم عبر
`PUT /blocks/{id}` بقائمة `attachments` الجديدة.

### جدول قاعدة البيانات المقترح

```sql
CREATE TABLE lesson_block_attachments (
  id              BIGSERIAL PRIMARY KEY,
  lesson_block_id BIGINT NOT NULL REFERENCES lesson_blocks(id) ON DELETE CASCADE,
  file_name       TEXT NOT NULL,
  file_path       TEXT NOT NULL,
  file_size       BIGINT NOT NULL DEFAULT 0,
  created_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_attachments_block ON lesson_block_attachments (lesson_block_id);
```

علاقة واحد-لعدة: فقرة الفيديو الواحدة تحمل عدة ملفات. `ON DELETE CASCADE`
يضمن اختفاء المرفقات مع حذف الفقرة. عند بناء رد `GET /lessons/{id}/blocks`
تُسقَط صفوف هذا الجدول داخل `data.attachments` كما في المثال أعلاه، مع
تحويل `file_path` إلى رابط `url` قابل للتنزيل.

---

## التقدّم والمزامنة (التلميذ)

### `GET /me/progress`
```json
[
  {
    "lesson_id": "10", "subject_id": "1",
    "status": "in_progress",        // not_started | in_progress | completed
    "last_block_index": 3, "blocks_total": 7,
    "completed_at": null,
    "updated_at": "2026-09-05T14:20:00Z"
  }
]
```

### `POST /me/progress/sync`
جسم الطلب هو نفس كائن التقدّم أعلاه. **يجب أن تكون العملية idempotent**:
قد يُعاد الإرسال بعد انقطاع. القاعدة المقترحة على الخادم: تجاهل الطلب إن
كان `updated_at` المخزَّن أحدث من الوارد.

### `POST /me/quiz-attempts`
```json
{
  "id": "8f3c…",                 // UUID مولَّد على الجهاز = مفتاح idempotency
  "block_id": "102",
  "lesson_id": "10",
  "selected_option_id": "b",
  "is_correct": true,
  "answered_at": "2026-09-05T14:22:00Z"
}
```
إن وصل `id` مكرّر أعِد `200` دون تسجيل محاولة ثانية.

### `GET /me/levels` و `PUT /me/levels/{subjectId}`
```json
// GET → قائمة
[{ "subject_id": "1", "level": "secondary", "updated_at": "…" }]

// PUT → { "level": "secondary" }
```

> ملاحظة: مسارات `/me/*` تخصّ التلميذ. للأستاذ يكفي أن يردّ الخادم `403`
> أو `404` — التطبيق يتجاهلها بهدوء في دورة المزامنة.

---

## إحصائيات الأستاذ

### `GET /teacher/stats`
```json
{
  "students_count": 37,
  "subjects_count": 4,
  "lessons_count": 26,
  "average_quiz_score": 0.72,        // من 0.0 إلى 1.0
  "lessons": [
    {
      "lesson_id": "10",
      "lesson_title": "المعادلات",
      "subject_title": "الرياضيات",
      "completion_rate": 0.45,        // من 0.0 إلى 1.0
      "average_quiz_score": 0.68,
      "students_started": 20,
      "students_completed": 9
    }
  ]
}
```
