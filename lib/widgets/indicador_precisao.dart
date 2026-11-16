import 'package:flutter/material.dart';

/// Faixas do Desafio Básico: verde abaixo de 15 m, amarelo de 15 a 50 m e
/// vermelho acima de 50 m.
enum NivelPrecisao {
  alta('Precisão alta', Colors.green, Icons.gps_fixed),
  media('Precisão média', Colors.yellow, Icons.gps_not_fixed),
  baixa('Precisão baixa', Colors.red, Icons.gps_off);

  const NivelPrecisao(this.rotulo, this.cor, this.icone);

  final String rotulo;
  final MaterialColor cor;
  final IconData icone;
}

NivelPrecisao classificarPrecisao(double metros) {
  if (metros < 15) return NivelPrecisao.alta;
  if (metros <= 50) return NivelPrecisao.media;
  return NivelPrecisao.baixa;
}

/// Chip colorido com a faixa de precisão da última leitura do GPS.
class IndicadorPrecisao extends StatelessWidget {
  const IndicadorPrecisao({super.key, required this.precisao});

  /// Raio de incerteza em metros (Position.accuracy).
  final double precisao;

  @override
  Widget build(BuildContext context) {
    final nivel = classificarPrecisao(precisao);
    // Tons escuros no texto e no ícone para manter o contraste, inclusive
    // sobre o amarelo.
    final corTexto = nivel.cor.shade900;

    return Chip(
      avatar: Icon(nivel.icone, color: corTexto, size: 18),
      label: Text(
        '${nivel.rotulo} · ${precisao.toStringAsFixed(1)} m',
        style: TextStyle(color: corTexto, fontWeight: FontWeight.w600),
      ),
      backgroundColor: nivel.cor.shade100,
      side: BorderSide(color: nivel.cor.shade700),
    );
  }
}
