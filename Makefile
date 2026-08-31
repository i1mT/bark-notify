.PHONY: build test app dmg xcode-project install clean

VERSION ?= 1.0.0

build:
	swift build

test:
	swift test

app:
	./scripts/build-app.sh

dmg:
	VERSION="$(VERSION)" ./scripts/build-dmg.sh

xcode-project:
	xcodegen generate --spec Xcode/project.yml --project .

install:
	./scripts/install-local.sh

clean:
	swift package clean
	rm -rf build
