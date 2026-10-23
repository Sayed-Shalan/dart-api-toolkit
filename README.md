# dart-api-toolkit

A small Dart library for one HTTP call at a time. It maps the outcomes that usually get string-matched — timeout, cancellation, transport failure, non-2xx, and decode errors — into a sealed result. It is not a Dio or `package:http` wrapper. The only I/O implementation uses `dart:io`.

Package name: `api_toolkit`. Version 0.1.0 is prepared and is not published to pub.dev.

## Public API

- `ApiRequest` — method, URI, encoded body, headers, timeout.
- `Transport` — send a request, return status and bytes, or throw `TransportException`.
- `ApiClient.execute` — returns `ApiSuccess<T>` or `ApiError<T>`. It does not throw those failures.
- `CancellationToken` — cooperative cancel.
- `HttpTransport` — loopback and real HTTP via `dart:io`.

## Retry

`ApiClient` retries a **GET** once, and only once, when the first attempt:

- times out, or
- throws `TransportException`, or
- returns HTTP 503.

POST, PUT, PATCH, and DELETE are not retried. A second failure is returned as-is. Cancellation and decode errors are not retried. 500 is not retried: repeating it hides a server bug. PUT is not treated as idempotent.

## Cancellation

Cancelling a token makes `execute` return `CancelledFailure` if the call has not already succeeded. `HttpTransport` does not abort the socket. The caller stops waiting; the request may still finish on the server. That limit is deliberate so the transport interface stays synchronous to implement in tests.

## Example

```bash
dart pub get
dart run example/main.dart
```

The example uses an in-memory transport, so it does not need a network.

## Tests

```bash
dart format --output=none --set-exit-if-changed .
dart analyze
dart test
```

## License

[MIT](LICENSE)
