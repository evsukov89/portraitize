CC=clang
CFLAGS=-lobjc -framework Foundation -framework QuartzCore -framework AppKit -g
EXECUTABLE=portraitize
SOURCES=portraitize.m

compile: $(SOURCES)
	mkdir -p build
	$(CC) -o build/$(EXECUTABLE) $(SOURCES) $(CFLAGS)

clean:
	rm -rf build

run: compile
	build/$(EXECUTABLE) $(ARGS)

debug: compile
	lldb build/$(EXECUTABLE) -- $(ARGS)

all: compile
