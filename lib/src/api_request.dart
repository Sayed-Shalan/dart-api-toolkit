enum ApiMethod { get, post, put, patch, delete }

/// A single call. [body] is already encoded. This library does not choose JSON.
class ApiRequest {
  const ApiRequest({
    required this.method,
    required this.uri,
    this.headers = const {},
    this.body,
    this.timeout = const Duration(seconds: 10),
  });

  final ApiMethod method;
  final Uri uri;
  final Map<String, String> headers;
  final List<int>? body;
  final Duration timeout;

  /// Only GET is treated as safe to send twice. PUT is not retried.
  bool get mayRetry => method == ApiMethod.get;
}
