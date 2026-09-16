# Pomar na mão

Aplicativo Flutter para visualizar o inventário do pomar e as plantas da fazenda em um mapa.

## Plataformas

Esta primeira versão suporta Android e iOS. O Google Maps da tela Fazenda não está configurado para web ou desktop.

## Requisitos

- Flutter 3.47.1 ou compatível
- Dart 3.13.1 ou compatível
- Android SDK para execução no Android
- Xcode e CocoaPods em macOS para execução no iOS

## Supabase

O aplicativo usa por padrão o projeto `https://uxschjkypkkzprbwuhxm.supabase.co` e sua publishable key pública. É possível substituir ambos no build:

```shell
flutter run \
  --dart-define=SUPABASE_URL=https://SEU_PROJETO.supabase.co \
  --dart-define=SUPABASE_PUBLISHABLE_KEY=SUA_PUBLISHABLE_KEY
```

A tabela `public.plants` deve estar com RLS habilitado e possuir uma política `SELECT` apropriada. Nunca coloque uma `service_role` key no aplicativo.

## Google Maps

Ative no Google Cloud as APIs Maps SDK for Android e Maps SDK for iOS. Restrinja a chave:

- Android: package `com.example.pomar_na_mao_mobile` e o SHA do certificado do build.
- iOS: bundle identifier `com.example.pomarNaMaoMobile`.

### Android

Adicione ao arquivo local e não versionado `android/local.properties`:

```properties
GOOGLE_MAPS_API_KEY=SUA_GOOGLE_MAPS_API_KEY
```

Também é possível fornecer `GOOGLE_MAPS_API_KEY` como variável de ambiente durante o build.

### iOS

Copie `ios/Flutter/GoogleMaps.xcconfig.example` para `ios/Flutter/GoogleMaps.xcconfig` e preencha:

```text
GOOGLE_MAPS_API_KEY=SUA_GOOGLE_MAPS_API_KEY
```

O arquivo com o valor real é ignorado pelo Git.

## Executar

```shell
flutter pub get
flutter run
```

Na primeira abertura da Fazenda, o aplicativo solicita permissão de localização. Se a permissão for negada ou o serviço estiver desligado, as plantas continuam visíveis no mapa.
