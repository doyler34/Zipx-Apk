import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';

import '../../../device/device_info.dart';
import '../../../dependency_injection/di.dart';
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

  /// The embed URL requested for the in-flight attempt. `onHttpError` gives
  /// no way to tell a main-document response from a sub-resource one, so we
  /// compare against this to decide whether an HTTP error status is the
  /// provider itself failing (e.g. a Cloudflare block/challenge page served
  /// with a non-2xx status) versus a harmless ad/tracker asset 404ing.
  Uri? _pendingUrl;

  /// True while the device is in landscape - drives immersive fullscreen
  /// (see [didChangeMetrics]). Landscape is the only fullscreen trigger:
  /// there's no separate manual toggle, matching how video players
  /// conventionally behave on rotation.
  bool _isFullScreen = false;

  StreamingProvider? get _currentProvider => (_currentIndex >= 0 && _currentIndex < _attemptQueue.length) ? _attemptQueue[_currentIndex] : null;

  @override
  void initState() {
    super.initState();
    // On TV stay landscape-only (TVs are fixed landscape - allowing portrait
    // here is what made the player flip to a phone-style portrait view). On
    // a phone, allow both so the player can rotate and go fullscreen.
    SystemChrome.setPreferredOrientations(
      sl<DeviceInfo>().isTv
          ? const [DeviceOrientation.landscapeLeft, DeviceOrientation.landscapeRight]
          : const [
              DeviceOrientation.portraitUp,
              DeviceOrientation.landscapeLeft,
              DeviceOrientation.landscapeRight,
            ],
    );
    WidgetsBinding.instance.addPostFrameCallback((_) => _autoStartOrSelect());
  }

  /// If only one provider is enabled there's nothing to choose - start it
  /// straight away instead of making the user confirm a one-item picker
  /// (which on a TV was an extra remote click before playback). The switch-
  /// provider button in the app bar is still available.
  void _autoStartOrSelect() {
    final providers = widget.playbackProviderService.enabledProviders;
    if (providers.length == 1) {
      _startPlayback(providers.first);
    } else {
      _openSelector();
    }
  }

  @override
  void dispose() {
    _loadTimeoutTimer?.cancel();
    // Restore the app's default orientation for this device type: landscape
    // on TV, portrait on phone.
    SystemChrome.setPreferredOrientations(
      sl<DeviceInfo>().isTv
          ? const [DeviceOrientation.landscapeLeft, DeviceOrientation.landscapeRight]
          : const [DeviceOrientation.portraitUp],
    );
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  /// Rotating to landscape is treated as "go fullscreen": hides our own app
  /// bar and the system status/nav bars so the video actually fills the
  /// screen, rather than just reflowing wider underneath them.
  ///
  /// Reading MediaQuery here (an inherited dependency) rather than in a
  /// WidgetsBindingObserver.didChangeMetrics callback matters: that observer
  /// fires before the inherited MediaQuery rebuilds, so it reads the
  /// orientation one rotation behind and fullscreen never engages.
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // On a TV the screen is permanently landscape, so treating landscape as
    // "hide all chrome" would leave a remote user with no on-screen close /
    // switch-provider buttons. Keep the app bar (and its focusable buttons)
    // visible there; the immersive-fullscreen-on-rotate behaviour is for
    // phones only.
    if (sl<DeviceInfo>().isTv) return;
    final isLandscape = MediaQuery.of(context).orientation == Orientation.landscape;
    if (isLandscape == _isFullScreen) return;

    // No setState: didChangeDependencies is always followed by a build.
    _isFullScreen = isLandscape;
    SystemChrome.setEnabledSystemUIMode(isLandscape ? SystemUiMode.immersiveSticky : SystemUiMode.edgeToEdge);
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
    _pendingUrl = result.embedUrl;

    setState(() => _status = _PlayerStatus.loading);

    final controller = WebViewController();
    _configureController(controller, provider, token);
    // Providers publish these as *embed* URLs meant to sit inside an
    // <iframe> on a hosting page - loading one directly as the WebView's
    // top-level document makes `window.top === window.self` true, which
    // several providers use to detect "not actually embedded" and respond
    // with a blank page instead of an error. Wrapping it in a minimal local
    // HTML page with the real URL in an iframe reproduces how it's actually
    // meant to be consumed. baseUrl is set to the provider's own origin so
    // the iframe isn't loaded from a bare `about:blank` parent.
    controller.loadHtmlString(
      _embedWrapperHtml(result.embedUrl),
      baseUrl: '${result.embedUrl.scheme}://${result.embedUrl.host}',
    );
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
            // The actual provider content now loads inside an iframe (see
            // `_embedWrapperHtml`), so it's technically a "sub-frame" from
            // the WebView's point of view even though it's the whole reason
            // we're here. Treat a failure as fatal if it's either our own
            // wrapper's main frame (should basically never happen, it's
            // static local HTML) or that specific provider iframe - anything
            // else is an ad/tracker sub-resource and gets ignored.
            final erroringUrl = error.url != null ? Uri.tryParse(error.url!) : null;
            if (error.isForMainFrame == false && !_isPendingEmbedUrl(erroringUrl)) return;
            _handleFailure(provider, error.description);
          },
          onHttpError: (error) {
            if (token != _attemptToken) return; // stale WebView we've since abandoned
            // `onWebResourceError` only covers network/connection-level
            // failures. A provider sitting behind Cloudflare (or similar)
            // can return a non-2xx status for a block/challenge page while
            // the WebView still considers that a "successful" load - which
            // otherwise shows up as a blank player with no error at all.
            // Only the provider's own embed response counts as fatal here;
            // sub-resources (ads, trackers) 404ing constantly is normal.
            final statusCode = error.response?.statusCode;
            if (statusCode == null || !_isPendingEmbedUrl(error.request?.uri)) return;
            if (statusCode >= 400) {
              _handleFailure(provider, 'Provider returned an error (HTTP $statusCode).');
            }
          },
          onNavigationRequest: (navRequest) {
            final uri = Uri.tryParse(navRequest.url);
            if (uri == null) return NavigationDecision.prevent;

            // The top-level document is always our own static wrapper (see
            // `_embedWrapperHtml`) - nothing should ever legitimately
            // navigate it away, so any attempt is blocked outright. This
            // also covers "frame-busting": some providers' JS tries to
            // redirect `window.top` to their own domain when it detects it
            // isn't the top frame, which would otherwise silently undo the
            // iframe embedding and reintroduce the direct-navigation bug.
            // It doubles as the pop-up/ad-redirect block this always was.
            if (navRequest.isMainFrame) return NavigationDecision.prevent;

            // Sub-frames (the provider's own iframe, and whatever it nests
            // inside itself) are left free to navigate so playback keeps
            // working - they can't replace the app screen on their own.
            if (uri.scheme != 'http' && uri.scheme != 'https') {
              // Blocks intent://, market://, etc - the classic ad-redirect
              // trick to kick the user out to another app/browser, even from
              // a sub-frame.
              return NavigationDecision.prevent;
            }
            return NavigationDecision.navigate;
          },
        ),
      );

    final platformController = controller.platform;
    if (platformController is AndroidWebViewController) {
      platformController.setMediaPlaybackRequiresUserGesture(false);
    }
  }

  /// Whether [uri] is the provider embed URL currently being loaded (same
  /// host + path as [_pendingUrl], ignoring query string). Used to recognize
  /// an error/response as "the provider's own iframe failed" even though it
  /// is technically a sub-frame of our wrapper document.
  bool _isPendingEmbedUrl(Uri? uri) {
    final pending = _pendingUrl;
    return uri != null && pending != null && uri.host == pending.host && uri.path == pending.path;
  }

  /// Minimal local page that embeds [embedUrl] in an iframe instead of
  /// navigating the WebView to it directly. See the comment at the call
  /// site for why: several providers only serve real content when they
  /// detect they're actually inside an iframe.
  String _embedWrapperHtml(Uri embedUrl) {
    return '''
<!DOCTYPE html>
<html>
<head>
<meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no" />
<style>
  html, body { margin: 0; padding: 0; background: #000; height: 100%; overflow: hidden; }
  iframe { position: absolute; top: 0; left: 0; width: 100%; height: 100%; border: 0; }
</style>
</head>
<body>
<iframe src="$embedUrl" allow="autoplay; fullscreen; encrypted-media" allowfullscreen></iframe>
</body>
</html>
''';
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
        extendBodyBehindAppBar: true,
        // Landscape = fullscreen: the app bar (and the system status/nav
        // bars, toggled in didChangeMetrics) get out of the way so the
        // video actually fills the screen instead of being squeezed under
        // our own chrome.
        appBar: _isFullScreen
            ? null
            : PlayerStatusBar(
                title: widget.request.title,
                activeProviderName: provider?.displayName,
                onSwitchProvider: _openSelector,
                onClose: () => Navigator.of(context).pop(),
              ),
        body: SafeArea(
          child: Stack(
            // Without this, non-positioned Stack children get loose
            // constraints and the WebView platform view sizes itself small
            // instead of filling the available space, which is why playback
            // wasn't filling the screen.
            fit: StackFit.expand,
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
