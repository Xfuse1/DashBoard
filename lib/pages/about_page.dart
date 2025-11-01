import 'package:flutter/material.dart';

class AboutPage extends StatelessWidget {
  const AboutPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('نبذة عنا'),
          backgroundColor: Theme.of(context).colorScheme.primary,
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Logo row (simple text logo; replace with image if available)
              Row(
                mainAxisAlignment: MainAxisAlignment.start,
                children: const [
                  SizedBox(width: 8),
                  Text('CVEEEZ',
                      style:
                          TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                ],
              ),
              const SizedBox(height: 18),
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: Theme.of(context)
                          .colorScheme
                          .primary
                          .withValues(alpha: 0.2)),
                  color: Theme.of(context).colorScheme.surface,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: const [
                    Text(
                      'لكل طموح قصة.. ونحن نرويها باحتراف',
                      style:
                          TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    SizedBox(height: 12),
                    Text(
                      'CVEEEZ هو شريكك المهني لصناعة هوية احترافية تفتح لك أبواب الفرص. نحن متخصصون في كتابة السير الذاتية بتنسيقات عالمية متنوعة (ATS, Europass, Canadian, Standard) للباحثين عن عمل داخل مصر وخارجها. مهمتنا هي إبراز مهاراتك وشغفك لجعلك الخيار الأمثل لدى كبرى الشركات. نعمل على تحويل طموحك إلى واقع ملموس وهوية مهنية لا تُنسى.',
                      style: TextStyle(fontSize: 16, height: 1.6),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              // Callout box
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(28),
                  border:
                      Border.all(color: Theme.of(context).colorScheme.primary),
                  color: Theme.of(context)
                      .colorScheme
                      .primary
                      .withValues(alpha: 0.04),
                ),
                child: const Text(
                  'استثمر في طموحك اليوم، ودعنا نصنع لك هوية مهنية لا تهزم.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                ),
              ),
              const SizedBox(height: 24),
              // Optional additional details
              const Text('خدماتنا:',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              const Text(
                  '- كتابة سير ذاتية احترافية متوافقة مع أنظمة ATS\n- تصميم ملفات تعريف LinkedIn احترافية\n- خدمات توظيف لأصحاب العمل',
                  style: TextStyle(height: 1.6)),
            ],
          ),
        ),
      ),
    );
  }
}
