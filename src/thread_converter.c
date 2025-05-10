// src/thread_converter.c
#define _POSIX_C_SOURCE 200809L
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <pthread.h>
#include <limits.h>
#include <unistd.h>
#include <time.h>

typedef struct {
    char *filepath;
    char *out_dir;
    char *out_ext;
} job_t;

static job_t *jobs       = NULL;
static int      job_count = 0;
static int      next_job  = 0;
static pthread_mutex_t queue_mutex = PTHREAD_MUTEX_INITIALIZER;
static pthread_mutex_t log_mutex = PTHREAD_MUTEX_INITIALIZER;

// Format de sortie tel que défini dans le pdf:
// yyyy-mm-dd-hh-mm-ss : username : INFOS/ERROR : message
static void log_message(const char *level, const char *message) {
    time_t now;
    struct tm *tm_info;
    char timestamp[20];
    char username[64];
    
    // Mutex pour éviter entrelacement des logs
    pthread_mutex_lock(&log_mutex);
    
    // Obtenir timestamp au format spécifié
    time(&now);
    tm_info = localtime(&now);
    strftime(timestamp, sizeof(timestamp), "%Y-%m-%d-%H-%M-%S", tm_info);
    
    // Obtenir username
    if (getlogin_r(username, sizeof(username)) != 0) {
        strncpy(username, "unknown", sizeof(username));
    }
    
    // Afficher log selon le format requis
    printf("%s : %s : %s : %s\n", timestamp, username, level, message);
    
    pthread_mutex_unlock(&log_mutex);
}

static void log_info(const char *message) {
    log_message("INFOS", message);
}

static void log_error(const char *message) {
    log_message("ERROR", message);
}

static char *basename_noext(const char *path) {
    const char *base = strrchr(path, '/');
    base = base ? base + 1 : path;
    char *copy = strdup(base);
    char *dot = strrchr(copy, '.');
    if (dot) *dot = '\0';
    return copy;
}

static void *worker(void *arg) {
    int thread_id = *((int*)arg);
    char log_buffer[512];
    
    while (1) {
        pthread_mutex_lock(&queue_mutex);
        if (next_job >= job_count) {
            pthread_mutex_unlock(&queue_mutex);
            break;
        }
        job_t job = jobs[next_job++];
        pthread_mutex_unlock(&queue_mutex);

        char outpath[PATH_MAX];
        char *name = basename_noext(job.filepath);
        snprintf(outpath, sizeof(outpath), "%s/%s.%s",
                 job.out_dir, name, job.out_ext);
        free(name);

        // Préparer la commande avec redirection vers /dev/null
        char cmd[PATH_MAX * 2];
        snprintf(cmd, sizeof(cmd),
                 "ffmpeg -y -i \"%s\" \"%s\" > /dev/null 2>&1",
                 job.filepath, outpath);

        // Afficher info sur l'opération en cours
        snprintf(log_buffer, sizeof(log_buffer), 
                "THREAD-%d: Conversion de %s vers %s", 
                thread_id, job.filepath, outpath);
        log_info(log_buffer);
        
        // Exécuter la commande
        int ret = system(cmd);
        
        // Informer du résultat
        if (ret == 0) {
            snprintf(log_buffer, sizeof(log_buffer), 
                    "THREAD-%d: Succès: %s → %s", 
                    thread_id, job.filepath, outpath);
            log_info(log_buffer);
        } else {
            snprintf(log_buffer, sizeof(log_buffer), 
                    "THREAD-%d: Échec de conversion pour %s (code=%d)", 
                    thread_id, job.filepath, ret);
            log_error(log_buffer);
        }
    }
    
    free(arg);
    return NULL;
}

int main(int argc, char **argv) {
    if (argc < 8) {
        fprintf(stderr,
                "Usage: %s -o <out_dir> -e <out_ext> -j <threads> <file1> [file2 ...]\n",
                argv[0]);
        return EXIT_FAILURE;
    }

    int threads = 0;
    char *out_dir = NULL, *out_ext = NULL;
    int i = 1;
    while (i < argc && argv[i][0] == '-') {
        if (!strcmp(argv[i], "-o")) {
            out_dir = argv[++i];
        } else if (!strcmp(argv[i], "-e")) {
            out_ext = argv[++i];
        } else if (!strcmp(argv[i], "-j")) {
            threads = atoi(argv[++i]);
        } else {
            fprintf(stderr, "Option inconnue : %s\n", argv[i]);
            return EXIT_FAILURE;
        }
        i++;
    }

    if (!out_dir || !out_ext || threads <= 0 || i >= argc) {
        fprintf(stderr, "Arguments manquants ou invalides.\n");
        return EXIT_FAILURE;
    }

    job_count = argc - i;
    jobs = malloc(sizeof(job_t) * job_count);
    if (!jobs) {
        perror("malloc");
        return EXIT_FAILURE;
    }

    // Préparer out_dir
    char mkdir_cmd[PATH_MAX];
    snprintf(mkdir_cmd, sizeof(mkdir_cmd), "mkdir -p \"%s\"", out_dir);
    system(mkdir_cmd);

    for (int j = 0; j < job_count; j++) {
        jobs[j].filepath = argv[i + j];
        jobs[j].out_dir  = out_dir;
        jobs[j].out_ext  = out_ext;
    }

    pthread_t *tids = malloc(sizeof(pthread_t) * threads);
    if (!tids) {
        perror("malloc");
        free(jobs);
        return EXIT_FAILURE;
    }

    int *thread_ids = malloc(sizeof(int) * threads);
    if (!thread_ids) {
        perror("malloc");
        free(jobs);
        free(tids);
        return EXIT_FAILURE;
    }

    char log_buffer[256];
    snprintf(log_buffer, sizeof(log_buffer), 
            "Démarrage de la conversion avec %d threads pour %d fichiers", 
            threads, job_count);
    log_info(log_buffer);

    for (int t = 0; t < threads; t++) {
        thread_ids[t] = t + 1;
        int *arg = malloc(sizeof(int));
        if (!arg) {
            perror("malloc");
            return EXIT_FAILURE;
        }
        *arg = thread_ids[t];
        if (pthread_create(&tids[t], NULL, worker, arg) != 0) {
            perror("pthread_create");
            free(arg);
            return EXIT_FAILURE;
        }
    }
    
    for (int t = 0; t < threads; t++) {
        pthread_join(tids[t], NULL);
    }

    log_info("Toutes les opérations de conversion sont terminées");

    free(thread_ids);
    free(tids);
    free(jobs);
    pthread_mutex_destroy(&queue_mutex);
    pthread_mutex_destroy(&log_mutex);
    return EXIT_SUCCESS;
}
