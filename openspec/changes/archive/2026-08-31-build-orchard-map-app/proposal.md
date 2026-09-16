## Why

O projeto Flutter ainda está vazio e precisa de uma base funcional para o aplicativo Pomar na mão. A primeira versão deve estabelecer a navegação principal e permitir que o usuário visualize, em contexto geográfico, as plantas cadastradas no Supabase junto de sua própria posição.

## What Changes

- Criar uma estrutura de aplicativo Flutter com três destinos acessíveis por barra de navegação inferior: Inventário, Fazenda e Sobre.
- Disponibilizar telas iniciais vazias para Inventário e Sobre, prontas para evolução futura.
- Criar a tela Fazenda com Google Maps, marcadores para todas as linhas válidas da tabela `public.plants` e indicação da posição atual do usuário quando autorizada e disponível.
- Configurar a integração do aplicativo com o projeto Supabase informado para leitura das plantas.
- Organizar o código conforme a arquitetura MVVM recomendada para Flutter, separando UI, estado/lógica de apresentação, modelos e acesso a dados.
- Configurar as integrações nativas necessárias ao Google Maps e à localização nos aplicativos Android e iOS.
- Não incluir testes unitários nesta mudança.

## Capabilities

### New Capabilities

- `main-navigation`: Estrutura principal do aplicativo com as abas Inventário, Fazenda e Sobre e preservação do destino selecionado.
- `farm-map`: Mapa da fazenda que carrega plantas do Supabase, representa suas coordenadas e exibe a posição do usuário quando possível.

### Modified Capabilities

Nenhuma.

## Impact

- Código Flutter em `lib/`, reorganizado em camadas MVVM e funcionalidades por domínio.
- Dependências Flutter para Supabase, Google Maps, gerenciamento de estado e geolocalização.
- Configurações Android e iOS para chave do Google Maps e permissões de localização.
- Projeto Supabase `uxschjkypkkzprbwuhxm`, especialmente a tabela `public.plants` e suas políticas de acesso de leitura.
- A chave publicável do Supabase pode ser distribuída no cliente; a chave do Google Maps deverá ser restringida aos identificadores dos aplicativos nas plataformas suportadas.
