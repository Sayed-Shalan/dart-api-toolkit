import 'dart:convert';
import 'dart:io';

import 'package:api_toolkit/api_toolkit.dart';

/// Runs without a network. A 503 is followed by one successful GET.
Future<void> main() async {
  final transport = _ScriptedTransport([
    TransportResponse(statusCode: 503, body: utf8.encode('unavailable')),
    TransportResponse(statusCode: 200, body: utf8.encode('{"name":"Ada"}')),
  ]);
  final result = await ApiClient(transport).execute<String>(
    ApiRequest(
      method: ApiMethod.get,
      uri: Uri.parse('https://example.test/profile'),
    ),
    decode: (body) {
      final json = jsonDecode(utf8.decode(body));
      if (json is! Map || json['name'] is! String) {
        throw const FormatException('expected a name');
      }
      return json['name'] as String;
    },
  );

  if (result is! ApiSuccess<String> ||
      result.value != 'Ada' ||
      transport.calls != 2) {
    stderr.writeln('example failed: $result calls=${transport.calls}');
    exitCode = 1;
    return;
  }
  stdout.writeln('profile: ${result.value}');
}

class _ScriptedTransport implements Transport {
  _ScriptedTransport(this._responses);

  final List<TransportResponse> _responses;
  int calls = 0;

  @override
  Future<TransportResponse> send(ApiRequest request) async {
    calls += 1;
    return _responses.removeAt(0);
  }
}
