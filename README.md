# mow iOS

iOS companion app for the Meals-on-Wheels Charlottesville stack. The goal of
this repo is to mirror the backend’s developer ergonomics: predictable
environments, explicit config/secrets, and easy-to-remember automation targets.

## Stack

* SwiftUI, iOS 18+ (Xcode 16)
* Local/Stage/Prod build configurations powered by xcconfig files
* Runtime configuration surfaced through `AppEnvironment`
* Makefile-driven developer workflow (similar to the backend repo)

## Getting started

```bash
make bootstrap   # resolves packages + creates Config/Secrets/LocalDev.secrets.xcconfig
make open        # opens the Xcode project
```

To verify the wiring from the terminal:

```bash
make build-local
make test
```

## Environment configuration

`Config/` contains the layered config system:

* `Config/App.base.xcconfig` – shared Info.plist + Swift flags
* `Config/Environments/{LocalDev,Stage,Prod}.xcconfig` – checked-in defaults
* `Config/Secrets/*.secrets.example.xcconfig` – templates for git-ignored overrides

Copy a template before building a given environment:

```bash
make env-local   # or env-stage / env-prod
```

The values flow into `Info.plist`, which `AppEnvironment` reads at runtime. The
home screen now shows which environment you’re connected to along with the
exact endpoints/flags that were compiled in.

> **Note:** Client apps cannot truly hide secrets—anything shipping in the app
> bundle is visible to end users. Use backend-issued tokens whenever possible
> and treat the xcconfig “secrets” as convenience overrides only.

## Make targets

Run `make help` for the full list. Highlights:

| Target | Description |
|--------|-------------|
| `make bootstrap` | Copy local secrets template + resolve packages |
| `make build-local` | Build LocalDev against the default simulator |
| `make build-stage` / `make build-prod` | Build other configs |
| `make run-local` | Clean + rebuild LocalDev |
| `make test` | Execute tests on the simulator |
| `make archive-prod` | Create an archive ready for distribution |
| `make format` | Run `swiftformat` (if installed) |

## Next steps

* Flesh out networking that points at the new backend.
* Introduce shared UI kits / design system packages.
* Hook CI to reuse the Make targets for lint/build/test.


