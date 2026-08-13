# دليل الإعداد — NetToolbox iOS

بناء ونشر التطبيق **بلا جهاز Mac**. كل ما يحتاج macOS يجري داخل runner على
GitHub Actions. أوامر جهازك بـ PowerShell، وهناك مسار كامل عبر المتصفح
للعمل من الآيباد.

---

## 1. بنية المشروع — نسختان لغرضين مختلفين

```
NetToolbox/
├── Sources/NetToolboxKit/     ← كل الشيفرة الفعلية (205 ملف)
├── App/                       ← نقطة دخول هدف XcodeGen  ◀ مسار النشر
│   ├── NetToolboxApp.swift
│   └── Info.plist
├── NetToolbox.swiftpm/        ← تطبيق Swift Playgrounds  ◀ التطوير على الآيباد
└── project.yml                ← مواصفة XcodeGen
```

| | `App/` عبر XcodeGen | `NetToolbox.swiftpm` |
|---|---|---|
| الغرض | **النشر الرسمي** إلى TestFlight | التطوير على الآيباد |
| مصدر المكتبة | **محلي** — `packages: path: .` | وسم منشور على GitHub |
| يبني آخر commit؟ | ✅ دائماً | ❌ يبني الوسم المنشور فقط |
| يُبنى في CI | ✅ | ❌ |

> **لماذا نسختان؟** Swift Playgrounds على الآيباد لا يتعامل مع الحزم
> المحلية، فتضطر نسخة `.swiftpm` لسحب المكتبة من وسم منشور. ذلك مقبول
> للتطوير، لكنه **غير مقبول للنشر**: كان الـ CI سابقاً يبني الوسم `1.73.0`
> متجاهلاً آخر تعديلاتك، أي أن TestFlight كانت ستستقبل نسخة ليست هي ما في
> المستودع. هدف XcodeGen يحل هذا نهائياً بالربط المحلي.

### لماذا تبقى المكتبة حزمة SPM ولا تُدمج ملفاتها في هدف التطبيق؟
لأن `NetToolboxKit` تعتمد على `Bundle.module` في ثلاثة مواضع جوهرية:
`Localization.swift` (كل نصوص الواجهة عربي/إنجليزي)، `OUIDatabase.swift`
(قاعدة `oui.json`)، و`ToolHelp.swift`. و`Bundle.module` رمز يولّده SwiftPM
للحزم فقط — دمج الملفات مباشرة كان سيُفقد كل النصوص المترجمة.

### الـ workflows الثلاثة

| Workflow | متى يعمل | يحتاج أسراراً؟ | الناتج |
|---|---|---|---|
| `ios-build` | كل push و PR | ❌ لا | اختبارات + `.ipa` غير موقّع |
| `ios-certificates` | يدوياً | ✅ نعم | توليد/تحقق الشهادات |
| `ios-release` | يدوياً أو وسم `v*` | ✅ نعم | رفع إلى TestFlight |

> **ابدأ الآن:** `ios-build` يعمل **فوراً** بلا حساب مطوّر ولا أسرار.
> Actions → ios-build → Run workflow، ثم نزّل الـ IPA من Artifacts وأعد
> توقيعه بـ AltStore لتجربته على جهازك.

---

## 2. القيم المعلّقة — من أين تُستخرج كل واحدة

### `TEAM_ID`
سلسلة من 10 محارف مثل `A1B2C3D4E5`.
> developer.apple.com → **Account** → **Membership details** → **Team ID**

### `APP_STORE_CONNECT_KEY_ID` و `APP_STORE_CONNECT_ISSUER_ID` و `APP_STORE_CONNECT_KEY_P8`
الثلاثة من مكان واحد:
> appstoreconnect.apple.com → **Users and Access** → **Integrations** → **App Store Connect API** → **Team Keys**

1. اضغط **+** لإنشاء مفتاح.
2. الاسم: `GitHub Actions CI`.
3. **الصلاحية: `Admin`.** لا تختر `Developer` — لن يستطيع توليد الشهادات ولا تسجيل التطبيق.
4. بعد الإنشاء:
   - **`KEY_ID`** = عمود Key ID (10 محارف)
   - **`ISSUER_ID`** = أعلى الجدول بصيغة UUID، مشترك لكل المفاتيح
   - **`KEY_P8`** = زر **Download API Key**. ⚠️ **التنزيل متاح مرة واحدة فقط.**

الصق **محتوى الـ `.p8` كاملاً** بما فيه سطرا `-----BEGIN PRIVATE KEY-----`
و`-----END PRIVATE KEY-----`. الـ Fastfile يكتشف الصيغة تلقائياً، فلا حاجة
لترميز base64 — مقصود ليسهل اللصق من الآيباد.

### `MATCH_PASSWORD`
عبارة تشفير مستودع الشهادات. **ليست** كلمة مرور Apple.
> ⚠️ يجب أن تكون **نفس العبارة** المستخدمة في WhatsX-iOS، لأن المستودعين
> يتشاركان مستودع `certificates` نفسه.

### `MATCH_GIT_TOKEN`
> github.com → Settings → Developer settings → Personal access tokens → **Tokens (classic)**

الصلاحية المطلوبة: **`repo`** فقط.

### `MATCH_GIT_URL` (اختياري)
`https://github.com/M-S-JABER/certificates`

---

## 3. إضافة الأسرار

### من الآيباد أو أي متصفح
> المستودع → **Settings** → **Secrets and variables** → **Actions** → **New repository secret**

### من PowerShell
```powershell
gh auth login    # مرة واحدة

Set-Location C:\Projects\NetToolbox

gh secret set TEAM_ID --body "A1B2C3D4E5"
gh secret set APP_STORE_CONNECT_KEY_ID --body "XXXXXXXXXX"
gh secret set APP_STORE_CONNECT_ISSUER_ID --body "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
gh secret set MATCH_PASSWORD --body "نفس-العبارة-المستخدمة-في-WhatsX"
gh secret set MATCH_GIT_TOKEN --body "ghp_xxxxxxxxxxxxxxxxxxxx"
gh secret set MATCH_GIT_URL --body "https://github.com/M-S-JABER/certificates"

gh secret set APP_STORE_CONNECT_KEY_P8 `
  --body (Get-Content "C:\Projects\keys\AuthKey_XXXXXXXXXX.p8" -Raw)

gh secret list
```

---

## 4. الترتيب الدقيق عند تفعيل الحساب

> **مهم:** إن كنت تجهّز المستودعين معاً، نفّذ خطوات WhatsX-iOS أولاً حتى
> الخطوة 5. الشهادة تُولَّد مرة واحدة وتُشارَك، فيكتفي NetToolbox بتوليد
> ملف تزويد لمعرّف حزمته فقط.

### الخطوة 0 — قبل التفعيل (الآن)
- [ ] شغّل `ios-build` وتأكد أن الوظيفتين خضراوان ✅
- [ ] نزّل الـ IPA غير الموقّع وجرّبه عبر AltStore

### الخطوة 1 — تأكيد التفعيل
اختفاء بانر `Purchase your membership` وظهور
**Certificates, Identifiers & Profiles** = الحساب مفعّل.

> ⚠️ لا تضغط `complete your purchase now` مهما طال الانتظار. الدفع تم
> ومؤكد؛ الأمر مزامنة بين نظام الاشتراكات والبوابة، ومدتها حتى 48 ساعة.

### الخطوة 2 — توقيع اتفاقية Free Apps
> appstoreconnect.apple.com → **Business** → اتفاقية **Free Apps** → وافق

كافية لنموذجك B2B. **لا توقّع Paid Apps Agreement** — هي وحدها التي تستلزم
حساباً بنكياً ونماذج ضريبية أمريكية.

### الخطوة 3 — مفتاح API بصلاحية `Admin`
### الخطوة 4 — إضافة الأسرار الستة

### الخطوة 5 — توليد الشهادات
> Actions → **ios-certificates** → Run workflow
> - `mode` = **`bootstrap`**
> - `confirm` = **`CREATE`**

ينفّذ داخل الرنر: تسجيل `net.alnokhba.nettoolbox` في البوابة، إنشاء سجل
التطبيق في App Store Connect، توليد ملف التزويد، وتشفيره في مستودع
`certificates`.

**لا تشغّل `bootstrap` مرة أخرى بعد نجاحه.**

### الخطوة 6 — التحقق
> Actions → **ios-certificates** → `mode` = **`verify`**

### الخطوة 7 — أول رفع إلى TestFlight
> Actions → **ios-release** → Run workflow

---

## 5. الاستخدام اليومي

```powershell
Set-Location C:\Projects\NetToolbox

# إصدار إلى TestFlight
gh workflow run ios-release.yml -f changelog="إضافة أداة BGP"
gh run watch

# أو عبر وسم
git tag v2.3.3
git push origin v2.3.3
```

رفع رقم النسخة: عدّل `MARKETING_VERSION` في `project.yml`. رقم البناء
يُضبط آلياً برقم تشغيل الـ workflow.

> **تنبيه:** عند تعديل `MARKETING_VERSION` في `project.yml`، عدّل
> `displayVersion` في `NetToolbox.swiftpm/Package.swift` أيضاً ليبقيا
> متطابقين.

---

## 6. الصلاحيات و App Transfer

التطبيق **خالٍ تماماً من أي entitlement**. كل ما يطلبه أوصاف استخدام في
`Info.plist` تُعرض عند أول استخدام للميزة لا عند الإقلاع:

| المفتاح | الميزة |
|---|---|
| `NSLocalNetworkUsageDescription` + `NSBonjourServices` | فحص الشبكة، Bonjour، كاميرات IP |
| `NSFaceIDUsageDescription` | قفل التطبيق |
| `NSCameraUsageDescription` | مسح رموز QR |
| `NSPhotoLibraryAddUsageDescription` | حفظ اللقطات |

**لا Network Extension، لا Apple Pay، لا Wallet، لا Sign in with Apple،
لا Push Notifications.** هذا مقصود ليبقى **App Transfer** إلى حساب
"مختبرات النخبة" ممكناً بلا عوائق بعد استخراج رقم D-U-N-S.

### قراران مؤجّلان يخصّانك

**1. مزامنة iCloud.** `Core/System/CloudSync.swift` يستخدم
`NSUbiquitousKeyValueStore` لمزامنة الإعدادات غير السرّية. هذه تحتاج
entitlement `com.apple.developer.ubiquity-kvstore-identifier` **لم أضفها
عمداً**، لأنها ترتبط بحاوية iCloud خاصة بالفريق وتُعقّد App Transfer.
بدونها تفشل المزامنة بصمت ولا ينهار التطبيق، والميزة أصلاً اختيارية بمفتاح
في الإعدادات. أضفها لاحقاً إن قررت أن المزامنة أهم من سهولة النقل.

**2. اكتشاف SSDP/UPnP.** `Features/SSDP/SSDP.swift` يحتاج entitlement
`com.apple.developer.networking.multicast`، وهي تتطلب **طلب استثناء يدوياً
من Apple بمبرر مكتوب**. الشيفرة واعية بذلك وتُعيد قائمة فارغة عند غيابها،
فلا شيء ينكسر. هذه الـ entitlement أيضاً تُعقّد النقل، فأنصح بتأجيلها إلى
ما بعد النقل إلى حساب المؤسسة.

---

## 7. حل المشاكل

| العطل | السبب والحل |
|---|---|
| `أسرار ناقصة: ...` | لم تُضف الأسرار. راجع القسم 3. |
| `Your account does not have permission` | مفتاح API بصلاحية `Developer`. أنشئ مفتاحاً بصلاحية `Admin`. |
| `The request expects other terms to be agreed` | اتفاقية Free Apps غير موقّعة. راجع الخطوة 2. |
| `Could not decrypt` في match | `MATCH_PASSWORD` لا تطابق المستخدمة في WhatsX. يجب أن تتطابقا. |
| `Authentication failed` لمستودع الشهادات | `MATCH_GIT_TOKEN` منتهٍ أو بلا صلاحية `repo`. |
| فشل حلّ الحزمة في `xcodegen` | تأكد أن `Package.swift` في الجذر سليم — هدف التطبيق يعتمد عليه محلياً. |
| `scheme NetToolboxKit not found` | تشغّل الاختبارات بعد توليد `.xcodeproj`. يجب أن تسبقه — راجع القسم 8. |
| `bundle version must be higher` | رقم بناء مكرر. أعد التشغيل. |

---

## 8. مصيدة تقنية تستحق الانتباه

`xcodebuild` يكتشف تلقائياً ما يبنيه في المجلد الحالي. ما إن يوجد
`NetToolbox.xcodeproj` في الجذر حتى يفضّله على `Package.swift`، فتفشل
مخططات الحزمة مثل `NetToolboxKit`.

لذلك يفصل `ios-build.yml` الاختبارات في **وظيفة مستقلة لا تشغّل
`xcodegen` إطلاقاً**. إن أضفت خطوات اختبار لاحقاً، احرص أن تعمل قبل
التوليد أو في وظيفة منفصلة.

---

## 9. العمل من الآيباد

افتح `NetToolbox.swiftpm` في **Swift Playgrounds**. سيسحب `NetToolboxKit`
من آخر وسم منشور. بعد تعديلاتك:

1. ادفع التغييرات إلى المستودع
2. شغّل **Tag release** من تبويب Actions لإنشاء وسم جديد
3. حدّث رقم الوسم في `NetToolbox.swiftpm/Package.swift`

أما البناء والنشر فيُداران بالكامل من تبويب **Actions** في المتصفح — لا
تحتاج أي أداة سطر أوامر على الآيباد.
