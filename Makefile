product-local:
	mkdir -p tmp
	npx antora --version
	npx antora $(PDF_ANTORA_ARGS) --stacktrace --log-format=pretty --log-level=info \
		playbook-product-local.yml \
		2>&1 | tee tmp/product-local-build.log 2>&1

community-local:
	mkdir -p tmp
	npx antora --version
	npx antora --stacktrace --log-format=pretty --log-level=info \
		playbook-community-local.yml \
		2>&1 | tee tmp/community-local-build.log 2>&1

product-remote:
	mkdir -p tmp
	npm ci
	npx antora --version
	npx antora $(PDF_ANTORA_ARGS) --stacktrace --log-format=pretty --log-level=info \
		playbook-product-remote.yml \
		2>&1 | tee tmp/product-remote-build.log 2>&1

community-remote:
	mkdir -p tmp
	npm ci
	npx antora --version
	npx antora --stacktrace --log-format=pretty --log-level=info \
		playbook-community-remote.yml \
		2>&1 | tee tmp/community-remote-build.log 2>&1

srfa-local:
	mkdir -p tmp
	npx antora --version
	npx antora --stacktrace --log-format=pretty --log-level=info \
		playbook-srfa-local.yml \
		2>&1 | tee tmp/srfa-local-build.log 2>&1

srfa-remote:
	mkdir -p tmp
	npm ci
	npx antora --version
	npx antora --stacktrace --log-format=pretty --log-level=info \
		playbook-srfa-remote.yml \
		2>&1 | tee tmp/srfa-remote-build.log 2>&1

clean:
	rm -rf build

environment:
	npm ci

preview-community-local:
	npx http-server build/site-community-local -c-1 -p 8080

preview-product-local:
	npx http-server build/site-product-local -c-1 -p 8081

preview-srfa-local:
	npx http-server build/site-srfa-local -c-1 -p 8082

# Optional PDF build: pdf-options.yml activates it. Refer to
# dsc-style-bundle/pdf/README.md. Include pdf.mk last, so that product-local
# stays the default target.
PDF_PLAYBOOK ?= playbook-product-local.yml
PDF_LOCAL_PLAYBOOK ?= playbook-product-local.yml
PDF_SITE_DIR ?= build/site-product-local
DSC ?= dsc-style-bundle
-include $(DSC)/pdf/pdf.mk
