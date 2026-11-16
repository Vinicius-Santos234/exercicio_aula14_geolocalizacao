import 'package:url_launcher/url_launcher.dart';

/// Desafio Avançado: abre a posição capturada no Google Maps.
class MapaService {
  /// Link no formato pedido pelo roteiro: https://maps.google.com/?q=lat,lng
  Uri linkGoogleMaps(double latitude, double longitude) {
    return Uri.parse('https://maps.google.com/?q=$latitude,$longitude');
  }

  /// Abre o link fora do app (aplicativo do Maps ou navegador).
  /// Devolve false quando nenhum aplicativo consegue tratar o link.
  Future<bool> abrirNoMapa(double latitude, double longitude) async {
    try {
      return await launchUrl(
        linkGoogleMaps(latitude, longitude),
        mode: LaunchMode.externalApplication,
      );
    } catch (_) {
      return false;
    }
  }
}
