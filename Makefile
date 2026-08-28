.PHONY: build test app install clean

build:
	swift build

test:
	swift test

app:
	./scripts/build-app.sh

install:
	./scripts/install-local.sh

clean:
	swift package clean
	rm -rf build
