import 'dart:async';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import '../services/location_service.dart';
import '../services/mapa_service.dart';
import '../utils/formatar_distancia.dart';
import '../widgets/indicador_precisao.dart';

class GeolocalizacaoScreen extends StatefulWidget {
  const GeolocalizacaoScreen({super.key});

  @override
  State<GeolocalizacaoScreen> createState() => _GeolocalizacaoScreenState();
}

class _GeolocalizacaoScreenState extends State<GeolocalizacaoScreen> {
  final _locationService = LocationService();
  final _mapaService = MapaService();
  Position? _posicaoAtual;
  bool _carregando = false;
  String? _mensagemErro;
  StreamSubscription<Position>? _positionStreamSub;
  bool _rastreando = false;

  Future<void> _buscarLocalizacao() async {
    setState(() {
      _carregando = true;
      _mensagemErro = null;
    });
    try {
      final posicao = await _locationService.obterPosicaoAtual();
      setState(() => _posicaoAtual = posicao);
    } catch (e) {
      setState(
        () => _mensagemErro = e.toString().replaceAll('Exception: ', ''),
      );
    } finally {
      setState(() => _carregando = false);
    }
  }

  void _alternarRastreamento() {
    if (_rastreando) {
      _positionStreamSub?.cancel();
      setState(() => _rastreando = false);
    } else {
      setState(() => _rastreando = true);
      _positionStreamSub = _locationService.monitorarPosicao().listen(
        (pos) => setState(() => _posicaoAtual = pos),
        onError: (err) => setState(() => _mensagemErro = err.toString()),
      );
    }
  }

  Future<void> _abrirNoMapa() async {
    final posicao = _posicaoAtual!;
    final abriu = await _mapaService.abrirNoMapa(
      posicao.latitude,
      posicao.longitude,
    );
    if (!abriu && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Não foi possível abrir o mapa.')),
      );
    }
  }

  @override
  void dispose() {
    _positionStreamSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Check-in & GPS'), centerTitle: true),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            if (_carregando) const CircularProgressIndicator(),
            if (_mensagemErro != null)
              Card(
                color: Colors.red.shade100,
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Text(
                    _mensagemErro!,
                    style: const TextStyle(color: Colors.red),
                  ),
                ),
              ),
            if (_posicaoAtual != null) ...[
              Card(
                elevation: 3,
                child: Column(
                  children: [
                    ListTile(
                      leading: const Icon(
                        Icons.my_location,
                        color: Colors.blue,
                      ),
                      title: const Text('Latitude'),
                      subtitle: Text('${_posicaoAtual!.latitude}'),
                    ),
                    ListTile(
                      leading: const Icon(
                        Icons.location_on,
                        color: Colors.green,
                      ),
                      title: const Text('Longitude'),
                      subtitle: Text('${_posicaoAtual!.longitude}'),
                    ),
                    ListTile(
                      leading: const Icon(Icons.speed, color: Colors.orange),
                      title: const Text('Precisão / Altitude'),
                      subtitle: Text(
                        'Precisão: ${_posicaoAtual!.accuracy.toStringAsFixed(1)}m | Alt: ${_posicaoAtual!.altitude.toStringAsFixed(1)}m',
                      ),
                    ),
                    // Desafio Intermediário: distância até a Fatec Matão
                    ListTile(
                      leading: const Icon(Icons.school, color: Colors.purple),
                      title: const Text('Distância até a Fatec Matão'),
                      subtitle: Text(
                        formatarDistancia(
                          _locationService.distanciaAteFatec(_posicaoAtual!),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                      child: Wrap(
                        alignment: WrapAlignment.center,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 12,
                        runSpacing: 8,
                        children: [
                          // Desafio Básico: medidor visual da precisão
                          IndicadorPrecisao(precisao: _posicaoAtual!.accuracy),
                          // Desafio Avançado: abre a posição no Google Maps
                          FilledButton.tonalIcon(
                            onPressed: _abrirNoMapa,
                            icon: const Icon(Icons.map),
                            label: const Text('Abrir no Mapa'),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const Spacer(),
            ElevatedButton.icon(
              onPressed: _carregando ? null : _buscarLocalizacao,
              icon: const Icon(Icons.gps_fixed),
              label: const Text('Capturar Localização Atual'),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: _alternarRastreamento,
              icon: Icon(_rastreando ? Icons.stop : Icons.play_arrow),
              label: Text(
                _rastreando
                    ? 'Parar Rastreamento'
                    : 'Iniciar Rastreamento Contínuo',
              ),
            ),
          ],
        ),
      ),
    );
  }
}
