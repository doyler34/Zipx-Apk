import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';

import '../../domain/entities/playback_request.dart';
import '../../domain/providers/streaming_provider.dart';
import '../../services/playback_history_service.dart';
import '../../services/playback_provider_service.dart';
import '../widgets/player_error_view.dart';
import '../widgets/player_loading_view.dart';
import '../widgets/player_status_bar.dart';
import '../widgets/provider_selector_sheet.dart';

enum _PlayerStatus { selectingProvider, loading, playing, error }

/// The single screen every "Watch Now" / episode "Play" action opens.
///
/// This screen only ever talks to [PlaybackProviderService] (to resolve a
/// provider into a URL and to compute the fallback order) and
/// [PlaybackHistoryService] (to record continue-watching). It never
/// constructs a provider or a URL itself, and never imports a concrete
/// [StreamingProvider] implementation - that's what keeps provider-specific
/// logic out of the UI layer.
class PlayerScreen extends StatefulWidget {
  const PlayerScreen({
    super.key,
    required this.request,
    required this.playbackProviderService,
    required this.historyService,
  });

  final PlaybackRequest request;
  final PlaybackProviderService playbackProviderService;
  final PlaybackHistoryService historyService;

  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen> {
  static const Duration _loadTimeout = Duration(seconds: 25);

  WebViewController? _controller;
  List<StreamingProvider> _attemptQueue = const [];
  int _currentIndex = -1;
  final Set<String> _failedProviderIds = {};
  _PlayerStatus _status = _PlayerStatus.selectingProvider;
  String _errorMessage = '';
  bool _historyRecordedForCurrentAttempt = false;
  bool _failureHandledForCurrentAttempt = false;
  Timer? _loadTimeoutTimer;

  /// Bumped every time a new [WebViewController] is created. Each
  /// controller's callbacks capture the token they were created with, so a
  /// late/stale callback from a WebView we've already abandoned (e.g. a slow
  /// response arriving after automatic fallback already moved on) can be
  /// told apart from the one that's actually on screen and ignored.
  int _attemptToken = 0;

  StreamingProvider? get _currentProvider => (_currentIndex >= 0 && _currentIndex < _attemptQueue.length) ? _attemptQueue[_currentIndex] : null;

  @override
  void initState() {
    super.initState();
    // The app is portrait-locked by default (see main.dart); the player is
    // the one screen that needs landscape too, both for manual rotation and
    // for HTML5 fullscreen video.
    SystemChrome.setPreferredOrientations(const [
      DeviceOrientation.portraitUp,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    WidgetsBinding.instance.addPostFrameCallback((_) => _openSelector());
  }

  @override
  void dispose() {
    _loadTimeoutTimer?.cancel();
    SystemChrome.setPreferredOrientations(const [DeviceOrientation.portraitUp]);
    super.dispose();
  }

  Future<void> _openSelector() async {
    final providers = widget.playbackProviderService.enabledProviders;
    final preselected = _currentProvider ?? widget.playbackProviderService.preferredProvider;

    final selected = await ProviderSelectorSheet.show(
      context,
      providers: providers,
      failedProviderIds: _failedProviderIds,
      activeProviderId: preselected?.id,
    );

    if (selected != null) {
      _startPlayback(selected);
    }
  }

  void _startPlayback(StreamingProvider provider) {
    // Remembers this as the user's preferred provider for next time.
    widget.playbackProviderService.setDefaultProvider(provider.id);

    _attemptQueue = widget.playbackProviderService.fallbackSequence(provider.id);
    _currentIndex = _attemptQueue.indexWhere((p) => p.id == provider.id);
    if (_currentIndex == -1) _currentIndex = 0;
    _failedProviderIds.clear();
    _loadCurrentProvider();
  }

  void _loadCurrentProvider() {
    final provider = _currentProvider;
    if (provider == null) {
      setState(() {
        _status = _PlayerStatus.error;
        _errorMessage = 'No streaming providers are enabled. Enable one in Settings > Streaming Providers.';
      });
      return;
    }

    final result = widget.playbackProviderService.buildResult(widget.request, provider);
    _historyRecordedForCurrentAttempt = false;
    _failureHandledForCurrentAttempt = false;
    final token = ++_attemptToken;

    setState(() => _status = _PlayerStatus.loading);

    final controller = WebViewController();
    _configureController(controller, provider, token);
    controller.loadRequest(result.embedUrl);
    _controller = controller;

    _loadTimeoutTimer?.cancel();
    _loadTimeoutTimer = Timer(_loadTimeout, () {
      if (token == _attemptToken && _status == _PlayerStatus.loading) {
        _handleFailure(provider, 'Timed out waiting for this provider to respond.');
      }
    });
  }

  void _configureController(WebViewController controller, StreamingProvider provider, int token) {
    controller
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.black)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (_) {
            if (token != _attemptToken) return; // stale WebView we've since abandoned
            _loadTimeoutTimer?.cancel();
            if (!mounted) return;
            setState(() => _status = _PlayerStatus.playing);
            if (!_historyRecordedForCurrentAttempt) {
              _historyRecordedForCurrentAttempt = true;
              widget.historyService.recordPlaybackStarted(request: widget.request, providerId: provider.id);
            }
          },
          onWebResourceError: (error) {
            if (token != _attemptToken) return; // stale WebView we've since abandoned
            // Sub-resource failures (ad scripts, tracking pixels, blocked
            // trackers) are extremely common on embed pages and must not be
            // treated as the provider failing.
            if (error.isForMainFrame == false) return;
            _handleFailure(provider, error.description);
          },
          onNavigationRequest: (navRequest) {
            final uri = Uri.tryParse(navRequest.url);
            if (uri == null) return NavigationDecision.prevent;

            // Only gate top-level navigations. Sub-frames (the actual video
            // player is very often an iframe) stay untouched so playback
            // keeps working; they can't replace the app screen on their own.
            if (!navRequest.isMainFrame) return NavigationDecision.navigate;

            if (uri.scheme != 'http' && uri.scheme != 'https') {
              // Blocks intent://, market://, etc - the classic ad-redirect
              // trick to kick the user out to another app/browser.
              return NavigationDecision.prevent;
            }

            if (provider.canHandleNavigation(uri)) {
              return NavigationDecision.navigate;
            }
            // Unrelated domain trying to take over the main frame - this is
            // what keeps the app screen from being replaced by ad pages, and
            // covers the common "fake window.open, then navigate top frame"
            // pop-up pattern (real window.open popups are already dropped by
            // default since this WebView never registers multi-window
            // support).
            return NavigationDecision.prevent;
          },
        ),
      );

    final platformController = controller.platform;
    if (platformController is AndroidWebViewController) {
      platformController.setMediaPlaybackRequiresUserGesture(false);
    }
  }

  void _handleFailure(StreamingProvider provider, String message) {
    if (!mounted || _failureHandledForCurrentAttempt) return;
    _failureHandledForCurrentAttempt = true;
    _loadTimeoutTimer?.cancel();
    _failedProviderIds.add(provider.id);

    final hasNext = _currentIndex + 1 < _attemptQueue.length;
    if (widget.playbackProviderService.automaticFallbackEnabled && hasNext) {
      _currentIndex++;
      _loadCurrentProvider();
      return;
    }

    setState(() {
      _status = _PlayerStatus.error;
      _errorMessage = message;
    });
  }

  void _retry() {
    if (_currentProvider == null) return;
    _failedProviderIds.remove(_currentProvider!.id);
    _loadCurrentProvider();
  }

  void _tryAnotherProvider() {
    final hasNext = _currentIndex + 1 < _attemptQueue.length;
    if (hasNext) {
      _currentIndex++;
      _loadCurrentProvider();
    } else {
      _openSelector();
    }
  }

  Future<void> _handleBack() async {
    final controller = _controller;
    if (controller != null && await controller.canGoBack()) {
      await controller.goBack();
      return;
    }
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final provider = _currentProvider;
    final failedNames = _failedProviderIds.map((id) => widget.playbackProviderService.providerById(id)?.displayName ?? id).toList();
    final exhausted = _attemptQueue.isNotEmpty && _failedProviderIds.length >= _attemptQueue.length;

    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) {
        if (didPop) return;
        _handleBack();
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        appBar: PlayerStatusBar(
          title: widget.request.title,
          activeProviderName: provider?.displayName,
          onSwitchProvider: _openSelector,
          onClose: () => Navigator.of(context).pop(),
        ),
        body: SafeArea(
          child: Stack(
            children: [
              if (_controller != null) WebViewWidget(controller: _controller!),
              if (_status == _PlayerStatus.loading) PlayerLoadingView(providerName: provider?.displayName ?? ''),
              if (_status == _PlayerStatus.error)
                PlayerErrorView(
                  message: _errorMessage,
                  failedProviderNames: failedNames,
                  exhausted: exhausted,
                  onRetry: _retry,
                  onTryAnotherProvider: _tryAnotherProvider,
                ),
              if (_status == _PlayerStatus.selectingProvider && _controller == null)
                const ColoredBox(color: Colors.black, child: SizedBox.expand()),
            ],
          ),
        ),
      ),
    );
  }
}
