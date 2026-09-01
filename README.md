# Crave Build Scripts for Tecno Pova 5 Pro 5G (`LH8n`)

Automated cloud compilation scripts for Crave.io featuring real-time Telegram status pingers and automated GoFile uploading.

## Features
- 🚀 **Telegram Status Alerts**: Instant notifications on Start, Failure (with failed line & exit code), and Success.
- 📦 **GoFile Auto-Upload**: Automatically uploads the finished ROM `.zip` directly to GoFile and sends the download link.
- 🔏 **Release-Keys Signing**: Automatically clones signing keys for passing Play Integrity.
- ⚡ **Optimized Crave Caching**: Enforces `--depth 1` and uses `/opt/crave/resync.sh`.

---

## How to Trigger on Crave

### 1. With Telegram Alerts & GoFile Auto-Upload (Recommended)
Set your `TG_TOKEN` and `TG_CHAT_ID` when launching:
```bash
crave run --no-patch -- "export TG_TOKEN='your_bot_token' TG_CHAT_ID='your_chat_id' && curl -sL https://raw.githubusercontent.com/Swaggyxren/build_scripts/main/lineage.sh | bash"
```

### 2. Without Telegram Notifications (Silent Mode)
If `TG_TOKEN` is omitted, it will build normally and output the GoFile download URL to the terminal logs:
```bash
crave run --no-patch -- "curl -sL https://raw.githubusercontent.com/Swaggyxren/build_scripts/main/lineage.sh | bash"
```

---

## How to Pull Output Artifacts Manually (Optional)
If you also want to pull the artifacts locally:
```bash
crave pull out/target/product/LH8n/*.zip
crave pull out/target/product/LH8n/*.img
```
