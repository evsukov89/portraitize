CC=clang
CFLAGS=-std=c99 -fobjc-arc -lobjc -framework Foundation -framework QuartzCore -framework AppKit -g
EXECUTABLE=portraitize
SOURCES=src/*.m

compile: $(SOURCES)
	mkdir -p build
	$(CC) $(CFLAGS) -o build/$(EXECUTABLE) $(SOURCES)

clean:
	rm -rf build

run: compile
	build/$(EXECUTABLE) $(ARGS)

debug: compile
	lldb build/$(EXECUTABLE) -- $(ARGS)

all: compile
