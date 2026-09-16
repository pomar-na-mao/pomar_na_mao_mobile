## 1. Layout da tela Sobre

- [x] 1.1 Substituir o corpo vazio de `AboutView` por um layout rolável com título, hierarquia visual e espaçamento adequado, verificando em execução que a tela abre pelo menu Sobre sem overflow.
- [x] 1.2 Criar uma seção visual para Pomar na mão com nome e descrição institucional fornecida, verificando que o texto aparece integralmente e com contraste legível.
- [x] 1.3 Criar uma seção visual para Prímora com nome, indicação de parceria e descrição institucional fornecida, verificando que o texto aparece integralmente e com contraste legível.

## 2. Responsividade e integração

- [x] 2.1 Garantir que a tela Sobre usa `SingleChildScrollView` ou comportamento equivalente para telas pequenas, verificando que o conteúdo não é cortado quando a altura disponível é reduzida.
- [x] 2.2 Manter a navegação inferior existente sem alteração funcional, verificando que Inventário, Fazenda e Sobre continuam acessíveis e com seleção correta.
- [x] 2.3 Executar formatação e análise estática, verificando que `dart analyze` termina sem issues introduzidas pela mudança.
- [x] 2.4 Gerar ao menos um build Android de validação, verificando que `:app:assembleDebug` ou `:app:assembleRelease` conclui com sucesso.
