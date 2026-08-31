.PHONY: build test app dmg release-dmg xcode-project install cli-install cli-build cli-test cli-pack website-install website-dev website-build clean

VERSION ?= 1.0.0

build:
	swift build

test:
	swift test

app:
	./scripts/build-app.sh

dmg:
	VERSION="$(VERSION)" ./scripts/build-dmg.sh

release-dmg:
	VERSION="$(VERSION)" APP_ARCHS="arm64 x86_64" SIGN_IDENTITY=auto NOTARY_PROFILE="BarkDesk-Notary" ./scripts/build-dmg.sh

xcode-project:
	xcodegen generate --spec Xcode/project.yml --project .

install:
	./scripts/install-local.sh

cli-install:
	npm --prefix cli install

cli-build:
	npm --prefix cli run build

cli-test:
	npm --prefix cli test

cli-pack:
	npm --prefix cli pack --dry-run

website-install:
	npm --prefix website install

website-dev:
	npm --prefix website run dev

website-build:
	npm --prefix website run build

clean:
	swift package clean
	rm -rf build
	rm -rf cli/dist
	rm -rf website/.next website/out
