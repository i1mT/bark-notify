.PHONY: build test app xcode-project install clean

build:
	swift build

test:
	swift test

app:
	./scripts/build-app.sh

xcode-project:
	xcodegen generate --spec Xcode/project.yml --project .

install:
	./scripts/install-local.sh

clean:
	swift package clean
	rm -rf build
