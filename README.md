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
║                              Mediasmith v1.0.0                                    ║
╚═══════════════════════════════════════════════════════════════════════════════════╝
</pre>
</div>
<p align="center">
	<em><code>❯ Seamlessly watch ➜ backup ➜ convert your media</code></em>
</p>
<p align="center">
	<img src="https://img.shields.io/github/last-commit/ZAKARIA-ELOMARI/mediasmith?style=default&logo=git&logoColor=white&color=0080ff" alt="last-commit">
	<img src="https://img.shields.io/github/languages/top/ZAKARIA-ELOMARI/mediasmith?style=default&color=0080ff" alt="repo-top-language">
	<img src="https://img.shields.io/github/languages/count/ZAKARIA-ELOMARI/mediasmith?style=default&color=0080ff" alt="repo-language-count">
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
**Mediasmith** is a Bash‑powered toolkit that **monitors**, **backs up**, **organises** and **converts** your multimedia files—video, audio and images—in real‑time.  
Driven by `inotifywait`, `ffmpeg`, and `ImageMagick`, it forges any incoming media into the format you choose, while keeping pristine timestamped copies of the originals and logging every step for full traceability.

---

## 👾 Features
- **Live watch‑folder**: automatically reacts when new files land in a directory.  
- **Multi‑type support**: videos (`mp4`, `mkv`, `avi`…), audio (`wav`, `flac`, `mp3`…), images (`png`, `jpg`, `gif`…).  
- **One‑click organisation**: optional sorting into `audio/`, `video/`, `images/` before processing.  
- **Safe backups**: originals copied to `backup/<timestamp>/` with preserved tree structure.  
- **Flexible conversion**  
  - Merge or one‑by‑one mode  
  - Fork (`&`), subshell, or **native POSIX threads** via the `thread_converter` helper.  
- **Verbose logging** to `/var/log/convertisseur_multimedia/history.log`.  
- **Self‑installing**: dependency checker fetches `ffmpeg`, `inotify-tools`, `imagemagick` if missing.  
- **Portable build**: simple `Makefile` compiles the C helper and prepares everything.  

---

## 📁 Project Structure
```text
mediasmith/
├── bin/                    # compiled thread_converter
├── backup/                 # timestamped backups (created at runtime)
├── config/
│   └── config.ini          # default paths & options
├── lib/                    # reusable Bash modules
│   ├── backup.sh
│   ├── conversion.sh
│   ├── logging.sh
│   ├── monitor.sh
│   └── utils.sh
├── output/                 # converted results (created at runtime)
├── scripts/
│   ├── convertisseur_multimedia.sh  # main entry‑point
│   ├── deps_check.sh
│   └── populate_test_files.sh
├── src/
│   └── thread_converter.c  # POSIX‑threads helper
├── Makefile
├── LICENSE
└── README.md
```

---

## 🚀 Getting Started

### ☑️ Prerequisites
| Requirement | Minimum version | Why |
|-------------|-----------------|-----|
| Linux distro| any with `apt`, `dnf`, or `yum` | package install |
| Bash        | 4.0             | arrays & `declare -F` |
| GCC & make  | standard build tools | compile `thread_converter` |
| Internet    | for first‑run dependency install |

### ⚙️ Installation
```bash
git clone https://github.com/yourname/mediasmith.git
cd mediasmith

# install system deps & build the C helper
make all
```

This will:
1. run `scripts/deps_check.sh` → installs **ffmpeg**, **inotify‑tools**, **ImageMagick**;  
2. compile `src/thread_converter.c` → `bin/thread_converter`;  
3. leave you ready to roll.

### 🤖 Usage
Generate a sandbox folder of sample media (optional):
```bash
make test    # or: scripts/populate_test_files.sh
```

Run Mediasmith on that folder:
```bash
# 4 POSIX threads, output format chosen interactively
scripts/convertisseur_multimedia.sh -t -j 4 test_files
```

Common flags:
| Flag | Purpose |
|------|---------|
| `-f` | fork each conversion (`&`) |
| `-s` | run in a subshell |
| `-t` | thread mode (C helper) |
| `-j N` | number of threads (with `-t`) |
| `-l DIR` | custom log dir |
| `-r` | restore last backup |

### 🧪 Testing
The project is mostly shell; integration tests are manual:

```bash
# create fixtures
make test
# convert with each execution mode
scripts/convertisseur_multimedia.sh -f test_files
scripts/convertisseur_multimedia.sh -s test_files
scripts/convertisseur_multimedia.sh -t -j 2 test_files
```

Check:
* `output/` contains converted files in the requested format.  
* `backup/<timestamp>/` contains untouched originals.  
* `logs/history.log` records INFO/ERROR lines for every step.


---

## 🔰 Contributing
Feel free to open issues or PRs! For major changes, please file an issue first to discuss what you would like to change.

1. Fork → create feature branch → commit → push → pull request.  
2. Follow existing code style; shell scripts are formatted with `shfmt`.

---

## 🎗 License
Mediasmith is released under the **MIT License**. See [LICENSE](LICENSE).

---

## 🙌 Acknowledgments
Inspired by the simplicity of classic Unix tools and the awesome open‑source projects `ffmpeg`, `inotify‑tools`, and `ImageMagick`.

---
