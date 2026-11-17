## Verificação automatizada

- `operations_view_test.dart`, `inspection_widgets_test.dart`, `inspection_map_camera_test.dart` e `user_map_navigation_test.dart`: 37 testes aprovados em conjunto, incluindo o rótulo `Ocorrências` no card e no topo da tela.
- `dart analyze`: nenhuma ocorrência.
- A suíte ampla `test/features/operations` executou os testes afetados com sucesso, mas conserva duas falhas preexistentes em `inspection_database_test.dart`: os cenários de migração ainda esperam versão 10, enquanto o banco atual abre na versão 12. A mudança não altera banco nem migrações.

## Verificação em dispositivo

- Dispositivo: Samsung SM-S926B, Android 17 (API 37), build debug instalada em 2026-11-16.
- A build instalada antecede a correção final da nomenclatura para `Ocorrências`; essa correção está coberta pelos testes de widget e será revalidada na próxima instalação em dispositivo.
- Confirmado que o mapa pode ser deslocado para longe do usuário. Com o stream GPS ativo, capturas realizadas logo após o gesto e seis segundos depois produziram o mesmo SHA-256 (`CE1E3E1F3D42F44906D07475AFDE44DF11D6495EB62F550FE0294EF54677F705`), demonstrando que a câmera não retornou automaticamente.
- Confirmado que `Minha localização` recentraliza a câmera na posição GPS e exibe o marcador neutro quando não há rumo confiável.
- Pendente: validar visualmente a rotação da seta durante deslocamento físico. O aparelho permaneceu parado e reportou velocidade zero; por isso o fallback neutro foi o comportamento correto. Rumos cardeais, heading GPS e curso derivado estão cobertos pelos testes automatizados.
