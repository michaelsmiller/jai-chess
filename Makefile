JC = jai-linux -x64
CFLAGS = -import_dir modules

default: run

main: clean
	@$(JC) $(CFLAGS) main.jai
	@clear

run: main
	./main

clean:
	rm -f main

.PHONY: main default clean
