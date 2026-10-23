import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:api_toolkit/api_toolkit.dart';
import 'package:test/test.dart';

void main() {
  ApiRequest getRequest({Duration timeout = const Duration(seconds: 1)}) {
    return ApiRequest(
      method: ApiMethod.get,
      uri: Uri.parse('https://example.test/items'),
      timeout: timeout,
    );
  }

  test('decodes a successful body', () async {
    final transport = ScriptedTransport([response(200, '{"name":"Ada"}')]);
    final result = await ApiClient(transport).execute<String>(
      getRequest(),
      decode: (body) =>
          (jsonDecode(utf8.decode(body)) as Map)['name'] as String,
    );

    expect(result, isA<ApiSuccess<String>>());
    expect((result as ApiSuccess<String>).value, 'Ada');
    expect(transport.calls, 1);
  });

  test('retries a GET once after 503 and does not retry a POST', () async {
    final gets = ScriptedTransport([
      response(503, 'unavailable'),
      response(200, 'ok'),
    ]);
    final getResult = await ApiClient(
      gets,
    ).execute<String>(getRequest(), decode: utf8.decode);
    expect((getResult as ApiSuccess<String>).value, 'ok');
    expect(gets.calls, 2);

    final posts = ScriptedTransport([response(503, 'unavailable')]);
    final postResult = await ApiClient(posts).execute<String>(
      ApiRequest(
        method: ApiMethod.post,
        uri: Uri.parse('https://example.test/items'),
        body: utf8.encode('{}'),
      ),
      decode: utf8.decode,
    );
    expect(postResult, isA<ApiError<String>>());
    final failure =
        (postResult as ApiError<String>).failure as HttpStatusFailure;
    expect(failure.statusCode, 503);
    expect(posts.calls, 1);
  });

  test('retries a GET once on timeout or transport failure', () async {
    final timingOut = SequenceTransport(
      onCall: (call) => call == 1
          ? Completer<TransportResponse>().future
          : Future<TransportResponse>.value(response(200, 'ok')),
    );
    final timed = await ApiClient(timingOut).execute<String>(
      getRequest(timeout: const Duration(milliseconds: 20)),
      decode: utf8.decode,
    );
    expect((timed as ApiSuccess<String>).value, 'ok');
    expect(timingOut.calls, 2);

    final broken = SequenceTransport(
      onCall: (call) => call == 1
          ? Future<TransportResponse>.error(const TransportException('down'))
          : Future<TransportResponse>.value(response(200, 'back')),
    );
    final recovered = await ApiClient(
      broken,
    ).execute<String>(getRequest(), decode: utf8.decode);
    expect((recovered as ApiSuccess<String>).value, 'back');
    expect(broken.calls, 2);
  });

  test(
    'does not retry cancellation, decode errors, or unexpected throws',
    () async {
      final cancelled = CancellationToken()..cancel();
      final idle = ScriptedTransport([response(200, 'ok')]);
      final early = await ApiClient(
        idle,
      ).execute<String>(getRequest(), decode: utf8.decode, cancel: cancelled);
      expect((early as ApiError<String>).failure, isA<CancelledFailure>());
      expect(idle.calls, 0);

      final hanging = SequenceTransport(
        onCall: (_) => Completer<TransportResponse>().future,
      );
      final token = CancellationToken();
      final pending = ApiClient(hanging).execute<String>(
        getRequest(timeout: const Duration(seconds: 5)),
        decode: utf8.decode,
        cancel: token,
      );
      token.cancel();
      final mid = await pending;
      expect((mid as ApiError<String>).failure, isA<CancelledFailure>());
      expect(hanging.calls, 1);

      final malformed = ScriptedTransport([response(200, '{')]);
      final decoded = await ApiClient(
        malformed,
      ).execute<Object>(getRequest(), decode: jsonDecodeUtf8);
      expect((decoded as ApiError<Object>).failure, isA<DecodeFailure>());
      expect(malformed.calls, 1);

      final unexpected = ScriptedTransport.throws(StateError('bug'));
      final result = await ApiClient(
        unexpected,
      ).execute<String>(getRequest(), decode: utf8.decode);
      expect((result as ApiError<String>).failure, isA<UnexpectedFailure>());
      expect(unexpected.calls, 1);
    },
  );

  test('HttpTransport reads a loopback server', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() => server.close(force: true));
    server.listen((request) {
      request.response
        ..statusCode = 201
        ..write('created');
      request.response.close();
    });
    final transport = HttpTransport();
    addTearDown(transport.close);

    final result = await ApiClient(transport).execute<String>(
      ApiRequest(
        method: ApiMethod.get,
        uri: Uri.parse('http://127.0.0.1:${server.port}/created'),
      ),
      decode: utf8.decode,
    );

    expect((result as ApiSuccess<String>).value, 'created');
  });
}

Object jsonDecodeUtf8(List<int> body) {
  final decoded = jsonDecode(utf8.decode(body));
  if (decoded == null) {
    throw const FormatException('null json');
  }
  return decoded as Object;
}

TransportResponse response(int status, String body) {
  return TransportResponse(statusCode: status, body: utf8.encode(body));
}

class ScriptedTransport implements Transport {
  ScriptedTransport(this._script);

  ScriptedTransport.throws(Object error) : _script = [error];

  final List<Object> _script;
  int calls = 0;

  @override
  Future<TransportResponse> send(ApiRequest request) async {
    calls += 1;
    final next = _script.removeAt(0);
    if (next is TransportResponse) {
      return next;
    }
    throw next;
  }
}

class SequenceTransport implements Transport {
  SequenceTransport({required this.onCall});

  final Future<TransportResponse> Function(int call) onCall;
  int calls = 0;

  @override
  Future<TransportResponse> send(ApiRequest request) {
    calls += 1;
    return onCall(calls);
  }
}
