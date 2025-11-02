import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../home_page.dart';
import 'employee_edit.dart';
import '../payments/payments_page.dart';
import '../payments/credit_page.dart';

class EmployeeDashboard extends StatelessWidget {
  const EmployeeDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.secondary,
      appBar: AppBar(
          title: const Text('Employee Dashboard'),
          backgroundColor: AppColors.accent),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Welcome, employer!',
                style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF333333))),
            const SizedBox(height: 12),
            const Text('Manage your company profile and job postings.'),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.accent,
                  foregroundColor: Colors.white),
              onPressed: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const EmployeeEditPage())),
              icon: const Icon(Icons.business, color: Colors.white),
              label: const Text('Edit Company Profile'),
            ),
            const SizedBox(height: 8),
            ElevatedButton.icon(
              onPressed: () {},
              icon: const Icon(Icons.post_add_outlined),
              label: const Text('My Jobs'),
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
                          const PaymentsPage(title: 'Payments - Employer'))),
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
                          const CreditPage(title: 'Credit - Employer'))),
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
