import 'package:flutter/material.dart';
import '../services/supabase_service.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;
import '../services/theme_service.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/scheduler.dart' show SchedulerBinding;

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  String? _fullName;
  String? _destination;

  @override
  void initState() {
    super.initState();
    // If the app was opened via a Supabase recovery link but,
    // for any reason, we landed on Home, route to reset page.
    SchedulerBinding.instance.addPostFrameCallback((_) {
      try {
        final uri = Uri.base;
        final isRecovery = (uri.queryParameters['type'] ?? '').toLowerCase() == 'recovery' ||
            (uri.fragment.isNotEmpty &&
                ((Uri.splitQueryString(uri.fragment)['type'] ?? '').toLowerCase() == 'recovery')) ||
            uri.path.endsWith('/reset-password');
        if (kIsWeb && isRecovery && mounted) {
          Navigator.pushReplacementNamed(context, '/reset-password');
          return;
        }
      } catch (_) {}
    });
    _loadCurrentProfile();
  }

  Future<void> _loadCurrentProfile() async {
    try {
      if (!SupabaseService.initialized) return;
      final userId = SupabaseService.client.auth.currentUser?.id;
      if (userId == null) return;

      // Try seeker profile first
      try {
        final seeker =
            await (SupabaseService.client.from('seeker_profiles') as dynamic)
                .select()
                .eq('id', userId)
                .maybeSingle();
        if (seeker != null) {
          if (!mounted) return;
          setState(() {
            _fullName = seeker['full_name'] ?? seeker['name'] ?? userId;
            _destination = '/seeker';
          });
          return;
        }
      } catch (_) {}

      // Try company/employer profile
      try {
        final company =
            await (SupabaseService.client.from('companies') as dynamic)
                .select()
                .eq('owner_user_id', userId)
                .maybeSingle();
        if (company != null) {
          if (!mounted) return;
          setState(() {
            _fullName = company['name_en'] ?? company['name_ar'] ?? userId;
            _destination = '/employee';
          });
          return;
        }
      } catch (_) {}

      // Fallback: use email or user id
      try {
        final email = SupabaseService.client.auth.currentUser?.email;
        if (!mounted) return;
        setState(() {
          _fullName = email ?? SupabaseService.client.auth.currentUser?.id;
          _destination = '/seeker';
        });
      } catch (_) {}
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(70),
        child: _buildHeader(context),
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildHeroSection(context),
            _buildSearchBar(context),
            _buildDevSections(context),
            const SizedBox(height: 32),
            _buildAdvantagesSection(context),
            const SizedBox(height: 32),
            const PortfolioSection(),
            const SizedBox(height: 24),
            _buildStatsSection(context),
            const SizedBox(height: 32),
            _buildCtaSection(context),
            const SizedBox(height: 32),
            _buildFooter(context),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final bg = Theme.of(context).scaffoldBackgroundColor;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 10),
      color: bg,
      child: Row(
        children: [
          // Logo
          Text(
            'CVEEEZ',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 26,
              color: Theme.of(context).colorScheme.primary,
              letterSpacing: 2,
            ),
          ),
          const SizedBox(width: 40),
          // Navigation
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                _navButton(context, 'Home'),
                _navButton(context, 'Services',
                    onPressed: () => Navigator.pushNamed(context, '/services')),
                _navButton(context, 'Jobs'),
                _navButton(context, 'Talent Space'),
                _navButton(context, 'Contact Us'),
                _navButton(context, 'About Us',
                    onPressed: () => Navigator.pushNamed(context, '/about')),
              ],
            ),
          ),
         
          const SizedBox(width: 8),
          // Theme toggle
          ValueListenableBuilder<ThemeMode>(
            valueListenable: themeNotifier,
            builder: (context, mode, _) {
              return IconButton(
                onPressed: () {
                  themeNotifier.value = (themeNotifier.value == ThemeMode.light)
                      ? ThemeMode.dark
                      : ThemeMode.light;
                },
                icon: Icon(mode == ThemeMode.light
                    ? Icons.dark_mode
                    : Icons.light_mode),
                tooltip: 'Toggle theme',
              );
            },
          ),
          // Login / profile button
          _fullName == null
              ? ElevatedButton(
                  onPressed: () {
                    Navigator.pushNamed(context, '/login');
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    foregroundColor: Theme.of(context).colorScheme.onPrimary,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text('Login'),
                )
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ElevatedButton(
                      onPressed: () {
                        final dest = _destination ?? '/seeker';
                        Navigator.pushReplacementNamed(context, dest);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(context).colorScheme.primary,
                        foregroundColor:
                            Theme.of(context).colorScheme.onPrimary,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 24, vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: Text(_fullName ?? 'Account'),
                    ),
                    const SizedBox(width: 8),
                    // Logout icon button
                    IconButton(
                      tooltip: 'Logout',
                      onPressed: () async {
                        // Sign out and clear stored project binding, then show login
                        try {
                          await SupabaseService.signOutAndClearBinding();
                        } catch (_) {}
                        if (!mounted) return;
                        // Reset local state and navigate to login
                        setState(() {
                          _fullName = null;
                          _destination = null;
                        });
                        Navigator.pushReplacementNamed(context, '/login');
                      },
                      icon: Icon(Icons.logout,
                          color: Theme.of(context).colorScheme.primary),
                    ),
                  ],
                ),
        ],
      ),
    );
  }

  Widget _navButton(BuildContext context, String label,
      {VoidCallback? onPressed}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: TextButton(
        onPressed: onPressed ?? () {},
        child: Text(
          label,
          style: TextStyle(
              fontSize: 16,
              color: Theme.of(context).textTheme.bodyMedium?.color),
        ),
      ),
    );
  }

  Future<Uri> _buildSsoUri(String link) async {
    // Default to the plain URL
    Uri target = Uri.parse(link);
    try {
      if (!SupabaseService.initialized) return target;
      // If not logged in, don't attach anything
      final user = SupabaseService.client.auth.currentUser;
      if (user == null) return target;

      // Try to read access/refresh tokens across possible client versions
      final authDyn = SupabaseService.client.auth as dynamic;
      String? accessToken;
      String? refreshToken;
      try {
        final cs = authDyn.currentSession;
        accessToken = cs?.accessToken ?? cs?.access_token;
        refreshToken = cs?.refreshToken ?? cs?.refresh_token;
      } catch (_) {}
      if (accessToken == null || refreshToken == null) {
        try {
          final sess = await authDyn.session();
          accessToken = accessToken ?? sess?.accessToken ?? sess?.access_token;
          refreshToken =
              refreshToken ?? sess?.refreshToken ?? sess?.refresh_token;
        } catch (_) {}
      }
      // Strongly typed fallback
      try {
        accessToken = accessToken ??
            SupabaseService.client.auth.currentSession?.accessToken;
        refreshToken = refreshToken ??
            SupabaseService.client.auth.currentSession?.refreshToken;
      } catch (_) {}

      if (accessToken == null || refreshToken == null) return target;

      // Prefer using URL fragment so tokens don't hit server logs
      final existingFragment = target.fragment;
      final ssoParams = [
        'sso=supabase',
        'access_token=${Uri.encodeComponent(accessToken)}',
        'refresh_token=${Uri.encodeComponent(refreshToken)}',
      ].join('&');
      final newFragment = existingFragment.isEmpty
          ? ssoParams
          : '$existingFragment&$ssoParams';
      target = target.replace(fragment: newFragment);
      return target;
    } catch (_) {
      return target;
    }
  }

  Future<void> _openLink(BuildContext context, String link) async {
    // If link looks like an HTTP link, open externally (with SSO attach if possible).
    if (link.startsWith('http')) {
      final uri = await _buildSsoUri(link);
      try {
        if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Could not open link')));
          }
        }
      } catch (_) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Could not open link')));
        }
      }
    } else {
      Navigator.pushNamed(context, link);
    }
  }

// linkes
  Widget _buildDevSections(BuildContext context) {
    final sections = [
      {
        'title': 'Employee',
        'desc': 'Company dashboard and management',
        'icon': Icons.business,
        'link':
            'https://studio--employed5-86582846-acd41.us-central1.hosted.app'
      },
      {
        'title': 'CV Builder',
        'desc': 'Create and download your CV',
        'icon': Icons.article,
        'link': 'http://studio--studio-7954367756-191fb.us-central1.hosted.app'
      },
      {
        'title': 'E-Commerce',
        'desc': 'Buy services and products',
        'icon': Icons.shopping_bag,
        'link': 'https://example.com/ecommerce'
      },
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
      child: Row(
        children: sections.map((s) {
          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: InkWell(
                onTap: () => _openLink(context, s['link'] as String),
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Theme.of(context)
                            .shadowColor
                            .withValues(alpha: 0.05),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(s['icon'] as IconData,
                          size: 40,
                          color: Theme.of(context).colorScheme.primary),
                      const SizedBox(height: 12),
                      Text(s['title'] as String,
                          style: const TextStyle(
                              fontSize: 18, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      Text(s['desc'] as String,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              color: Theme.of(context)
                                  .textTheme
                                  .bodyMedium
                                  ?.color
                                  ?.withValues(alpha: 0.7))),
                      const SizedBox(height: 12),
                      ElevatedButton(
                        onPressed: () =>
                            _openLink(context, s['link'] as String),
                        style: ElevatedButton.styleFrom(
                          backgroundColor:
                              Theme.of(context).colorScheme.primary,
                          foregroundColor:
                              Theme.of(context).colorScheme.onPrimary,
                        ),
                        child: const Text('Open'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildHeroSection(BuildContext context) {
    return Stack(
      children: [
        // Fallback hero background using a gradient so app doesn't require an asset
        Container(
          height: 340,
          width: double.infinity,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Theme.of(context).colorScheme.primary.withValues(alpha: 0.95),
                Theme.of(context).colorScheme.primary.withValues(alpha: 0.6)
              ],
            ),
          ),
        ),
        Container(
          height: 340,
          width: double.infinity,
          color:
              Theme.of(context).colorScheme.onPrimary.withValues(alpha: 0.12),
        ),
        SizedBox(
          height: 340,
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'CVEEEZ: Your Partner for a Professional Identity',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onPrimary,
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'We write CVs to global standards (ATS • Europass • Canadian • Standard),\nand build you an unforgettable professional identity inside and outside of Egypt.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onPrimary,
                    fontSize: 18,
                  ),
                ),
                const SizedBox(height: 28),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    ElevatedButton(
                      onPressed: () {},
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(context).colorScheme.primary,
                        foregroundColor:
                            Theme.of(context).colorScheme.onPrimary,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 28, vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(24),
                        ),
                      ),
                      child: const Text('Start Your CV Now'),
                    ),
                    const SizedBox(width: 16),
                    OutlinedButton(
                      onPressed: () {},
                      style: OutlinedButton.styleFrom(
                        foregroundColor:
                            Theme.of(context).colorScheme.onPrimary,
                        side: BorderSide(
                            color: Theme.of(context).colorScheme.onPrimary,
                            width: 2),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 28, vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(24),
                        ),
                      ),
                      child: const Text('Contact Us'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSearchBar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 0),
      child: Center(
        child: Container(
          // Removed negative margin to fix assertion error
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(32),
            boxShadow: [
              BoxShadow(
                color: Theme.of(context).shadowColor.withValues(alpha: 0.08),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 220,
                child: TextField(
                  decoration: InputDecoration(
                    hintText: 'Job title, keyword, or company',
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 140,
                child: TextField(
                  decoration: InputDecoration(
                    hintText: 'Location',
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: () {},
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  foregroundColor: Theme.of(context).colorScheme.onPrimary,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24),
                  ),
                ),
                child: const Text('Search'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAdvantagesSection(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            'Our Competitive Advantages',
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).textTheme.titleLarge?.color,
            ),
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _advantageCard(
                context,
                icon: Icons.check_circle_outline,
                title: 'Professional Content',
                desc:
                    'Professional content that matches global market requirements.',
              ),
              _advantageCard(
                context,
                icon: Icons.design_services,
                title: 'Innovative Designs',
                desc: 'Modern and attractive designs that are ATS-compliant.',
              ),
              _advantageCard(
                context,
                icon: Icons.support_agent,
                title: 'Human Support',
                desc:
                    'Fast customer service support + consultations to improve your chances.',
              ),
              _advantageCard(
                context,
                icon: Icons.integration_instructions,
                title: 'Integrated Solutions',
                desc: 'CV + LinkedIn + Portfolio + Cover Letter.',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _advantageCard(BuildContext context,
      {required IconData icon, required String title, required String desc}) {
    return Expanded(
      child: Card(
        margin: const EdgeInsets.symmetric(horizontal: 10),
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 12),
          child: Column(
            children: [
              Icon(icon,
                  size: 40, color: Theme.of(context).colorScheme.primary),
              const SizedBox(height: 16),
              Text(
                title,
                style:
                    const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                desc,
                style: TextStyle(
                    fontSize: 15,
                    color: Theme.of(context)
                        .textTheme
                        .bodyMedium
                        ?.color
                        ?.withValues(alpha: 0.8)),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatsSection(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _statCard(context, '5,800+', 'Success Story in One Year'),
          _statCard(context, '97%', 'Customer Satisfaction'),
          _statCard(context, '2,024',
              'Our start with a clear vision and real passion.'),
        ],
      ),
    );
  }

  Widget _statCard(BuildContext context, String stat, String label) {
    return Expanded(
      child: Column(
        children: [
          Text(
            stat,
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
                fontSize: 15,
                color: Theme.of(context).textTheme.bodyMedium?.color),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildCtaSection(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 32),
      child: Column(
        children: [
          Text(
            'We build the professional identity you deserve.',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).textTheme.titleLarge?.color,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 18),
          ElevatedButton(
            onPressed: () {},
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.primary,
              foregroundColor: Theme.of(context).colorScheme.onPrimary,
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
            ),
            child: const Text('Start Your Journey'),
          ),
        ],
      ),
    );
  }

  Widget _buildFooter(BuildContext context) {
    return Container(
      color: Theme.of(context).colorScheme.surface,
      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 32),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Company description
          Expanded(
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'CVEEEZ',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 20,
                    letterSpacing: 2,
                    color: Theme.of(context).textTheme.titleMedium?.color,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'CVEEEZ is dedicated to empowering professionals by providing top-tier career services and a thriving job market.',
                  style: TextStyle(
                      fontSize: 15,
                      color: Theme.of(context).textTheme.bodyMedium?.color),
                ),
              ],
            ),
          ),
          // Quick links
          Expanded(
            flex: 1,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Quick Links',
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).textTheme.bodyMedium?.color)),
                const SizedBox(height: 8),
                Text('Home',
                    style: TextStyle(
                        color: Theme.of(context).textTheme.bodyMedium?.color)),
                Text('Services',
                    style: TextStyle(
                        color: Theme.of(context).textTheme.bodyMedium?.color)),
                Text('Jobs',
                    style: TextStyle(
                        color: Theme.of(context).textTheme.bodyMedium?.color)),
                Text('Talent Space',
                    style: TextStyle(
                        color: Theme.of(context).textTheme.bodyMedium?.color)),
                Text('Contact Us',
                    style: TextStyle(
                        color: Theme.of(context).textTheme.bodyMedium?.color)),
                Text('About Us',
                    style: TextStyle(
                        color: Theme.of(context).textTheme.bodyMedium?.color)),
              ],
            ),
          ),
          // Contact
          Expanded(
            flex: 1,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Contact',
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).textTheme.bodyMedium?.color)),
                const SizedBox(height: 8),
                Text('support@cveeez.com',
                    style: TextStyle(
                        color: Theme.of(context).textTheme.bodyMedium?.color)),
                const SizedBox(height: 8),
                // TODO: Replace with real social media icons using a package like font_awesome_flutter
                Row(
                  children: [
                    IconButton(
                      icon: Icon(Icons.alternate_email,
                          color: Theme.of(context)
                              .iconTheme
                              .color), // Instagram placeholder
                      onPressed: () {},
                    ),
                    IconButton(
                      icon: Icon(Icons.link,
                          color: Theme.of(context)
                              .iconTheme
                              .color), // LinkedIn placeholder
                      onPressed: () {},
                    ),
                    IconButton(
                      icon: Icon(Icons.thumb_up,
                          color: Theme.of(context)
                              .iconTheme
                              .color), // Facebook placeholder
                      onPressed: () {},
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// PortfolioSection: loads portfolio data from assets/portfolio.json and displays cards.
class PortfolioSection extends StatefulWidget {
  const PortfolioSection({super.key});

  @override
  State<PortfolioSection> createState() => _PortfolioSectionState();
}

class _PortfolioSectionState extends State<PortfolioSection> {
  List<dynamic>? _items;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadItems();
  }

  Future<void> _loadItems() async {
    try {
      final jsonStr = await rootBundle.loadString('assets/portfolio.json');
      final parsed = json.decode(jsonStr) as List<dynamic>;
      if (mounted) setState(() => _items = parsed);
    } catch (e) {
      if (mounted) setState(() => _error = 'Failed to load portfolio');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Text(_error!,
            style: TextStyle(color: Theme.of(context).colorScheme.error)),
      );
    }
    final items = _items ?? [];
    if (items.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 8),
        child: Column(
          children: [
            Text('Portfolio',
                style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).textTheme.titleLarge?.color)),
            const SizedBox(height: 12),
            Text('No portfolio items found.',
                style: TextStyle(
                    color: Theme.of(context).textTheme.bodyMedium?.color)),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Portfolio',
              style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).textTheme.titleLarge?.color)),
          const SizedBox(height: 12),
          SizedBox(
            height: 220,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: items.length,
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemBuilder: (context, i) {
                final it = items[i] as Map<String, dynamic>;
                return SizedBox(
                  width: 320,
                  child: Card(
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(it['title'] ?? '',
                              style: const TextStyle(
                                  fontSize: 18, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 8),
                          Text(it['summary'] ?? '',
                              style: TextStyle(
                                  color: Theme.of(context)
                                      .textTheme
                                      .bodyMedium
                                      ?.color)),
                          const Spacer(),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              ElevatedButton(
                                onPressed: () {
                                  final link = it['link'] as String?;
                                  if (link != null && link.isNotEmpty) {
                                    // Use same opening logic: external link
                                    final uri = Uri.parse(link);
                                    launchUrl(uri,
                                        mode: LaunchMode.externalApplication);
                                  }
                                },
                                child: Text('View',
                                    style: TextStyle(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .onPrimary)),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor:
                                      Theme.of(context).colorScheme.primary,
                                ),
                              ),
                            ],
                          )
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
