CC 	:= nvcc
TARGET 	:= mandelbrot

SOURCES := $(shell find . -type f -name "*.cu")

.PHONY: all clean

all: $(TARGET)

$(TARGET): $(SOURCES)
	$(CC) $(CFLAGS) $^ -o $@

clean:
	rm -rf $(TARGET) images
