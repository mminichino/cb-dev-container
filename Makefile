.PHONY: script build push
export CONTAINER := "cbdev"
export PROJECT_NAME := $$(basename $$(pwd))
export PROJECT_VERSION := $(shell cat VERSION)

commit:
		git commit -am "Version $(shell cat VERSION)"
		git push
branch:
		git checkout -b "Version_$(shell cat VERSION)"
		git push --set-upstream origin "Version_$(shell cat VERSION)"
merge:
		git checkout main
		git pull origin main
		git merge "Version_$(shell cat VERSION)"
		git push origin main
patch:
		bumpversion --allow-dirty patch
minor:
		bumpversion --allow-dirty minor
major:
		bumpversion --allow-dirty major
push:
		docker system prune -f
		docker buildx prune -f
		docker buildx build --platform linux/amd64,linux/arm64 \
		--no-cache \
		-t mminichino/$(CONTAINER):latest \
		-t mminichino/$(CONTAINER):$(PROJECT_VERSION) \
		-f Dockerfile . \
		--push
		git add -A .
		git commit -m "Build version $(PROJECT_VERSION)"
		git push -u origin main
script:
		gh release create -R "mminichino/$(PROJECT_NAME)" \
		-t "Management Utility Release" \
		-n "Auto Generated Run Utility" \
		$(PROJECT_VERSION) runutil.sh
build:
		docker system prune -f
		docker build --force-rm=true --no-cache=true -t $(CONTAINER):$(PROJECT_VERSION) -f Dockerfile .
