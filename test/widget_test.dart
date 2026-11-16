// Testes da geolocalização da Aula 14.
//
// O GPS é simulado trocando GeolocatorPlatform.instance por um FakeGeolocator:
// o código do app continua chamando os métodos estáticos do Geolocator, mas as
// respostas (GPS ligado/desligado, permissão, posição e stream) vêm do fake.
// O url_launcher é simulado do mesmo jeito com UrlLauncherPlatform.instance.
// Cobrem o LocationService, a tela do roteiro, os três desafios e as correções.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator_platform_interface/geolocator_platform_interface.dart';
import 'package:url_launcher_platform_interface/link.dart';
import 'package:url_launcher_platform_interface/url_launcher_platform_interface.dart';

import 'package:pdm_aula14_geolocalizacao/main.dart';
import 'package:pdm_aula14_geolocalizacao/services/location_service.dart';
import 'package:pdm_aula14_geolocalizacao/services/mapa_service.dart';
import 'package:pdm_aula14_geolocalizacao/utils/fatec_matao.dart';
import 'package:pdm_aula14_geolocalizacao/utils/formatar_distancia.dart';
import 'package:pdm_aula14_geolocalizacao/widgets/indicador_precisao.dart';

Position _posicao({
  double latitude = -21.603312,
  double longitude = -48.365847,
  double precisao = 8,
  double altitude = 562.4,
}) {
  return Position(
    latitude: latitude,
    longitude: longitude,
    timestamp: DateTime(2026, 11, 16, 10, 30),
    accuracy: precisao,
    altitude: altitude,
    altitudeAccuracy: 0,
    heading: 0,
    headingAccuracy: 0,
    speed: 0,
    speedAccuracy: 0,
  );
}

class FakeGeolocator extends GeolocatorPlatform {
  bool servicoHabilitado = true;
  LocationPermission permissao = LocationPermission.whileInUse;
  LocationPermission respostaDoPedido = LocationPermission.whileInUse;
  int pedidosDePermissao = 0;

  Position posicao = _posicao();
  Completer<Position>? capturaPendente;
  LocationSettings? configuracaoDaCaptura;

  StreamController<Position>? stream;
  LocationSettings? configuracaoDoStream;
  int streamsAbertos = 0;
  int streamsCancelados = 0;

  @override
  Future<bool> isLocationServiceEnabled() async => servicoHabilitado;

  @override
  Future<LocationPermission> checkPermission() async => permissao;

  @override
  Future<LocationPermission> requestPermission() async {
    pedidosDePermissao++;
    permissao = respostaDoPedido;
    return permissao;
  }

  @override
  Future<Position> getCurrentPosition({
    LocationSettings? locationSettings,
  }) async {
    configuracaoDaCaptura = locationSettings;
    if (capturaPendente != null) {
      // Igual ao geolocator_android: o timeLimit vira um timeout no Future
      final limite = locationSettings?.timeLimit;
      final futuro = capturaPendente!.future;
      return limite == null ? futuro : futuro.timeout(limite);
    }
    return posicao;
  }

  @override
  Stream<Position> getPositionStream({LocationSettings? locationSettings}) {
    configuracaoDoStream = locationSettings;
    stream = StreamController<Position>(
      onListen: () => streamsAbertos++,
      onCancel: () => streamsCancelados++,
    );
    return stream!.stream;
  }
}

class FakeUrlLauncher extends UrlLauncherPlatform {
  final List<String> abertos = [];
  PreferredLaunchMode? ultimoModo;
  bool consegueAbrir = true;

  @override
  LinkDelegate? get linkDelegate => null;

  @override
  Future<bool> launchUrl(String url, LaunchOptions options) async {
    abertos.add(url);
    ultimoModo = options.mode;
    return consegueAbrir;
  }
}

late FakeGeolocator gps;
late FakeUrlLauncher navegador;

Future<void> _abrirApp(WidgetTester tester) async {
  await tester.pumpWidget(const MeuApp());
  await tester.pumpAndSettle();
}

Future<void> _capturar(WidgetTester tester) async {
  await tester.tap(find.text('Capturar Localização Atual'));
  await tester.pumpAndSettle();
}

Future<void> _iniciarRastreamento(WidgetTester tester) async {
  await tester.tap(find.text('Iniciar Rastreamento Contínuo'));
  await tester.pumpAndSettle();
}

Future<void> _emitir(WidgetTester tester, Position posicao) async {
  gps.stream!.add(posicao);
  await tester.pumpAndSettle();
}

bool _capturarHabilitado(WidgetTester tester) {
  return tester
      .widget<ButtonStyleButton>(
        find.ancestor(
          of: find.text('Capturar Localização Atual'),
          matching: find.byWidgetPredicate((w) => w is ButtonStyleButton),
        ),
      )
      .enabled;
}

Chip _chipDePrecisao(WidgetTester tester) {
  return tester.widget<Chip>(
    find.descendant(
      of: find.byType(IndicadorPrecisao),
      matching: find.byType(Chip),
    ),
  );
}

void main() {
  setUp(() {
    gps = FakeGeolocator();
    navegador = FakeUrlLauncher();
    GeolocatorPlatform.instance = gps;
    UrlLauncherPlatform.instance = navegador;
  });

  group('LocationService', () {
    test('GPS desligado lança a exceção do roteiro', () async {
      gps.servicoHabilitado = false;

      await expectLater(
        LocationService().obterPosicaoAtual(),
        throwsA(
          predicate(
            (e) => '$e'.contains(
              'O serviço de GPS está desativado no dispositivo.',
            ),
          ),
        ),
      );
      expect(gps.pedidosDePermissao, 0);
    });

    test('permissão negada no diálogo: pede uma vez e lança o aviso', () async {
      gps.permissao = LocationPermission.denied;
      gps.respostaDoPedido = LocationPermission.denied;

      await expectLater(
        LocationService().obterPosicaoAtual(),
        throwsA(
          predicate((e) => '$e'.contains('Permissão de localização negada')),
        ),
      );
      expect(gps.pedidosDePermissao, 1);
    });

    test(
      'deniedForever manda para as configurações sem pedir de novo',
      () async {
        gps.permissao = LocationPermission.deniedForever;

        await expectLater(
          LocationService().obterPosicaoAtual(),
          throwsA(predicate((e) => '$e'.contains('Altere nas configurações'))),
        );
        expect(gps.pedidosDePermissao, 0);
      },
    );

    test(
      'permissão concedida no diálogo devolve a posição em alta precisão',
      () async {
        gps.permissao = LocationPermission.denied;
        gps.respostaDoPedido = LocationPermission.whileInUse;

        final posicao = await LocationService().obterPosicaoAtual();

        expect(gps.pedidosDePermissao, 1);
        expect(posicao.latitude, -21.603312);
        expect(posicao.longitude, -48.365847);
        expect(gps.configuracaoDaCaptura?.accuracy, LocationAccuracy.high);
      },
    );

    test(
      'monitorarPosicao usa alta precisão e distanceFilter de 10 m',
      () async {
        final recebidas = <Position>[];
        final sub = LocationService().monitorarPosicao().listen(recebidas.add);
        await pumpEventQueue();

        expect(gps.configuracaoDoStream?.accuracy, LocationAccuracy.high);
        expect(gps.configuracaoDoStream?.distanceFilter, 10);

        gps.stream!.add(_posicao(latitude: -21.6));
        await pumpEventQueue();
        expect(recebidas.single.latitude, -21.6);

        await sub.cancel();
        expect(gps.streamsCancelados, 1);
      },
    );

    test('mensagemDeErroGps traduz as exceções do geolocator', () {
      expect(
        mensagemDeErroGps(const LocationServiceDisabledException()),
        'O serviço de GPS foi desativado no dispositivo.',
      );
      expect(
        mensagemDeErroGps(const PermissionDeniedException(null)),
        'Permissão de localização negada pelo usuário.',
      );
      expect(
        mensagemDeErroGps(TimeoutException(null)),
        'O GPS não respondeu em 15 segundos. Tente de novo em um local aberto.',
      );
      expect(mensagemDeErroGps(Exception('Falhou')), 'Falhou');
    });
  });

  group('Tela de check-in (roteiro)', () {
    testWidgets('antes da captura mostra só os botões', (tester) async {
      await _abrirApp(tester);

      expect(find.text('Check-in & GPS'), findsOneWidget);
      expect(find.text('Latitude'), findsNothing);
      expect(find.text('Capturar Localização Atual'), findsOneWidget);
      expect(find.text('Iniciar Rastreamento Contínuo'), findsOneWidget);
    });

    testWidgets('Capturar mostra o loading e depois as coordenadas', (
      tester,
    ) async {
      gps.capturaPendente = Completer<Position>();
      await _abrirApp(tester);

      await tester.tap(find.text('Capturar Localização Atual'));
      await tester.pump();
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      // Botão desabilitado enquanto a busca não termina
      expect(_capturarHabilitado(tester), isFalse);

      gps.capturaPendente!.complete(_posicao());
      await tester.pumpAndSettle();

      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(_capturarHabilitado(tester), isTrue);
      expect(find.text('-21.603312'), findsOneWidget);
      expect(find.text('-48.365847'), findsOneWidget);
      expect(find.text('Precisão: 8.0m | Alt: 562.4m'), findsOneWidget);
    });

    testWidgets('erro do serviço aparece no card vermelho sem "Exception:"', (
      tester,
    ) async {
      gps.servicoHabilitado = false;
      await _abrirApp(tester);

      await _capturar(tester);

      expect(
        find.text('O serviço de GPS está desativado no dispositivo.'),
        findsOneWidget,
      );
      expect(find.textContaining('Exception'), findsNothing);
      expect(find.text('Latitude'), findsNothing);
    });

    testWidgets(
      'rastreamento atualiza a cada posição e Parar cancela o stream',
      (tester) async {
        await _abrirApp(tester);

        await _iniciarRastreamento(tester);
        expect(find.text('Parar Rastreamento'), findsOneWidget);
        expect(gps.streamsAbertos, 1);

        await _emitir(
          tester,
          _posicao(latitude: -21.6001, longitude: -48.3601),
        );
        expect(find.text('-21.6001'), findsOneWidget);

        await _emitir(
          tester,
          _posicao(latitude: -21.6002, longitude: -48.3602),
        );
        expect(find.text('-21.6002'), findsOneWidget);
        expect(find.text('-21.6001'), findsNothing);

        await tester.tap(find.text('Parar Rastreamento'));
        await tester.pumpAndSettle();
        expect(find.text('Iniciar Rastreamento Contínuo'), findsOneWidget);
        expect(gps.streamsCancelados, 1);
      },
    );
  });

  group('Desafio Básico — medidor de precisão', () {
    test('faixas: verde < 15 m, amarelo de 15 a 50 m, vermelho > 50 m', () {
      expect(classificarPrecisao(3), NivelPrecisao.alta);
      expect(classificarPrecisao(14.9), NivelPrecisao.alta);
      expect(classificarPrecisao(15), NivelPrecisao.media);
      expect(classificarPrecisao(50), NivelPrecisao.media);
      expect(classificarPrecisao(50.1), NivelPrecisao.baixa);
      expect(classificarPrecisao(1200), NivelPrecisao.baixa);
    });

    for (final caso in [
      (8.0, Colors.green, 'Precisão alta · 8.0 m'),
      (32.0, Colors.yellow, 'Precisão média · 32.0 m'),
      (120.0, Colors.red, 'Precisão baixa · 120.0 m'),
    ]) {
      testWidgets('precisão de ${caso.$1} m gera o Chip ${caso.$3}', (
        tester,
      ) async {
        gps.posicao = _posicao(precisao: caso.$1);
        await _abrirApp(tester);
        await _capturar(tester);

        final chip = _chipDePrecisao(tester);
        expect(chip.backgroundColor, caso.$2.shade100);
        expect(find.text(caso.$3), findsOneWidget);
      });
    }

    testWidgets('o Chip muda de cor conforme o stream melhora a precisão', (
      tester,
    ) async {
      await _abrirApp(tester);
      await _iniciarRastreamento(tester);

      await _emitir(tester, _posicao(precisao: 85));
      expect(_chipDePrecisao(tester).backgroundColor, Colors.red.shade100);

      await _emitir(tester, _posicao(precisao: 5));
      expect(_chipDePrecisao(tester).backgroundColor, Colors.green.shade100);
    });
  });

  group('Desafio Intermediário — distância até a Fatec Matão', () {
    test('formatarDistancia usa metros com separador e converte em km', () {
      expect(formatarDistancia(0.4), '0 m');
      expect(formatarDistancia(850.2), '850 m');
      expect(formatarDistancia(12437.6), '12.438 m (≈ 12,4 km)');
      expect(formatarDistancia(1234567), '1.234.567 m (≈ 1.234,6 km)');
    });

    test(
      'distanciaAteFatec usa distanceBetween até as coordenadas da Fatec',
      () {
        final service = LocationService();

        expect(
          service.distanciaAteFatec(
            _posicao(
              latitude: fatecMataoLatitude,
              longitude: fatecMataoLongitude,
            ),
          ),
          0,
        );
        // 0,01° de latitude ao norte = 6.378.137 m × 0,01 × π/180 ≈ 1.113,2 m
        expect(
          service.distanciaAteFatec(
            _posicao(
              latitude: fatecMataoLatitude + 0.01,
              longitude: fatecMataoLongitude,
            ),
          ),
          closeTo(1113.2, 0.5),
        );
      },
    );

    testWidgets('o card mostra a distância formatada', (tester) async {
      gps.posicao = _posicao(
        latitude: fatecMataoLatitude + 0.01,
        longitude: fatecMataoLongitude,
      );
      await _abrirApp(tester);
      await _capturar(tester);

      expect(find.text('Distância até a Fatec Matão'), findsOneWidget);
      expect(find.text('1.113 m (≈ 1,1 km)'), findsOneWidget);
    });

    testWidgets('a distância é recalculada a cada posição do rastreamento', (
      tester,
    ) async {
      await _abrirApp(tester);
      await _iniciarRastreamento(tester);

      await _emitir(
        tester,
        _posicao(latitude: fatecMataoLatitude, longitude: fatecMataoLongitude),
      );
      expect(find.text('0 m'), findsOneWidget);

      await _emitir(
        tester,
        _posicao(
          latitude: fatecMataoLatitude + 0.01,
          longitude: fatecMataoLongitude,
        ),
      );
      expect(find.text('1.113 m (≈ 1,1 km)'), findsOneWidget);
    });
  });

  group('Desafio Avançado — Abrir no Mapa', () {
    test('o link segue o formato https://maps.google.com/?q=lat,lng', () {
      expect(
        MapaService().linkGoogleMaps(-21.603312, -48.365847).toString(),
        'https://maps.google.com/?q=-21.603312,-48.365847',
      );
    });

    testWidgets('o botão só aparece depois que há uma posição', (tester) async {
      await _abrirApp(tester);
      expect(find.text('Abrir no Mapa'), findsNothing);

      await _capturar(tester);
      expect(find.text('Abrir no Mapa'), findsOneWidget);
    });

    testWidgets('abre a posição atual fora do app pelo url_launcher', (
      tester,
    ) async {
      await _abrirApp(tester);
      await _capturar(tester);

      await tester.tap(find.text('Abrir no Mapa'));
      await tester.pumpAndSettle();

      expect(navegador.abertos, [
        'https://maps.google.com/?q=-21.603312,-48.365847',
      ]);
      expect(navegador.ultimoModo, PreferredLaunchMode.externalApplication);
      expect(find.text('Não foi possível abrir o mapa.'), findsNothing);
    });

    testWidgets('sem app para abrir o link avisa com SnackBar', (tester) async {
      navegador.consegueAbrir = false;
      await _abrirApp(tester);
      await _capturar(tester);

      await tester.tap(find.text('Abrir no Mapa'));
      await tester.pumpAndSettle();

      expect(find.text('Não foi possível abrir o mapa.'), findsOneWidget);
    });
  });

  group('Correções', () {
    testWidgets(
      'rastrear sem permissão: pede antes de abrir o stream e volta para Iniciar',
      (tester) async {
        gps.permissao = LocationPermission.denied;
        gps.respostaDoPedido = LocationPermission.denied;
        await _abrirApp(tester);

        await _iniciarRastreamento(tester);

        expect(gps.pedidosDePermissao, 1);
        expect(gps.stream, isNull);
        expect(
          find.text('Permissão de localização negada pelo usuário.'),
          findsOneWidget,
        );
        expect(find.text('Iniciar Rastreamento Contínuo'), findsOneWidget);
      },
    );

    testWidgets(
      'GPS desligado no meio do rastreamento encerra o stream com aviso em português',
      (tester) async {
        await _abrirApp(tester);
        await _iniciarRastreamento(tester);
        await _emitir(tester, _posicao());

        gps.stream!.addError(const LocationServiceDisabledException());
        await tester.pumpAndSettle();

        expect(
          find.text('O serviço de GPS foi desativado no dispositivo.'),
          findsOneWidget,
        );
        expect(find.text('Iniciar Rastreamento Contínuo'), findsOneWidget);
        expect(gps.streamsCancelados, 1);
        // A última posição válida continua na tela
        expect(find.text('-21.603312'), findsOneWidget);

        // Religar o rastreamento abre um stream novo e limpa o aviso
        await _iniciarRastreamento(tester);
        await _emitir(tester, _posicao(latitude: -21.7));
        expect(gps.streamsAbertos, 2);
        expect(
          find.text('O serviço de GPS foi desativado no dispositivo.'),
          findsNothing,
        );
      },
    );

    testWidgets('GPS sem resposta: após 15 s avisa e libera o botão de novo', (
      tester,
    ) async {
      gps.capturaPendente = Completer<Position>();
      await _abrirApp(tester);

      await tester.tap(find.text('Capturar Localização Atual'));
      await tester.pump();
      expect(gps.configuracaoDaCaptura?.timeLimit, const Duration(seconds: 15));

      await tester.pump(const Duration(seconds: 14));
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(_capturarHabilitado(tester), isFalse);

      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(
        find.text(
          'O GPS não respondeu em 15 segundos. Tente de novo em um local aberto.',
        ),
        findsOneWidget,
      );
      expect(_capturarHabilitado(tester), isTrue);
    });

    testWidgets(
      'fechar a tela durante a captura não chama setState depois do dispose',
      (tester) async {
        gps.capturaPendente = Completer<Position>();
        await _abrirApp(tester);
        await tester.tap(find.text('Capturar Localização Atual'));
        await tester.pump();

        await tester.pumpWidget(const SizedBox());
        gps.capturaPendente!.complete(_posicao());
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
      },
    );

    group('layout', () {
      void definirTela(WidgetTester tester, double altura) {
        tester.view.physicalSize = Size(360, altura);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
      }

      Future<void> tocarRolando(WidgetTester tester, String texto) async {
        await tester.scrollUntilVisible(
          find.text(texto),
          100,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.tap(find.text(texto));
        await tester.pumpAndSettle();
      }

      testWidgets('celular baixo (360 × 480) rola em vez de estourar', (
        tester,
      ) async {
        definirTela(tester, 480);
        await _abrirApp(tester);

        // Tela no estado mais cheio: card completo + aviso de erro
        await _capturar(tester);
        await tocarRolando(tester, 'Iniciar Rastreamento Contínuo');
        gps.stream!.addError(const LocationServiceDisabledException());
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(
          find.text('O serviço de GPS foi desativado no dispositivo.'),
          findsOneWidget,
        );

        await tocarRolando(tester, 'Iniciar Rastreamento Contínuo');
        expect(find.text('Parar Rastreamento'), findsOneWidget);
      });

      testWidgets('com altura sobrando os botões ficam no rodapé', (
        tester,
      ) async {
        definirTela(tester, 800);
        await _abrirApp(tester);

        final fimDoBotao = tester
            .getBottomLeft(find.text('Iniciar Rastreamento Contínuo'))
            .dy;
        expect(800 - fimDoBotao, lessThan(40));
      });
    });
  });
}
