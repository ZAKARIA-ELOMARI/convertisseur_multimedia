// src/thread_converter.c
#define _POSIX_C_SOURCE 200809L
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <pthread.h>
#include <limits.h>
#include <unistd.h>

typedef struct {
    char *filepath;
    char *out_dir;
    char *out_ext;
} job_t;

static job_t *jobs       = NULL;
static int      job_count = 0;
static int      next_job  = 0;
static pthread_mutex_t queue_mutex = PTHREAD_MUTEX_INITIALIZER;

static char *basename_noext(const char *path) {
    const char *base = strrchr(path, '/');
    base = base ? base + 1 : path;
    char *copy = strdup(base);
    char *dot = strrchr(copy, '.');
    if (dot) *dot = '\0';
    return copy;
}

static void *worker(void *arg) {
    (void)arg;
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

        char cmd[PATH_MAX * 2];
        snprintf(cmd, sizeof(cmd),
                 "ffmpeg -y -i \"%s\" \"%s\" > /dev/null 2>&1",
                 job.filepath, outpath);

        printf("[THREAD %lu] %s\n", pthread_self(), cmd);
        int ret = system(cmd);
        if (ret == 0) {
            printf("[THREAD %lu] OK: %s → %s\n",
                   pthread_self(), job.filepath, outpath);
        } else {
            fprintf(stderr,
                    "[THREAD %lu] ERROR: échec %s\n",
                    pthread_self(), job.filepath);
        }
    }
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

    for (int t = 0; t < threads; t++) {
        if (pthread_create(&tids[t], NULL, worker, NULL) != 0) {
            perror("pthread_create");
            return EXIT_FAILURE;
        }
    }
    for (int t = 0; t < threads; t++) {
        pthread_join(tids[t], NULL);
    }

    free(tids);
    free(jobs);
    pthread_mutex_destroy(&queue_mutex);
    return EXIT_SUCCESS;
}
