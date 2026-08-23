# مشروع AI Studio - ملف التسليم للانتقال إلى Ubuntu (Handoff Document)

## 📌 السياق والهدف
هذا الملف يحتوي على الذاكرة المعمارية وملخص الإنجازات التي قمنا بها في نظام Windows. الهدف هو تزويد "المستشار البرمجي" في المحادثة الجديدة (على نظام Ubuntu) بكامل السياق ليكمل العمل دون فقدان أي بيانات.

---

## 🏗️ المعمارية الحالية (Architecture Overview)
لقد قمنا بتحويل المشروع إلى بيئة **مفتوحة المصدر وقابلة للتوسع (Plug-and-Play)** تعتمد على الإضافات (Plugins) بدلاً من الكود الصلب الثابت.

1. **نظام الإضافات (`IPlugin`, `PluginContext`, `PluginManager`)**:
   - كل خدمة جديدة يتم تغليفها كإضافة لتُسجل نفسها في النواة دون الحاجة لتعديل `Bootstrap`.
2. **سجل خط الإنتاج (`PipelineRegistry` & `PipelineStage`)**:
   - كل مرحلة في توليد الفيديو تمتلك أولوية `priority` تحدد ترتيب تنفيذها تلقائياً. (القصة 10، الشخصيات 20، الصور 40... الصوت 60، الفيديو 70).
3. **مزودو الخدمات (`ProviderRegistry`)**:
   - يتم سحب المزودين باستخدام النوع `Type` مثل `context.providers.getDefault<TTSProvider>()`.
4. **كائن المشروع (`NoemaProject`)**:
   - يخزن القصة، الشخصيات، الصور المولدة (`GeneratedImage`)، الأصوات المولدة (`GeneratedAudio`)، ومسار الفيديو النهائي (`finalVideoPath`).

---

## ✅ ما تم إنجازه مؤخراً
1. **TTS (تحويل النص إلى صوت)**:
   - استخدمنا حزمة `flutter_tts` في ملف `flutter_tts_provider.dart`.
   - أضفنا `SceneAudioStage` لتوليد الأصوات وحفظها في المسار `C:\AI_Studio\output\audio\`.
2. **FFmpeg (تجميع الفيديو)**:
   - تم بناء `FFmpegVideoCompilerProvider` يستخدم `Process.run('C:\\AI_Studio\\bin\\ffmpeg.exe', [...])` لدمج الصور والأصوات في `mp4`.
   - أضفنا `VideoCompilationStage` كخطوة أخيرة في הـ Pipeline.
3. **الإضافات المستخدمة في `main.dart`**:
   - `OllamaPlugin`, `ComfyUIPlugin`, `FlutterTTSPlugin`, `FFmpegPlugin`, `CorePipelinePlugin`.

---

## 🚀 مهام "المستشار البرمجي" القادمة (أوامر للإكمال على Ubuntu)

أيها المستشار البرمجي في المحادثة الجديدة، نحن الآن نعمل على بيئة **Ubuntu Linux**. لقد قام المستخدم بنسخ هذا المشروع من بيئة Windows، وبالتالي هناك مسارات (Paths) صلبة يجب عليك إصلاحها فوراً لتعمل على Linux:

1. **تعديل `FlutterTTSProvider`**:
   - افتح `lib/infrastructure/tts/flutter_tts_provider.dart`.
   - استبدل المسار الثابت `C:\AI_Studio\output\audio` بمسار نسبي متوافق مع Linux باستخدام `Directory.current.path`.

2. **تعديل `FFmpegVideoCompilerProvider`**:
   - افتح `lib/infrastructure/ffmpeg/ffmpeg_video_compiler.dart`.
   - قم بتغيير مسار أداة FFmpeg من `C:\AI_Studio\bin\ffmpeg.exe` ليصبح ببساطة استدعاء للأمر `ffmpeg` الموجود ضمن مسار النظام (System PATH) في Linux.

3. **التحقق من تثبيت FFmpeg**:
   - تأكد أن المستخدم قام بتنفيذ `sudo apt install ffmpeg` في نظام Ubuntu الخاص به.

4. **تجربة التطبيق (End-to-End)**:
   - قم بتشغيل `flutter pub get` (يجب ألا تظهر أخطاء الـ Symlink التي كانت تظهر على Windows).
   - تأكد من أن الـ Pipeline يعمل كاملاً ويقوم بتوليد الفيديو والصوت بنجاح داخل بيئة Linux.

---
**نهاية الرسالة. يمكنك الآن يا صديقي إكمال رحلة الإبداع في هذا الستوديو المذهل! 🤖✨**
