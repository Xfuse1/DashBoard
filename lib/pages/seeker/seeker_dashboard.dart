import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../home_page.dart';
import 'seeker_edit.dart';
import '../payments/payments_page.dart';
import '../payments/credit_page.dart';

class SeekerDashboard extends StatelessWidget {
  const SeekerDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.secondary,
      appBar: AppBar(
          title: const Text('Job Seeker Dashboard'),
          backgroundColor: AppColors.accent),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Welcome, job seeker!',
                style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF333333))),
            const SizedBox(height: 12),
            const Text(
                'Here you can manage your profile, applications and CV.'),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.accent,
                  foregroundColor: Colors.white),
              onPressed: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const SeekerEditPage())),
              icon: const Icon(Icons.edit, color: Colors.white),
              label: const Text('Edit Profile'),
            ),
            const SizedBox(height: 8),
            ElevatedButton.icon(
              onPressed: () {},
              icon: const Icon(Icons.work_outline),
              label: const Text('My Applications'),
            ),
            const SizedBox(height: 8),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.accent,
                  foregroundColor: Colors.white),
              onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) =>
                          const PaymentsPage(title: 'Payments - Seeker'))),
              icon: const Icon(Icons.payment, color: Colors.white),
              label: const Text('Payments'),
            ),
            const SizedBox(height: 8),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.accent,
                  foregroundColor: Colors.white),
              onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) =>
                          const CreditPage(title: 'Credit - Seeker'))),
              icon:
                  const Icon(Icons.account_balance_wallet, color: Colors.white),
              label: const Text('Credit'),
            ),
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: () {
                // Navigate back to the app HomePage and clear navigation stack
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (_) => const HomePage()),
                  (route) => false,
                );
              },
              child: const Text('Back'),
            ),
          ],
        ),
      ),
    );
  }
}
