import 'dart:io';

import 'api_request.dart';
import 'transport.dart';

/// `dart:io` transport. Flutter web is not supported.
class HttpTransport implements Transport {
  HttpTransport({HttpClient? client}) : _client = client ?? HttpClient();

  final HttpClient _client;

  @override
  Future<TransportResponse> send(ApiRequest request) async {
    try {
      final ioRequest = await _client.openUrl(
        _method(request.method),
        request.uri,
      );
      request.headers.forEach(ioRequest.headers.set);
      final body = request.body;
      if (body != null) {
        ioRequest.add(body);
      }
      final response = await ioRequest.close();
      final bytes = await response.fold<List<int>>(<int>[], (collected, chunk) {
        collected.addAll(chunk);
        return collected;
      });
      return TransportResponse(statusCode: response.statusCode, body: bytes);
    } on SocketException catch (error) {
      throw TransportException(error);
    } on HttpException catch (error) {
      throw TransportException(error);
    }
  }

  void close({bool force = false}) => _client.close(force: force);

  String _method(ApiMethod method) {
    return switch (method) {
      ApiMethod.get => 'GET',
      ApiMethod.post => 'POST',
      ApiMethod.put => 'PUT',
      ApiMethod.patch => 'PATCH',
      ApiMethod.delete => 'DELETE',
    };
  }
}
