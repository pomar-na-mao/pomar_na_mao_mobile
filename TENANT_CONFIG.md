# Guia de Configuração e Execução Multi-Tenant

Este projeto suporta alternância de clientes (tenants) via compilação com a flag `--dart-define`.
Os dois tenants cadastrados no sistema são:

1. **`ricardoLichia`**: Cliente Fazenda Coatiara (Cultura: Lichia)
2. **`hassAvocado`**: Cliente Sítio São Francisco (Cultura: Abacate Hass)

---

## 🛠️ 1. Executando em Modo Debug (`flutter run`)

Para executar a aplicação em desenvolvimento/debug conectando ao Supabase do cliente desejado:

### 🥑 Cliente Ricardo Lichia
```bash
flutter run --debug \
  --dart-define=TENANT=ricardoLichia \
  --dart-define=SUPABASE_URL=https://cumkqrjwsbyotaojeyxv.supabase.co \
  --dart-define=SUPABASE_PUBLISHABLE_KEY=sb_publishable_8Bb-W0YT2zTGI83_bFil7w_ZRucyTwZ
```

### 🥑 Cliente Hass Avocado
```bash
flutter run --debug \
  --dart-define=TENANT=hassAvocado \
  --dart-define=SUPABASE_URL=https://uxschjkypkkzprbwuhxm.supabase.co \
  --dart-define=SUPABASE_PUBLISHABLE_KEY=sb_publishable_idzivuZYu4ScWTOb14EtQA_VToCjySh
```

---

## 📦 2. Gerando o APK do Android (`flutter build apk`)

### 📦 APK Release

#### Ricardo Lichia
```bash
flutter build apk --release \
  --dart-define=TENANT=ricardoLichia \
  --dart-define=SUPABASE_URL=https://cumkqrjwsbyotaojeyxv.supabase.co \
  --dart-define=SUPABASE_PUBLISHABLE_KEY=sb_publishable_8Bb-W0YT2zTGI83_bFil7w_ZRucyTwZ
```

#### Hass Avocado
```bash
flutter build apk --release \
  --dart-define=TENANT=hassAvocado \
  --dart-define=SUPABASE_URL=https://uxschjkypkkzprbwuhxm.supabase.co \
  --dart-define=SUPABASE_PUBLISHABLE_KEY=sb_publishable_idzivuZYu4ScWTOb14EtQA_VToCjySh
```

> O arquivo gerado estará em:  
> `build/app/outputs/flutter-apk/app-release.apk`

---

### 📦 APK Debug

#### Ricardo Lichia
```bash
flutter build apk --debug \
  --dart-define=TENANT=ricardoLichia \
  --dart-define=SUPABASE_URL=https://cumkqrjwsbyotaojeyxv.supabase.co \
  --dart-define=SUPABASE_PUBLISHABLE_KEY=sb_publishable_8Bb-W0YT2zTGI83_bFil7w_ZRucyTwZ
```

#### Hass Avocado
```bash
flutter build apk --debug \
  --dart-define=TENANT=hassAvocado \
  --dart-define=SUPABASE_URL=https://uxschjkypkkzprbwuhxm.supabase.co \
  --dart-define=SUPABASE_PUBLISHABLE_KEY=sb_publishable_idzivuZYu4ScWTOb14EtQA_VToCjySh
```

> O arquivo gerado estará em:  
> `build/app/outputs/flutter-apk/app-debug.apk`

---

## 💻 3. Configurando a Depuração no VS Code (`.vscode/launch.json`)

Você pode salvar estas configurações de inicialização no seu VS Code:

```json
{
  "version": "0.2.0",
  "configurations": [
    {
      "name": "Ricardo Lichia (Debug)",
      "request": "launch",
      "type": "dart",
      "args": [
        "--dart-define=TENANT=ricardoLichia",
        "--dart-define=SUPABASE_URL=https://cumkqrjwsbyotaojeyxv.supabase.co",
        "--dart-define=SUPABASE_PUBLISHABLE_KEY=sb_publishable_8Bb-W0YT2zTGI83_bFil7w_ZRucyTwZ"
      ]
    },
    {
      "name": "Hass Avocado (Debug)",
      "request": "launch",
      "type": "dart",
      "args": [
        "--dart-define=TENANT=hassAvocado",
        "--dart-define=SUPABASE_URL=https://uxschjkypkkzprbwuhxm.supabase.co",
        "--dart-define=SUPABASE_PUBLISHABLE_KEY=sb_publishable_idzivuZYu4ScWTOb14EtQA_VToCjySh"
      ]
    }
  ]
}
```
