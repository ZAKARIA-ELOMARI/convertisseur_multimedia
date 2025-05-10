<div align="center">
<pre>
╔═══════════════════════════════════════════════════════════════════════════════════╗
║                                                                                   ║
║   ███╗   ███╗███████╗██████╗ ██╗ █████╗ ███████╗███╗   ███╗██╗████████╗██╗  ██╗   ║
║   ████╗ ████║██╔════╝██╔══██╗██║██╔══██╗██╔════╝████╗ ████║██║╚══██╔══╝██║  ██║   ║
║   ██╔████╔██║█████╗  ██║  ██║██║███████║███████╗██╔████╔██║██║   ██║   ███████║   ║
║   ██║╚██╔╝██║██╔══╝  ██║  ██║██║██╔══██║╚════██║██║╚██╔╝██║██║   ██║   ██╔══██║   ║
║   ██║ ╚═╝ ██║███████╗██████╔╝██║██║  ██║███████║██║ ╚═╝ ██║██║   ██║   ██║  ██║   ║
║   ╚═╝     ╚═╝╚══════╝╚═════╝ ╚═╝╚═╝  ╚═╝╚══════╝╚═╝     ╚═╝╚═╝   ╚═╝   ╚═╝  ╚═╝   ║
║                                                                                   ║
║                              Mediasmith v1.1.0                                    ║
╚═══════════════════════════════════════════════════════════════════════════════════╝
</pre>
</div>
<p align="center">
	<em><code>❯ Seamlessly watch ➜ backup ➜ convert your media</code></em>
</p>
<p align="center">
	<img src="https://img.shields.io/github/license/yourname/mediasmith?style=default&logo=opensourceinitiative&logoColor=white&color=0080ff" alt="license">
	<img src="https://img.shields.io/github/last-commit/yourname/mediasmith?style=default&logo=git&logoColor=white&color=0080ff" alt="last-commit">
	<img src="https://img.shields.io/github/languages/top/yourname/mediasmith?style=default&color=0080ff" alt="repo-top-language">
	<img src="https://img.shields.io/github/languages/count/yourname/mediasmith?style=default&color=0080ff" alt="repo-language-count">
</p>

## 🔗 Table of Contents
- [📍 Overview](#-overview)
- [👾 Features](#-features)
- [📁 Project Structure](#-project-structure)
- [🚀 Getting Started](#-getting-started)
  - [☑️ Prerequisites](#-prerequisites)
  - [⚙️ Installation](#-installation)
  - [🤖 Usage](#-usage)
  - [🧪 Testing](#-testing)
- [🔰 Contributing](#-contributing)
- [🎗 License](#-license)
- [🙌 Acknowledgments](#-acknowledgments)

---

## 📍 Overview
**Mediasmith** (v1.0.1) is a Bash toolkit that **monitors**, **backs up**, **organizes**, and **converts** multimedia files (video, audio, images) in real time.  
It uses `inotifywait`, `ffmpeg`, and `ImageMagick`, and includes a native POSIX‑threaded helper for high‑performance parallel conversion.

---

## 👾 Features
- **Live watch‑folder**: reacts to new files via `inotifywait` and a `handle_new_file` handler that auto‑backs up and converts.
- **Safe backups**: copies originals into `backup/<timestamp>/` with full directory tree, using `backup.sh` with `init_backup` and `backup_directory`.
- **One‑click organisation**: optional sorting into `audio/`, `video/`, and `images/` before processing.
- **Flexible conversion**:
  - **Merge mode**: concat media into one file.
  - **Single mode**: convert file‑by‑file.
  - **Fork**, **subshell**, or **POSIX threads** (`thread_converter` in C) modes.
  - **Improved thread_converter** logs each thread’s work with timestamp, user, and mutex‑protected output, and cleans up resources.
- **Robust logging**:
  - `logging.sh` writes to `/var/log/convertisseur_multimedia/history.log`.
  - Falls back to `logs/history.log` if `/var/log` is not writable.
  - Uses standardized format: `YYYY-MM-DD-HH-MM-SS : user : LEVEL : message`.
- **Error codes & validation**:
  - `main_script.sh` enforces mutual exclusion of `-f`, `-t`, `-s`.
  - Provides specific exit codes for missing arguments, invalid choices, or permission issues.
- **Self‑installing**: `deps_check.sh` auto‑installs `ffmpeg`, `inotify-tools`, and `imagemagick` if missing.
- **Portable build**: `Makefile` compiles the C helper and sets up everything with `make all`.

---

## 📁 Project Structure
```text
mediasmith/
├── bin/
│   └── thread_converter            # POSIX‑threads helper (C, gcc -pthread)
├── backup/                         # timestamped backups
├── config/
│   └── config.ini                  # default paths & options
├── lib/                            # Bash modules
│   ├── backup.sh
│   ├── conversion.sh
│   ├── logging.sh
│   ├── monitor.sh
│   └── utils.sh
├── logs/
│   └── history.log                 # fallback logs
├── output/                         # conversion results
├── scripts/
│   ├── convertisseur_multimedia.sh # main script (watch, menu, backup, convert)
│   ├── deps_check.sh               # dependency installer
│   └── populate_test_files.sh      # test files generator
├── src/
│   └── thread_converter.c          # C source for threaded conversion
├── Makefile
├── LICENSE
└── README.md                       # this file
```

---

## 🚀 Getting Started

### ☑️ Prerequisites
- Linux (Debian, Ubuntu, CentOS, Fedora…)  
- Bash 4+  
- GCC & Make  
- Internet (for first-run installs)

### ⚙️ Installation
```bash
git clone https://github.com/yourname/mediasmith.git
cd mediasmith
make all
```
This runs:
1. `scripts/deps_check.sh` → installs **ffmpeg**, **inotify-tools**, **ImageMagick**  
2. `make build` → compiles `src/thread_converter.c` → `bin/thread_converter`

### 🤖 Usage
(Optional) generate sample media:
```bash
make test
```

Run the main script:
```bash
scripts/convertisseur_multimedia.sh [options] <source_dir>
```

**Common options**  
| Flag   | Description                                      |
|--------|--------------------------------------------------|
| `-h`   | show help                                        |
| `-f`   | fork mode (`&`)                                  |
| `-s`   | subshell mode                                    |
| `-t`   | thread mode (uses `bin/thread_converter`)        |
| `-j N` | number of threads (with `-t`)                    |
| `-l DIR`| custom log directory                            |
| `-r`   | restore last backup                              |

**Example**  
```bash
scripts/convertisseur_multimedia.sh -t -j 4 test_files
```

### 🧪 Testing
```bash
make test
scripts/convertisseur_multimedia.sh -f test_files
scripts/convertisseur_multimedia.sh -s test_files
scripts/convertisseur_multimedia.sh -t -j 2 test_files
```
- Check `output/` for converted files.  
- Check `backup/<timestamp>/` for originals.  
- Check `logs/history.log` or `/var/log/.../history.log` for detailed logs.

---

## 🔰 Contributing
1. Fork & clone  
2. Create a branch (`git checkout -b feature/xyz`)  
3. Commit, push, PR  
4. Follow shell style (use `shfmt`)

---

## 🎗 License
MIT — see [LICENSE](LICENSE)

---

## 🙌 Acknowledgments
Built with ❤️ using `ffmpeg`, `inotify-tools`, and `ImageMagick`.
