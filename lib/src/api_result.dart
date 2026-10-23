import 'api_failure.dart';

sealed class ApiResult<T> {
  const ApiResult();
}

final class ApiSuccess<T> extends ApiResult<T> {
  const ApiSuccess(this.value);

  final T value;
}

final class ApiError<T> extends ApiResult<T> {
  const ApiError(this.failure);

  final ApiFailure failure;
}
