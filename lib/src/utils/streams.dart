import 'dart:async';

/// A stream that can be listened to any number of times, sequentially or
/// concurrently: each `listen` call gets its own subscription to a fresh
/// stream from [factory].
///
/// Hand-rolled `async*` watch streams are single-subscription, so a reused
/// instance (cached across rebuilds, or handed to two widgets) crashes with
/// "Bad state: Stream has already been listened to". Wrapping them in this
/// class makes that impossible while keeping plain single-subscription
/// event delivery per listener.
class MultiListenStream<T> extends Stream<T> {
  MultiListenStream(this._factory);

  final Stream<T> Function() _factory;

  @override
  StreamSubscription<T> listen(void Function(T event)? onData,
          {Function? onError, void Function()? onDone, bool? cancelOnError}) =>
      _factory().listen(onData,
          onError: onError, onDone: onDone, cancelOnError: cancelOnError);
}
