// Web implementation using XHR streaming (works with POST)
import 'dart:async';
import 'dart:convert';
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

Stream<Map<String, dynamic>> connectImpl(
  String url,
  Map<String, String> headers,
  String body,
) {
  final controller = StreamController<Map<String, dynamic>>();
  final request = html.HttpRequest();

  String buffer = '';

  request.open('POST', url);
  request.responseType = 'text';

  headers.forEach((k, v) {
    request.setRequestHeader(k, v);
  });

  request.onProgress.listen((e) {
    // responseText grows incrementally
    final text = request.responseText ?? '';
    if (text.length <= buffer.length) return;
    final chunk = text.substring(buffer.length);
    buffer = text;
    // parse SSE-like messages
    final parts = chunk.split('\n\n');
    for (var part in parts) {
      part = part.trim();
      if (part.isEmpty) continue;
      String? event;
      String data = '';
      final lines = part.split('\n');
      for (var line in lines) {
        if (line.startsWith('event:')) {
          event = line.substring(6).trim();
        } else if (line.startsWith('data:')) {
          data += line.substring(5).trim();
        }
      }
      if (data.isNotEmpty) {
        try {
          final parsed = jsonDecode(data);
          controller.add({'event': event ?? 'message', 'data': parsed});
        } catch (err) {
          controller.add({'event': event ?? 'message', 'data': data});
        }
      }
    }
  });

  request.onLoad.listen((e) {
    // final chunk may be available in responseText
    final text = request.responseText ?? '';
    if (text.length > buffer.length) {
      final chunk = text.substring(buffer.length);
      buffer = text;
      final parts = chunk.split('\n\n');
      for (var part in parts) {
        part = part.trim();
        if (part.isEmpty) continue;
        String? event;
        String data = '';
        final lines = part.split('\n');
        for (var line in lines) {
          if (line.startsWith('event:')) {
            event = line.substring(6).trim();
          } else if (line.startsWith('data:')) {
            data += line.substring(5).trim();
          }
        }
        if (data.isNotEmpty) {
          try {
            final parsed = jsonDecode(data);
            controller.add({'event': event ?? 'message', 'data': parsed});
          } catch (err) {
            controller.add({'event': event ?? 'message', 'data': data});
          }
        }
      }
    }
    controller.close();
  });

  request.onError.listen((e) {
    controller.addError('Connection error');
    controller.close();
  });

  // send body
  request.send(body);

  return controller.stream;
}
