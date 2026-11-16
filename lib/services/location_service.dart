import 'package:geolocator/geolocator.dart';

import '../utils/fatec_matao.dart';

class LocationService {
  Future<Position> obterPosicaoAtual() async {
    bool servicoHabilitado = await Geolocator.isLocationServiceEnabled();
    if (!servicoHabilitado) {
      throw Exception('O serviço de GPS está desativado no dispositivo.');
    }

    LocationPermission permissao = await Geolocator.checkPermission();
    if (permissao == LocationPermission.denied) {
      permissao = await Geolocator.requestPermission();
      if (permissao == LocationPermission.denied) {
        throw Exception('Permissão de localização negada pelo usuário.');
      }
    }

    if (permissao == LocationPermission.deniedForever) {
      throw Exception(
        'Permissões negadas permanentemente. Altere nas configurações.',
      );
    }

    // No geolocator 14 o parâmetro desiredAccuracy do roteiro está obsoleto:
    // a precisão passa a ir dentro de LocationSettings.
    return await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
    );
  }

  /// Desafio Intermediário: distância em linha reta (metros) da posição
  /// informada até a Fatec Matão.
  double distanciaAteFatec(Position posicao) {
    return Geolocator.distanceBetween(
      posicao.latitude,
      posicao.longitude,
      fatecMataoLatitude,
      fatecMataoLongitude,
    );
  }

  Stream<Position> monitorarPosicao() {
    return Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10,
      ),
    );
  }
}
