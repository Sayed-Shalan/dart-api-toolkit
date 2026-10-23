import 'api_request.dart';

class TransportResponse {
  const TransportResponse({
    required this.statusCode,
    required this.body,
    this.headers = const {},
  });

  final int statusCode;
  final List<int> body;
  final Map<String, String> headers;
}

/// Socket and HTTP failures thrown by a transport. [ApiClient] maps them to
/// [NetworkFailure] and does not let them escape [ApiClient.execute].
class TransportException implements Exception {
  const TransportException(this.cause);

  final Object cause;

  @override
  String toString() => 'TransportException: $cause';
}

abstract interface class Transport {
  Future<TransportResponse> send(ApiRequest request);
}
