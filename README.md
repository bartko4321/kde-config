# 🚀 KDE Environment Auto-Setup Script

A script that automates the personalization and visual configuration of the **KDE Plasma** desktop environment. It allows you to easily transfer themes, wallpapers, lock screens, and panel configurations between different user accounts or systems.

## 🚀 What does this script do?

### 1. System Configuration (Sudo)
* **Splash Screen:** Replaces the default KDE Breeze splash screen with a custom one from the `splash` directory.
* **User avatar:** Sets `piwo.png` as the user avatar in the system, Plasma environment, and SDDM display manager (`AccountsService`).
* **Login screen & wallpapers:** Copies a dedicated login wallpaper (`start.png`) and the `plasmalogin.conf` configuration file.
* **Default system wallpapers:** Overwrites the system wallpapers from the "Next" theme in 1080p, 2K, and 4K resolutions (light and dark variants).

### 2. User Configuration
* **Safe copying:** Stops the `plasmashell` process to prevent the running desktop environment from overwriting files.
* **Config transfer:** Copies the hidden directories `.config`, `.local`, and `.icons` to the home directory (`~`).
* **Dynamic path replacement:** Automatically scans config files for the old username (`bartek`) and replaces it with your current system account name.
* **Cache cleanup & rebuild:** Clears the icon/Plasma cache and forces a rebuild of the `sycoca` database.

---

## 🛠️ How to Use

### 1. Clone the repository or download the files
```bash
git clone https://github.com/syscore88/kde-config.git
```

### 2. Enter the downloaded folder
```bash
cd kde-config
```

### 3. Make the script executable
```bash
chmod +x install.sh
```

### 4. Run the script
> ⚠️ **IMPORTANT:** Run the script as a **regular user** (NOT as root/sudo). The script will ask for the administrator password at the start to configure temporary elevated privileges.

```bash
./install.sh
```

---

### ☕ Support the Project

If you find this tool helpful and it saved you some time, consider buying me a coffee to support further development! 

[![Buy Me A Coffee](https://cdn.buymeacoffee.com/buttons/v2/default-yellow.png)](https://buymeacoffee.com/bartekszczecinski)

---
<img width="1920" height="1080" alt="Zrzut ekranu_20260716_191008" src="https://github.com/user-attachments/assets/15eafeed-a1aa-4351-bbc1-46c0c231a1a6" />

If you find this project useful, leave a star! ⭐

## ⚠️ Important Notes

* **Auto-Reboot:** After all configurations complete successfully, the script will **automatically restart the computer** after 3 seconds so that all changes to the display manager and desktop environment are properly loaded. Save your work before running!
* **Temporary privileges:** The script creates a `/etc/sudoers.d/99-temp-installer` file to avoid password prompts during execution. This file is **completely removed** just before the script finishes.
