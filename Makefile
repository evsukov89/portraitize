CC=clang
CFLAGS=-std=c99 -fobjc-arc -lobjc -framework Foundation -framework QuartzCore -framework AppKit -g
EXECUTABLE=portraitize
SOURCES=src/*.m
S3BUCKET=s3://portraitize

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

s3: compile
	cd build; cp $(EXECUTABLE) $(EXECUTABLE)_$(VERSION); \
	s3cmd put --acl-public $(EXECUTABLE)_$(VERSION) $(S3BUCKET); \
	rm $(EXECUTABLE)_$(VERSION); \
	zip -9 -y -r $(EXECUTABLE)_$(VERSION).dSYM.zip $(EXECUTABLE).dSYM; \
	s3cmd put --acl-public $(EXECUTABLE)_$(VERSION).dSYM.zip $(S3BUCKET); \
	rm $(EXECUTABLE)_$(VERSION).dSYM.zip;
