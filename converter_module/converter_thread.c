#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <pthread.h>
#include <unistd.h>

#define MAX_CMD_LEN 1024

typedef struct {
    char src[512], dst[512], opts[512];
} args_t;

void *worker(void *v) {
    args_t *a = (args_t*)v;
    char cmd[MAX_CMD_LEN];
    snprintf(cmd, MAX_CMD_LEN, "ffmpeg -y -i \"%s\" %s \"%s\"", a->src, a->opts, a->dst);
    int st = system(cmd);
    return (void*)(intptr_t)(st == 0 ? 0 : 1);
}

int main(int argc, char **argv) {
    if (argc!=4) {
        fprintf(stderr, "Usage: %s <src> <dst> \"<opts>\"\n", argv[0]);
        return 1;
    }
    args_t a;
    strncpy(a.src, argv[1],511);
    strncpy(a.dst, argv[2],511);
    strncpy(a.opts, argv[3],511);

    pthread_t tid;
    if (pthread_create(&tid, NULL, worker, &a)!=0) {
        perror("pthread_create");
        return 2;
    }
    void *res;
    pthread_join(tid, &res);
    return (int)(intptr_t)res;
}
