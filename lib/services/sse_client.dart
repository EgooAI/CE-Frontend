// Cross-platform SSE connector. Uses conditional imports to pick the right implementation.
import 'dart:async';

import 'sse_client_io.dart' if (dart.library.html) 'sse_client_web.dart';

/// Connects to [url] with [headers] and [body]. Returns a stream of maps: {"event":..., "data":...}
Stream<Map<String, dynamic>> connect(
  String url,
  Map<String, String> headers,
  String body,
) {
  return connectImpl(url, headers, body);
}
