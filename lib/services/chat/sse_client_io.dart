// IO implementation using package:http streaming
import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;

Stream<Map<String, dynamic>> connectImpl(
  String url,
  Map<String, String> headers,
  String body,
) async* {
  final client = http.Client();
  final request = http.Request('POST', Uri.parse(url));
  request.headers.addAll(headers);
  request.body = body;

  final streamed = await client.send(request);
  if (streamed.statusCode >= 400) {
    final bodyText = await streamed.stream.bytesToString();
    String message = '请求失败: HTTP ${streamed.statusCode}';
    try {
      final decoded = jsonDecode(bodyText);
      if (decoded is Map && decoded['message'] != null) {
        message = decoded['message'].toString();
      } else if (bodyText.isNotEmpty) {
        message = bodyText;
      }
    } catch (_) {
      if (bodyText.isNotEmpty) {
        message = bodyText;
      }
    }
    yield {
      'event': 'error',
      'data': {'message': message, 'status': streamed.statusCode},
    };
    return;
  }
  final utf8Stream = streamed.stream.transform(utf8.decoder);
  String buffer = '';

  await for (final chunk in utf8Stream) {
    buffer += chunk;
    // split events by double newline
    final items = buffer.split('\n\n');
    // keep last partial
    buffer = items.removeLast();
    for (var item in items) {
      item = item.trim();
      if (item.isEmpty) continue;
      String? event;
      String data = '';
      final lines = item.split('\n');
      for (var line in lines) {
        if (line.startsWith('event:')) {
          event = line.substring(6).trim();
        } else if (line.startsWith('data:')) {
          data += line.substring(5).trim();
        }
      }
      if (data.isNotEmpty) {
        try {
          yield {'event': event ?? 'message', 'data': jsonDecode(data)};
        } catch (err) {
          yield {'event': event ?? 'message', 'data': data};
        }
      }
    }
  }
  // final buffer
  if (buffer.trim().isNotEmpty) {
    final item = buffer.trim();
    String? event;
    String data = '';
    final lines = item.split('\n');
    for (var line in lines) {
      if (line.startsWith('event:')) {
        event = line.substring(6).trim();
      } else if (line.startsWith('data:')) {
        data += line.substring(5).trim();
      }
    }
    if (data.isNotEmpty) {
      try {
        yield {'event': event ?? 'message', 'data': jsonDecode(data)};
      } catch (err) {
        yield {'event': event ?? 'message', 'data': data};
      }
    }
  }
}
