import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

class BloggerWebViewScreen extends StatefulWidget {
  final String initialUrl;
  final String title;

  const BloggerWebViewScreen({
    super.key,
    required this.initialUrl,
    required this.title,
  });

  @override
  State<BloggerWebViewScreen> createState() => _BloggerWebViewScreenState();
}

class _BloggerWebViewScreenState extends State<BloggerWebViewScreen> {
  late final WebViewController _controller;
  double _progress = 0;

  @override
  void initState() {
    super.initState();

    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.black)
      ..setUserAgent(
        'Mozilla/5.0 (iPhone; CPU iPhone OS 15_0 like Mac OS X) '
        'AppleWebKit/605.1.15 (KHTML, like Gecko) Version/15.0 '
        'Mobile/15E148 Safari/604.1',
      )
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (int progress) {
            setState(() {
              _progress = progress / 100.0;
            });
          },
          onPageStarted: (_) {
            setState(() {
              _progress = 0;
            });
          },
          onPageFinished: (_) {
            setState(() {
              _progress = 1;
            });
          },
          onNavigationRequest: (navigation) {
            return NavigationDecision.navigate;
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.initialUrl));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text(
          widget.title,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          if (_progress < 1)
            LinearProgressIndicator(
              value: _progress,
              minHeight: 3,
              color: Theme.of(context).colorScheme.primary,
              backgroundColor: Colors.white10,
            ),
          Expanded(child: WebViewWidget(controller: _controller)),
        ],
      ),
    );
  }
}
