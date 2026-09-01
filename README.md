# Crave Build Scripts for Tecno Pova 5 Pro 5G (`LH8n`)

Automated cloud compilation scripts for Crave.io.

## Available Build Targets

### 1. YAAP 17 (Android 15)
To build YAAP on Crave using `LOS 22.1` base (Project ID `93`):
```bash
crave run --no-patch -- "curl -sL https://raw.githubusercontent.com/Swaggyxren/build_scripts/main/yaap.sh | bash"
```

### 2. LineageOS 22.1 / 23.2
To build LineageOS on Crave using `LOS 22.1` base (Project ID `93`):
```bash
crave run --no-patch -- "curl -sL https://raw.githubusercontent.com/Swaggyxren/build_scripts/main/lineage.sh | bash"
```

---

## How to Pull Output Artifacts
After the build succeeds:
```bash
crave pull out/target/product/LH8n/*.zip
crave pull out/target/product/LH8n/*.img
```
