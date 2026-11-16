/// Distância em metros no padrão brasileiro, com a conversão em km quando
/// passa de 1.000 m. Ex.: `850 m` e `12.438 m (≈ 12,4 km)`.
String formatarDistancia(double metros) {
  final inteiro = metros.round();
  final emMetros = '${_separarMilhar(inteiro)} m';
  if (inteiro < 1000) return emMetros;

  final partes = (metros / 1000).toStringAsFixed(1).split('.');
  final emKm = '${_separarMilhar(int.parse(partes[0]))},${partes[1]} km';
  return '$emMetros (≈ $emKm)';
}

String _separarMilhar(int valor) {
  final digitos = valor.toString();
  final buffer = StringBuffer();
  for (var i = 0; i < digitos.length; i++) {
    if (i > 0 && (digitos.length - i) % 3 == 0) buffer.write('.');
    buffer.write(digitos[i]);
  }
  return buffer.toString();
}
