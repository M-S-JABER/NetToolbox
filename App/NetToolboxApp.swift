import SwiftUI
import NetToolboxKit

/// نقطة الدخول لهدف التطبيق المولَّد بـ XcodeGen — وهو الهدف الذي يُبنى
/// ويُوقَّع ويُرفع إلى TestFlight داخل GitHub Actions.
///
/// كل الشيفرة الفعلية في مكتبة `NetToolboxKit` في جذر المستودع، وهذا
/// الملف لا يفعل شيئاً سوى عرض `NetToolboxRootView()`.
///
/// يوجد ملف مطابق في `NetToolbox.swiftpm/NetToolboxApp.swift` مخصّص لـ
/// Swift Playgrounds على الآيباد. الفرق الجوهري بينهما:
///
///   - هذا الهدف يربط المكتبة **محلياً** عبر `packages: path: .` في
///     project.yml، فيبني دائماً الشيفرة الموجودة في المستودع الآن.
///   - نسخة `.swiftpm` تسحب المكتبة من وسم منشور على GitHub، لأن Swift
///     Playgrounds لا يتعامل مع الحزم المحلية.
///
/// لذلك: مسار النشر الرسمي هو هذا الهدف، ونسخة `.swiftpm` للتطوير على
/// الآيباد فقط.
@main
struct NetToolboxApp: App {
    var body: some Scene {
        WindowGroup {
            NetToolboxRootView()
        }
    }
}
