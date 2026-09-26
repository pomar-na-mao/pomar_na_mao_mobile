## Purpose

O provimento de configurações multi-tenant permite parametrizar credenciais de conexão ao Supabase e dados de propriedades/cultivos para exibição na tela de Inventário por cliente do sistema.

## ADDED Requirements

### Requirement: Parametrização dos Dados da Propriedade e Cultivo no Inventário

O sistema DEVE permitir a configuração e parametrização dos dados de exibição do card Visão da Propriedade (como nome da propriedade, área total, cultura principal) e do card Configurações do Cultivo (como espaçamento, classificação, densidade de plantas e variedades) de acordo com o cliente (tenant) selecionado.

#### Scenario: Carregamento do perfil de propriedade e cultivo parametrizado
- **WHEN** o usuário abre a tela de Inventário para um cliente específico selecionado no ambiente/configuração
- **THEN** o sistema exibe os dados do card Visão da Propriedade e do card Configurações do Cultivo correspondentes às definições do cliente selecionado

#### Scenario: Alternância entre múltiplos clientes
- **WHEN** o aplicativo é iniciado com um perfil de cliente/tenant distinto no arquivo de configuração ou build flavor
- **THEN** a tela de Inventário renderiza as informações de propriedade e cultivo do cliente selecionado sem modificar a estrutura do componente visual

### Requirement: Parametrização das Credenciais do Supabase por Cliente

O sistema DEVE carregar a `supabaseUrl` e a `supabasePublishableKey` a partir de uma fonte de configuração parametrizável (variáveis de ambiente, build defines ou perfis de configuração por tenant), possibilitando que cada cliente utilize sua própria instância do Supabase.

#### Scenario: Inicialização do Supabase com credenciais do cliente ativo
- **WHEN** a aplicação inicializa no método principal (`main`)
- **THEN** a conexão com o Supabase é estabelecida utilizando a `supabaseUrl` e `supabasePublishableKey` configuradas para o cliente ativo

#### Scenario: Ausência de credencial customizada
- **WHEN** nenhuma credencial customizada por cliente for fornecida em tempo de execução
- **THEN** o sistema utiliza os valores padrão configurados com fallback seguro no `AppConfig`
