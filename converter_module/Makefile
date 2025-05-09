CC=gcc
CFLAGS=-Wall -pthread
LDFLAGS=-pthread
TARGET=converter_thread_app

all: $(TARGET)

$(TARGET): converter_thread.o
	$(CC) $^ -o $@ $(LDFLAGS)

converter_thread.o: converter_thread.c
	$(CC) $(CFLAGS) -c $< -o $@

clean:
	rm -f *.o $(TARGET)

install: $(TARGET)
	sudo cp $(TARGET) /usr/local/bin/
