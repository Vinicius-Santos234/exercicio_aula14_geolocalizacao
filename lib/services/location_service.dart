import 'dart:async';

import 'package:geolocator/geolocator.dart';

import '../utils/fatec_matao.dart';

/// Tempo máximo de espera pela captura única.
const limiteDaCaptura = Duration(seconds: 15);

class LocationService {
  Future<Position> obterPosicaoAtual() async {
    await _validarServicoEPermissao();

    // No geolocator 14 o parâmetro desiredAccuracy do roteiro está obsoleto:
    // a precisão passa a ir dentro de LocationSettings.
    return await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        // Sem limite, uma busca sem resposta (sem sinal, ou só com a
        // localização aproximada liberada) deixava o loading girando e o
        // botão desabilitado para sempre.
        timeLimit: limiteDaCaptura,
      ),
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

  /// O roteiro abre o stream direto, sem checar GPS e permissão. Agora as
  /// mesmas validações da captura única rodam antes, e uma falha chega como
  /// erro do próprio stream (onError).
  Stream<Position> monitorarPosicao() async* {
    await _validarServicoEPermissao();

    yield* Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10,
      ),
    );
  }

  Future<void> _validarServicoEPermissao() async {
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
  }
}

/// Texto em português para os erros do GPS. As exceções do próprio geolocator
/// (ex.: GPS desligado durante o rastreamento) vêm com mensagem em inglês.
String mensagemDeErroGps(Object erro) {
  if (erro is LocationServiceDisabledException) {
    return 'O serviço de GPS foi desativado no dispositivo.';
  }
  if (erro is PermissionDeniedException) {
    return 'Permissão de localização negada pelo usuário.';
  }
  if (erro is TimeoutException) {
    return 'O GPS não respondeu em ${limiteDaCaptura.inSeconds} segundos. '
        'Tente de novo em um local aberto.';
  }
  return erro.toString().replaceAll('Exception: ', '');
}
