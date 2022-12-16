typedef LazyPropCallback<T> = T Function();

class LazyProp<T> {
  final LazyPropCallback _callback;

  LazyProp(this._callback);

  T call() => _callback();
}
