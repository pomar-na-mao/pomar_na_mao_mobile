## Verificação automatizada

- Suíte direcionada de localização, Ocorrências, MIPD, atividades e Pulverização: 111 testes aprovados.
- `dart analyze`: nenhuma ocorrência.
- `openspec validate standardize-live-map-location --strict`: mudança válida.
- `flutter build apk --debug`: APK gerado com sucesso em `build/app/outputs/flutter-apk/app-debug.apk`.
- `git diff --check`: nenhuma inconsistência de whitespace.

## Verificação em dispositivo

- Pendente: caminhar com um dispositivo físico e confirmar a cadência percebida e a orientação da seta em Ocorrências, Pulverização, MIPD e ao menos uma atividade.
- Pendente: confirmar no mesmo percurso que Pomar e Estoque continuam sem iniciar localização ao vivo.
- A validação física permanece pendente porque exige movimento real e observação dos quatro fluxos; não foi inferida a partir dos testes automatizados.
