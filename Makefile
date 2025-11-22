APP_NAME        ?= mow-ios
SCHEME          ?= $(APP_NAME)
PROJECT         ?= $(APP_NAME).xcodeproj
SIMULATOR       ?= "platform=iOS Simulator,name=iPhone 16 Pro"
ARCHIVE_PATH    ?= build/$(APP_NAME).xcarchive
SECRETS_DIR     ?= Config/Secrets

XCODEBUILD = xcrun xcodebuild -project $(PROJECT) -scheme $(SCHEME)

.PHONY: help bootstrap env-local env-stage env-prod env-all open \
	build-local build-stage build-prod run-local test \
	format clean devices archive-prod

help: ## Show available targets
	@echo "Usage: make <target>"
	@echo ""
	@grep -hE '^[a-zA-Z0-9_-]+:.*?## .*$$' $(MAKEFILE_LIST) \
	| awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-22s\033[0m %s\n", $$1, $$2}'

bootstrap: env-local ## Prepare a fresh checkout (creates secrets + resolves packages)
	@$(XCODEBUILD) -resolvePackageDependencies >/dev/null
	@echo "✅ Bootstrap complete. Open the project with 'make open'."

env-local: ## Copy local-dev secret template if missing
	@$(MAKE) --no-print-directory _ensure-secret NAME=LocalDev

env-stage: ## Copy stage secret template if missing
	@$(MAKE) --no-print-directory _ensure-secret NAME=Stage

env-prod: ## Copy prod secret template if missing
	@$(MAKE) --no-print-directory _ensure-secret NAME=Prod

env-all: env-local env-stage env-prod ## Ensure every secrets file exists

_ensure-secret:
	@dest="$(SECRETS_DIR)/$(NAME).secrets.xcconfig"; \
	template="$(SECRETS_DIR)/$(NAME).secrets.example.xcconfig"; \
	if [ -f "$$dest" ]; then \
		echo "✅ $(NAME) secrets already exist at $$dest"; \
	else \
		cp "$$template" "$$dest"; \
		echo "✏️  Created $$dest — update it with real values."; \
	fi

open: ## Open the Xcode project
	open $(PROJECT)

build-local: ## Build LocalDev configuration for the default simulator
	$(XCODEBUILD) -configuration LocalDev -destination $(SIMULATOR) build

build-stage: ## Build Stage configuration
	$(XCODEBUILD) -configuration Stage -destination $(SIMULATOR) build

build-prod: ## Build Prod configuration (no simulator destination)
	$(XCODEBUILD) -configuration Prod build

run-local: ## Clean + rebuild LocalDev on the simulator
	$(XCODEBUILD) -configuration LocalDev -destination $(SIMULATOR) clean build

test: ## Run unit/UI tests in LocalDev configuration
	$(XCODEBUILD) test -configuration LocalDev -destination $(SIMULATOR)

format: ## Format Swift sources using swiftformat (if installed)
	@command -v swiftformat >/dev/null || { \
		echo "⚠️  Install swiftformat: brew install swiftformat"; exit 1; }
	swiftformat mow-ios

clean: ## Remove build artifacts
	$(XCODEBUILD) clean

devices: ## List available simulators
	xcrun simctl list devices

archive-prod: ## Archive the Prod build (outputs to ./build)
	$(XCODEBUILD) -configuration Prod -archivePath $(ARCHIVE_PATH) archive

