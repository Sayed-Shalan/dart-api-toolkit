/// Failures produced by [ApiClient]. The client returns these; it does not throw them.
sealed class ApiFailure {
  const ApiFailure();
}

final class CancelledFailure extends ApiFailure {
  const CancelledFailure();
}

final class TimeoutFailure extends ApiFailure {
  const TimeoutFailure();
}

final class NetworkFailure extends ApiFailure {
  const NetworkFailure(this.cause);

  final Object cause;
}

final class HttpStatusFailure extends ApiFailure {
  const HttpStatusFailure({required this.statusCode, required this.body});

  final int statusCode;
  final List<int> body;
}

final class DecodeFailure extends ApiFailure {
  const DecodeFailure(this.cause);

  final Object cause;
}

final class UnexpectedFailure extends ApiFailure {
  const UnexpectedFailure(this.cause);

  final Object cause;
}
