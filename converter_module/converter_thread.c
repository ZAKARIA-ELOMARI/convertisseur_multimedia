#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <pthread.h>
#include <unistd.h>

#define MAX_ARG_LEN   1024
#define MAX_CMD_LEN   2048

typedef struct {
    char src[MAX_ARG_LEN];
    char dst[MAX_ARG_LEN];
    char opts[MAX_ARG_LEN];
} args_t;

void *worker(void *v) {
    args_t *a = (args_t*)v;
    char cmd[MAX_CMD_LEN];
    int n = snprintf(cmd, MAX_CMD_LEN,
                     "ffmpeg -y -i \"%s\" %s \"%s\"",
                     a->src, a->opts, a->dst);
    if (n < 0 || n >= MAX_CMD_LEN) {
        fprintf(stderr, "THREAD_ERROR: command too long (%d chars)\n", n);
        return (void*)(intptr_t)1;
    }
    int status = system(cmd);
    return (void*)(intptr_t)(status == 0 ? 0 : 1);
}

int main(int argc, char **argv) {
    if (argc != 4) {
        fprintf(stderr, "Usage: %s <src> <dst> \"<opts>\"\n", argv[0]);
        return 1;
    }
    args_t a;
    strncpy(a.src,  argv[1], MAX_ARG_LEN-1); a.src[MAX_ARG_LEN-1] = '\0';
    strncpy(a.dst,  argv[2], MAX_ARG_LEN-1); a.dst[MAX_ARG_LEN-1] = '\0';
    strncpy(a.opts, argv[3], MAX_ARG_LEN-1); a.opts[MAX_ARG_LEN-1] = '\0';

    pthread_t tid;
    if (pthread_create(&tid, NULL, worker, &a) != 0) {
        perror("THREAD_ERROR: pthread_create");
        return 2;
    }
    void *res;
    if (pthread_join(tid, &res) != 0) {
        perror("THREAD_ERROR: pthread_join");
        return 3;
    }
    return (int)(intptr_t)res;
}
