# convertisseur_multimedia

## Structure
convertisseur_multimedia/
├── convertisseur.sh
├── config.conf
├── populate_test_files.sh
├── README.md
└── converter_module/
├── converter_thread.c
└── Makefile



## Prérequis  
Aucun install manuel : le script installera ffmpeg si besoin via apt.  
Le module C `converter_thread_app` doit être installé :

```bash
cd converter_module
make
sudo make install
```

## Utilisation
```bash
./convertisseur.sh [options] <dossier_media>
```

Options obligatoires Devoir_2_Mini_Projet_v1…
-h : aide

-f : fork

-t : thread

-s : subshell

-l <rép_logs> : changer dossier de logs

-r : restaure /var/log/convertisseur_multimedia

Flux
Sauvegarde du dossier original ($HOME/multimedia_backup/...)

Tri en sous-dossiers audio/, video/, image/

Sélection interactive de la catégorie et des formats source/cible

Conversion en mode choisi

Logs simultanés terminal + /var/log/.../history.log (format yyyy-mm-dd-hh-mm-ss : user : TYPE : message) Devoir_2_Mini_Projet_v1…Devoir_2_Mini_Projet_v1…

Test
Générez le dossier de test :

```bash
chmod +x populate_test_files.sh
./populate_test_files.sh
```

Puis :

```bash
./convertisseur.sh -s -l ./logs test_files
```