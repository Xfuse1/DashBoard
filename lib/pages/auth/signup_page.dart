// ignore_for_file: deprecated_member_use
import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import 'seeker_signup_page.dart';
import 'employer_signup_page.dart';

class SignupPage extends StatefulWidget {
  const SignupPage({super.key});

  @override
  State<SignupPage> createState() => _SignupPageState();
}

class _SignupPageState extends State<SignupPage> {

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.secondary,
      appBar: AppBar(
          title: const Text('Join CVEEEZ'), backgroundColor: AppColors.accent),
      body: Center(
        child: Card(
          child: Container(
            width: 760,
            padding: const EdgeInsets.all(20),
            // Make the card content scrollable to avoid RenderFlex overflow
            child: SingleChildScrollView(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                const Text('Choose your account type to get started',
                    style: TextStyle(color: Colors.black54)),
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(
                      child: InkWell(
                    onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const SeekerSignupPage())),
                    child: Container(
                      padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade300),
              borderRadius: BorderRadius.circular(10)),
                      child: Column(children: [
                        const Icon(Icons.person,
                            size: 36, color: AppColors.accent),
                        const SizedBox(height: 8),
                        const Text('Job Seeker',
                            style: TextStyle(fontWeight: FontWeight.bold)),
                        const SizedBox(height: 6),
                        const Text(
                            'Find jobs, build your CV, and grow your career.',
                            textAlign: TextAlign.center)
                      ]),
                    ),
                  )),
                  const SizedBox(width: 12),
                  Expanded(
                      child: InkWell(
                    onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const EmployerSignupPage())),
                    child: Container(
                      padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade300),
              borderRadius: BorderRadius.circular(10)),
                      child: Column(children: [
                        const Icon(Icons.business,
                            size: 36, color: AppColors.accent),
                        const SizedBox(height: 8),
                        const Text('Employer',
                            style: TextStyle(fontWeight: FontWeight.bold)),
                        const SizedBox(height: 6),
                        const Text(
                            'Post jobs, find talent, and manage candidates.',
                            textAlign: TextAlign.center)
                      ]),
                    ),
                  ))
                ]),
                const SizedBox(height: 18),
                const Text(
                  'Tap a card to open the full signup form for that account type.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.black54),
                ),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}
