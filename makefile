# Makefile – Automatisation du projet convertisseur_multimedia

SHELL        := /usr/bin/env bash
PROJECT_ROOT := $(shell pwd)
BIN_DIR      := $(PROJECT_ROOT)/bin
SRC          := src/thread_converter.c
BIN          := $(BIN_DIR)/thread_converter

.PHONY: all scripts-perm deps build test clean

# Tâche par défaut
all: scripts-perm deps build

# Rendre tous les scripts exécutables
scripts-perm:
	chmod +x scripts/*.sh lib/*.sh

# Installer les dépendances système
deps:
	@echo "[MAKE] Vérification et installation des dépendances..."
	scripts/deps_check.sh

# Compiler le convertisseur multi-threads en C
build: $(BIN)

$(BIN): $(SRC) | $(BIN_DIR)
	gcc -std=c99 -D_POSIX_C_SOURCE=200809L -pthread \
		-o "$@" "$<"
	@echo "[MAKE] Binaire généré : $@"

$(BIN_DIR):
	mkdir -p "$@"

# Générer les fichiers de test
test: scripts-perm
	@echo "[MAKE] Création des fichiers de test..."
	scripts/populate_test_files.sh

# Nettoyer les artefacts
clean:
	@echo "[MAKE] Nettoyage des fichiers générés..."
	rm -f $(BIN_DIR)/thread_converter
	rm -rf test_files output
