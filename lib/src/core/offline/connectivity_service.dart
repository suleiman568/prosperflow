import 'package:connectivity_plus/connectivity_plus.dart';

class ConnectivityService {
  ConnectivityService({Connectivity? connectivity})
    : _connectivity = connectivity ?? Connectivity();

  final Connectivity _connectivity;

  Future<bool> isOnline() async {
    return _hasConnection(await _connectivity.checkConnectivity());
  }

  Stream<bool> onOnlineStatusChanged() async* {
    yield await isOnline();
    yield* _connectivity.onConnectivityChanged.map(_hasConnection);
  }

  bool _hasConnection(List<ConnectivityResult> results) {
    return !results.contains(ConnectivityResult.none);
  }
}
