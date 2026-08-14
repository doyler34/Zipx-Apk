/// Whether the app is running on Fire TV / Android TV (leanback).
///
/// Set once at startup in `main()` (via device_info) and read synchronously by
/// widgets that need to behave differently on a TV - e.g. skipping the in-app
/// WebView (which is crash-prone on Fire TV) for trailers.
bool isAndroidTv = false;
