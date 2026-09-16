## 1. Preparação e configuração

- [ ] 1.1 Confirmar as versões instaladas de Flutter/Dart e os identificadores Android/iOS do projeto, registrando o resultado e verificando que `flutter doctor` não aponta bloqueios para os alvos móveis.
- [x] 1.2 Inspecionar via MCP Supabase a tabela `public.plants`, suas colunas, RLS e políticas `SELECT`, verificando que a publishable key consegue ler os registros sem uso de credencial privilegiada.
- [x] 1.3 Adicionar `supabase_flutter`, `google_maps_flutter` e `geolocator` em versões estáveis compatíveis, verificando que `flutter pub get` conclui sem conflitos.
- [x] 1.4 Criar a estrutura de diretórios MVVM por funcionalidade em `lib/` e a composição de dependências em `core/app`, verificando que cada ViewModel, contrato, modelo e implementação de dados reside na camada planejada.

## 2. Supabase e dados de plantas

- [x] 2.1 Criar configuração de build para o Project URL e a publishable key do Supabase, documentar como fornecê-los e verificar que nenhuma service-role key ou segredo privilegiado foi adicionado ao repositório.
- [x] 2.2 Inicializar o Supabase antes do aplicativo e injetar o cliente nas dependências, verificando em execução que a inicialização conclui sem erro com o projeto `uxschjkypkkzprbwuhxm`.
- [x] 2.3 Implementar o modelo `Plant` cobrindo o schema fornecido e o mapeamento tolerante de campos opcionais, verificando manualmente o mapeamento de uma linha real retornada pelo Supabase.
- [x] 2.4 Implementar o contrato e o repositório Supabase de plantas com leitura de `public.plants`, verificando que todos os registros retornados incluem ao menos `id`, `latitude` e `longitude` corretos.

## 3. Navegação principal

- [x] 3.1 Criar o shell principal com `NavigationBar` e `IndexedStack` nas opções Inventário, Fazenda e Sobre, verificando que Inventário abre selecionado e a barra permanece visível nas três telas.
- [x] 3.2 Criar as Views identificáveis e sem conteúdo funcional de Inventário e Sobre, verificando que ambas abrem sem erro e sem conteúdo fictício obrigatório.
- [x] 3.3 Conectar a seleção da barra às três Views preservadas no `IndexedStack`, verificando manualmente que cada toque atualiza tela e seleção sem recriar o estado da Fazenda.

## 4. Localização e mapa da fazenda

- [ ] 4.1 Implementar o serviço de localização com verificação do serviço, solicitação de permissão e obtenção da posição, verificando em dispositivo/emulador os estados autorizado, negado e serviço desativado.
- [ ] 4.2 Implementar `FarmMapViewModel` com estados de carregamento, sucesso, vazio, erro/retry e localização, verificando por inspeção em execução que cada resposta externa produz o estado de UI correspondente.
- [x] 4.3 Criar a View Fazenda com Google Maps interativo e estados sobrepostos de carregamento, vazio e erro com retry, verificando que uma falha de consulta não remove nem trava o mapa.
- [x] 4.4 Converter todas as plantas carregadas em marcadores identificados por `id`, verificando que a quantidade e as coordenadas dos marcadores correspondem às linhas retornadas por `public.plants`.
- [x] 4.5 Exibir a camada de posição do usuário somente após autorização e mostrar feedback quando indisponível, verificando que negar a permissão não impede a exibição dos marcadores das plantas.
- [ ] 4.6 Implementar o enquadramento da câmera para múltiplas plantas, planta única, apenas usuário e região padrão, verificando manualmente os quatro cenários sem falha do mapa.

## 5. Configuração móvel e validação

- [x] 5.1 Configurar no Android a chave Google Maps por configuração local/de build e as permissões de localização, verificando que o mapa carrega em um build Android sem chave versionada indevidamente.
- [ ] 5.2 Configurar no iOS a chave Google Maps por configuração local/de build, a inicialização do SDK e as descrições de uso da localização, verificando que o mapa carrega em um build iOS sem chave versionada indevidamente.
- [x] 5.3 Documentar no README as variáveis/chaves necessárias, restrições recomendadas no Google Cloud, plataformas suportadas e comandos de execução, verificando as instruções a partir de uma configuração local limpa.
- [ ] 5.4 Executar formatação e `flutter analyze`, corrigindo todos os problemas introduzidos e verificando término sem erros.
- [ ] 5.5 Validar manualmente em Android e iOS o fluxo completo de navegação, leitura real de plantas, marcadores, retry, estados vazio/erro e localização permitida/negada, registrando quaisquer limitações encontradas.
