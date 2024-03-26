build:
	sh ./barf
	rsync -r public/ docs/public

clean:
	rm -rf docs/*

watch:
	while true; do \
	ls -d .git/* * posts/* pages/* header.html | entr -cd make ;\
	done

.PHONY: build clean watch
