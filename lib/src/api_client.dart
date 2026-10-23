import 'dart:async';

import 'api_failure.dart';
import 'api_request.dart';
import 'api_result.dart';
import 'cancellation.dart';
import 'transport.dart';

/// Sends one request through a [Transport].
///
/// A GET is attempted a second time only when the first attempt times out,
/// throws [TransportException], or returns HTTP 503. The second attempt is
/// not retried. POST, PUT, PATCH, and DELETE are never retried. Cancellation
/// is not retried.
class ApiClient {
  ApiClient(this._transport);

  final Transport _transport;

  Future<ApiResult<T>> execute<T>(
    ApiRequest request, {
    required T Function(List<int> body) decode,
    CancellationToken? cancel,
  }) {
    return _attempt(request, decode: decode, cancel: cancel, allowRetry: true);
  }

  Future<ApiResult<T>> _attempt<T>(
    ApiRequest request, {
    required T Function(List<int> body) decode,
    required CancellationToken? cancel,
    required bool allowRetry,
  }) async {
    if (cancel?.isCancelled ?? false) {
      return const ApiError(CancelledFailure());
    }

    final response = await _sendGuarded(request, cancel);

    switch (response) {
      case ApiSuccess(:final value):
        if (value.statusCode < 200 || value.statusCode >= 300) {
          final failure = HttpStatusFailure(
            statusCode: value.statusCode,
            body: value.body,
          );
          if (allowRetry && _canRetryStatus(request, value.statusCode)) {
            return _attempt(
              request,
              decode: decode,
              cancel: cancel,
              allowRetry: false,
            );
          }
          return ApiError(failure);
        }
        try {
          return ApiSuccess(decode(value.body));
        } catch (error) {
          return ApiError(DecodeFailure(error));
        }
      case ApiError(:final failure):
        if (allowRetry && _canRetryFailure(request, failure)) {
          return _attempt(
            request,
            decode: decode,
            cancel: cancel,
            allowRetry: false,
          );
        }
        return ApiError(failure);
    }
  }

  Future<ApiResult<TransportResponse>> _sendGuarded(
    ApiRequest request,
    CancellationToken? cancel,
  ) async {
    try {
      return ApiSuccess(await _send(request, cancel));
    } on CancelledException {
      return const ApiError(CancelledFailure());
    } on TimeoutException {
      return const ApiError(TimeoutFailure());
    } on TransportException catch (error) {
      return ApiError(NetworkFailure(error.cause));
    } catch (error) {
      return ApiError(UnexpectedFailure(error));
    }
  }

  Future<TransportResponse> _send(
    ApiRequest request,
    CancellationToken? cancel,
  ) {
    if (cancel?.isCancelled ?? false) {
      return Future<TransportResponse>.error(const CancelledException());
    }

    final completer = Completer<TransportResponse>();
    final timer = Timer(request.timeout, () {
      if (!completer.isCompleted) {
        completer.completeError(TimeoutException('timed out', request.timeout));
      }
    });

    void completeError(Object error, [StackTrace? stack]) {
      if (!completer.isCompleted) {
        completer.completeError(error, stack ?? StackTrace.current);
      }
    }

    cancel?.cancelled.then((_) => completeError(const CancelledException()));
    _transport.send(request).then((value) {
      if (cancel?.isCancelled ?? false) {
        completeError(const CancelledException());
        return;
      }
      if (!completer.isCompleted) {
        completer.complete(value);
      }
    }, onError: completeError);

    return completer.future.whenComplete(timer.cancel);
  }

  bool _canRetryFailure(ApiRequest request, ApiFailure failure) {
    if (!request.mayRetry || failure is CancelledFailure) {
      return false;
    }
    return failure is TimeoutFailure || failure is NetworkFailure;
  }

  bool _canRetryStatus(ApiRequest request, int statusCode) {
    return request.mayRetry && statusCode == 503;
  }
}
