import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

class KashierCheckoutResult {
  final bool success;
  final Uri? finalUrl;
  KashierCheckoutResult({required this.success, this.finalUrl});
}

class KashierCheckoutPage extends StatefulWidget {
  final Uri checkoutUrl;
  final Uri successUrl; // we detect navigation to this URL
  final Uri failureUrl; // detect navigation to this URL

  const KashierCheckoutPage({
    super.key,
    required this.checkoutUrl,
    required this.successUrl,
    required this.failureUrl,
  });

  @override
  State<KashierCheckoutPage> createState() => _KashierCheckoutPageState();
}

class _KashierCheckoutPageState extends State<KashierCheckoutPage> {
  late final WebViewController _controller;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    final navDelegate = NavigationDelegate(
      onPageStarted: (_) => setState(() => _loading = true),
      onPageFinished: (_) => setState(() => _loading = false),
      onNavigationRequest: (NavigationRequest req) {
        final url = Uri.parse(req.url);
        if (_matches(url, widget.successUrl)) {
          Navigator.of(context).pop(KashierCheckoutResult(success: true, finalUrl: url));
          return NavigationDecision.prevent;
        }
        if (_matches(url, widget.failureUrl)) {
          Navigator.of(context).pop(KashierCheckoutResult(success: false, finalUrl: url));
          return NavigationDecision.prevent;
        }
        return NavigationDecision.navigate;
      },
    );

    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(navDelegate)
      ..loadRequest(widget.checkoutUrl);
  }

  bool _matches(Uri a, Uri b) {
    // Match by scheme+host+path; query can vary.
    return a.scheme == b.scheme && a.host == b.host && a.path == b.path;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Kashier Checkout')),
      body: Stack(children: [
        WebViewWidget(controller: _controller),
        if (_loading)
          const LinearProgressIndicator(minHeight: 2),
      ]),
    );
  }
}
