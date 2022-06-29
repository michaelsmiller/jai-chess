JC = jai-linux -x64

default: run

main: clean
	@$(JC) build.jai
	@clear

run: main
	./main

clean:
	rm -f main

.PHONY: main default clean
