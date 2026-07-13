# Gost Installer

> Simple installer for **Gost** with support for installation, reconfiguration and automatic updates.

---

## ✨ Features

- ✅ Install Gost
- ✅ Detect existing installation
- ✅ Reconfigure an existing installation
- ✅ Force reinstall
- ✅ Automatic update mode
- ✅ Local execution
- ✅ Remote execution

---

## 🚀 Usage

### Local

```bash
git clone https://github.com/STEALTHNET-APP/gost-install-script.git

cd gost-install-script

chmod +x install_gost.sh

./install_gost.sh
```

### Remote

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/STEALTHNET-APP/gost-install-script/main/install_gost.sh)
```

---

## 🔄 Force Reinstall

### Local

```bash
sudo ./install_gost.sh --force
```

### Remote

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/STEALTHNET-APP/gost-install-script/main/install_gost.sh) -- --force
```

---

## ⚙️ Execution Flow

| Situation                              | Action                        |
| -------------------------------------- | ----------------------------- |
| Gost is not installed                  | Install Gost                  |
| Gost is installed                      | Update existing configuration |
| Gost is installed + arguments provided | Reconfigure                   |
| Gost is installed + `--force`          | Remove and reinstall          |

---

## 📖 Installation Flow

```text
main()

↓

detect_installation()

↓

Installed?

├── No
│
│   Install
│
└── Yes
    │
    ├── --force
    │     │
    │     Reinstall
    │
    └── No
          │
          Arguments passed?
          │
          ├── Yes
          │      Reconfigure
          │
          └── No
                 Update
```

---

## 📋 Requirements

- Linux
- `systemd`
- `curl`
- Root privileges

---

## 📄 License

MIT