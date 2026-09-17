## Why

O aplicativo ainda não oferece um ponto central para acessar as rotinas de manejo do pomar. Incluir a área Operações prepara a navegação para essas rotinas e disponibiliza inicialmente o fluxo de Inspeção, comunicando com clareza quais recursos ainda não estão liberados.

## What Changes

- Adiciona Operações à navegação inferior, entre Fazenda e Sobre.
- Cria uma tela Operações com cards para Inspeção, Pulverização, Irrigação, Colheita e Análise de Solo.
- Disponibiliza somente o card Inspeção, que abre uma tela própria identificada como Inspeção.
- Exibe Pulverização, Irrigação, Colheita e Análise de Solo como indisponíveis, com aparência, texto auxiliar e semântica acessível de bloqueio, sem executar navegação.
- Adota uma composição visual responsiva, com cores temáticas e ícones Material coerentes com cada operação.
- Amplia os testes de widgets para cobrir a ordem da navegação, a apresentação dos cards, os estados habilitado/bloqueado e a navegação para Inspeção.

## Capabilities

### New Capabilities

- `operations-menu`: Apresentação responsiva das operações agrícolas, estados de disponibilidade e acesso à tela de Inspeção.

### Modified Capabilities

- `main-navigation`: Inclusão do destino Operações entre Fazenda e Sobre e manutenção desse novo conjunto de destinos na navegação principal.

## Impact

- Altera o shell principal e seus testes de navegação.
- Adiciona widgets de apresentação para Operações e Inspeção sob uma nova feature Flutter.
- Usa somente componentes, ícones e temas Material já disponíveis no Flutter, sem nova dependência externa ou alteração de API/backend.
- Mantém o estado das telas principais por meio da estrutura de navegação já existente.
