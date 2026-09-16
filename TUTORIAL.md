# Tutorial: Criando o App "Pomar na Mão" do Zero

Este documento é um guia passo a passo para que você possa reescrever este projeto do zero e aprender os conceitos básicos do Flutter durante o processo.

## Passo 1: Criando o Projeto Base

Para começar, crie um novo projeto Flutter. No seu terminal, execute:

```bash
flutter create pomar_na_mao_mobile
cd pomar_na_mao_mobile
```

Isso criará a estrutura inicial de pastas e o arquivo `lib/main.dart` padrão com o aplicativo contador.

## Passo 2: Adicionando Dependências

Nosso aplicativo utiliza algumas bibliotecas importantes (pacotes) que facilitam a integração com serviços externos. Adicione as seguintes dependências ao seu `pubspec.yaml` (ou rode os comandos abaixo):

```bash
flutter pub add supabase_flutter
flutter pub add google_maps_flutter
flutter pub add geolocator
flutter pub add video_player
```

- **supabase_flutter**: Para conectar com o banco de dados Supabase.
- **google_maps_flutter**: Para renderizar o mapa da fazenda.
- **geolocator**: Para obter a localização atual do dispositivo.
- **video_player**: Para reproduzir vídeos institucionais ou tutoriais.

## Passo 3: Entendendo e Criando a Estrutura de Pastas

Uma boa arquitetura é essencial. No seu projeto, apague o conteúdo da pasta `lib/` e crie a seguinte estrutura:

```text
lib/
├── app/          # Configurações globais do app (temas, rotas)
├── core/         # Código compartilhado (injeção de dependências, constantes)
├── features/     # Funcionalidades do app separadas por domínio
│   ├── about/    # Tela Sobre (informações do app/vídeos)
│   ├── farm/     # Tela da Fazenda (Google Maps e Geolocalização)
│   └── inventory/# Tela de Inventário (Lista de Plantas via Supabase)
└── main.dart     # Ponto de entrada do aplicativo
```

### O que você aprende aqui:
- **Modularização**: Separar o código em módulos (`features`) facilita a manutenção.

## Passo 4: Configurando o Ponto de Entrada (main.dart)

O arquivo `main.dart` é o primeiro a ser executado. Ele deve inicializar as configurações vitais antes de rodar a interface.

Crie o arquivo `lib/main.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() async {
  // Garante que os bindings do Flutter estejam iniciados antes do runApp
  WidgetsFlutterBinding.ensureInitialized();
  
  // Inicialização do Supabase (substitua com suas chaves depois)
  final supabase = SupabaseClient(
    'SUA_URL_SUPABASE',
    'SUA_CHAVE_PUBLICA_SUPABASE',
  );

  runApp(PomarNaMaoApp());
}

class PomarNaMaoApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Pomar na Mão',
      theme: ThemeData(
        primarySwatch: Colors.green,
      ),
      home: Scaffold(
        appBar: AppBar(title: const Text('Pomar na Mão')),
        body: const Center(child: Text('Bem-vindo ao Pomar!')),
      ),
    );
  }
}
```

### O que você aprende aqui:
- `main()`: A função raiz.
- `WidgetsFlutterBinding.ensureInitialized()`: Necessário quando rodamos código assíncrono (como instanciar o Supabase) antes do `runApp`.
- `StatelessWidget` e `MaterialApp`: Componentes fundamentais para construir a UI.

## Passo 5: Implementando as Funcionalidades (Features)

Agora, o objetivo é criar as telas (Widgets) dentro da pasta `features/`.

### 1. Inventário (`features/inventory`)
- Crie um arquivo `inventory_page.dart`.
- Utilize um `StatefulWidget` para gerenciar o estado da lista.
- Aprenda a usar o `FutureBuilder` ou `StreamBuilder` para buscar e exibir dados da tabela `plants` usando a instância do `SupabaseClient`.
- Use um `ListView.builder` para renderizar as plantas na tela de forma otimizada.

### 2. Fazenda (`features/farm`)
- Crie a tela `farm_page.dart`.
- Adicione o widget `GoogleMap`.
- Aprenda a lidar com permissões de localização utilizando o pacote `geolocator`.
- Exiba a posição do usuário no mapa e crie marcadores (Markers) para representar as plantas no mapa.

### 3. Sobre (`features/about`)
- Crie a tela `about_page.dart`.
- Utilize o pacote `video_player` para renderizar um vídeo (você precisará gerenciar o estado de play/pause do player).
- Use `StatefulWidget` para iniciar o `VideoPlayerController` no método `initState()` e descartá-lo no método `dispose()`.

## Passo 6: Navegação entre Telas

No Flutter, você pode navegar entre as telas usando o `Navigator`. Crie uma `BottomNavigationBar` (Barra de navegação inferior) no seu `PomarNaMaoApp` ou em uma tela base `HomePage` para alternar facilmente entre as telas de **Inventário**, **Fazenda** e **Sobre**.

## Passo 7: Configurando as Chaves Nativas (APIs)

Para que o Google Maps funcione, você precisa mexer no código nativo do Android e do iOS.

- **Android**: Edite o arquivo `android/local.properties` (ou o `AndroidManifest.xml`) para adicionar sua `GOOGLE_MAPS_API_KEY`.
- **iOS**: Modifique o arquivo `ios/Runner/AppDelegate.swift` e crie arquivos como `GoogleMaps.xcconfig` para prover a chave da API.

*Revise o arquivo `README.md` original do projeto para os passos exatos de configuração de chaves do Supabase e Google Maps.*

## Passo 8: Rodando e Testando

Com tudo conectado, execute o app no seu emulador ou dispositivo físico:

```bash
flutter run
```

### Dicas de Ouro para Aprender Flutter:
1. **Tudo é um Widget**: Desde botões até o padding (espaçamento). 
2. **Stateful vs Stateless**: Use `StatelessWidget` se a tela não muda (ex: tela de sobre com texto fixo). Use `StatefulWidget` se a tela muda de acordo com interações ou dados da internet.
3. **Hot Reload**: Aperte "r" no terminal (ou o raiozinho na IDE) para ver suas mudanças quase instantaneamente sem perder o estado atual do app.

---
**Desafio final:** Depois de montar as estruturas básicas, tente comparar o seu código criado do zero com o código existente nesta pasta para ver como as melhores práticas (como injeção de dependências em `core/di`) foram implementadas neste projeto!
