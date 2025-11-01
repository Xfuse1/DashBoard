import 'package:flutter/material.dart';

class ServicesPage extends StatelessWidget {
  const ServicesPage({super.key});

  final List<Map<String, String>> _services = const [
    {
      "title": "CV ATS",
      "desc": "تصميم سيرة ذاتية متوافقة مع أنظمة الفرز الآلي للشركات."
    },
    {
      "title": "CV Standard",
      "desc": "سير ذاتية بتنسيق بسيط وجذاب مع ألوان تجذب الانتباه."
    },
    {
      "title": "CV Europass",
      "desc": "تنسيق مخصص للوظائف الأوروبية وفق معايير Europass."
    },
    {
      "title": "CV Canadian",
      "desc": "تصميم سيرة ذاتية متوافقة مع معايير الوظائف في كندا."
    },
    {
      "title": "CV Bilingual",
      "desc": "تصميم سيرة ذاتية مزدوجة اللغة بتنسيق منظم وواضح."
    },
    {
      "title": "Customized Offers",
      "desc": "باقات شاملة وعروض حصرية ومتكاملة حسب احتياجاتك."
    },
    {
      "title": "Cover Letter",
      "desc": "كتابة خطاب تقديم احترافي يعكس مهاراتك وطموحاتك."
    },
    {
      "title": "Online Card",
      "desc": "بطاقة تعريفية إلكترونية يمكن مشاركتها بسهولة."
    },
    {"title": "Portfolio", "desc": "تصميم محفظة مهنية تبرز مهاراتك ومشاريعك."},
    {
      "title": "Professional LinkedIn",
      "desc": "تحسين ملفاتك الشخصية على لينكدإن لتكون أكثر احترافية."
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('خدماتنا'),
          backgroundColor: Theme.of(context).colorScheme.primary,
        ),
        body: Padding(
          padding: const EdgeInsets.all(16.0),
          child: GridView.builder(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              childAspectRatio: 1.0,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
            ),
            itemCount: _services.length,
            itemBuilder: (context, index) {
              final s = _services[index];
              return Card(
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(
                        color: Theme.of(context)
                            .colorScheme
                            .primary
                            .withValues(alpha: 0.2))),
                elevation: 2,
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Theme.of(context)
                              .colorScheme
                              .primary
                              .withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          s['title'] ?? '',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                              fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Expanded(
                        child: Text(
                          s['desc'] ?? '',
                          style: const TextStyle(fontSize: 14, height: 1.6),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
