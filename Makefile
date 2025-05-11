APP_NAME=rawpair
VERSION=0.0.0~a025
ARCH=amd64
BUILD_DIR=phoenix-app/_build/prod/rel/$(APP_NAME)
STAGING_DIR=dist/deb/$(APP_NAME)
DEB_NAME=$(APP_NAME)_$(VERSION)_$(ARCH).deb

.PHONY: all build-release stage deb clean

all: build-release stage deb

build-release:
	cd phoenix-app && ./deploy.sh

stage:
	rm -rf $(STAGING_DIR)
	mkdir -p $(STAGING_DIR)/opt/$(APP_NAME)
	mkdir -p $(STAGING_DIR)/etc/$(APP_NAME)
	mkdir -p $(STAGING_DIR)/lib/systemd/system
	mkdir -p $(STAGING_DIR)/etc/logrotate.d

	cp -r $(BUILD_DIR)/* $(STAGING_DIR)/opt/$(APP_NAME)/
	cp packaging/rawpair.env.default $(STAGING_DIR)/etc/$(APP_NAME)/rawpair.env.default
	cp packaging/rawpair.service $(STAGING_DIR)/lib/systemd/system/rawpair.service
	cp packaging/rawpair.logrotate $(STAGING_DIR)/etc/logrotate.d/$(APP_NAME)

	cp packaging/postinst.sh postinst.sh
	cp packaging/postrm.sh postrm.sh

deb:
	fpm -s dir -t deb \
	  -n $(APP_NAME) \
	  -v $(VERSION) \
	  -a $(ARCH) \
	  --license "MPL-2.0" \
	  --description "RawPair self-hosted collaborative development server" \
	  --after-install postinst.sh \
	  --after-remove postrm.sh \
	  $(STAGING_DIR)/opt/$(APP_NAME)/=/opt/$(APP_NAME)/ \
	  $(STAGING_DIR)/etc/$(APP_NAME)/=/etc/$(APP_NAME)/ \
	  $(STAGING_DIR)/lib/systemd/system/rawpair.service=/lib/systemd/system/rawpair.service \
	  $(STAGING_DIR)/etc/logrotate.d/$(APP_NAME)=/etc/logrotate.d/$(APP_NAME)

clean:
	rm -rf dist
	rm -f *.deb
	rm -f postinst.sh postrm.sh
