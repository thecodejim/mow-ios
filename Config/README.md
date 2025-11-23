# iOS Environment Configuration

The iOS app mirrors the backend’s `.env` workflow by using layered **xcconfig**
files. Each build configuration (`LocalDev`, `Stage`, `Prod`) points at one of
the environment files under `Config/Environments/`. Secrets or per-developer
overrides live in git-ignored files under `Config/Secrets/`.

```
Config/
├── App.base.xcconfig          # shared build settings
├── Environments/              # checked-in defaults per environment
│   ├── LocalDev.xcconfig
│   ├── Stage.xcconfig
│   └── Prod.xcconfig
└── Secrets/                   # git-ignored per-env overrides
    ├── LocalDev.secrets.example.xcconfig
    ├── Stage.secrets.example.xcconfig
    └── Prod.secrets.example.xcconfig
```

Each environment file:

1. `#include`s the shared defaults.
2. Defines the public, non-sensitive values (domains, feature flags, etc.).
3. Optionally `#include?s` a matching secrets file that is ignored by git.

## Creating secrets files

Use the supplied Make targets (or copy by hand) to create local overrides:

```bash
make env-local    # writes Config/Secrets/LocalDev.secrets.xcconfig
make env-stage    # writes Config/Secrets/Stage.secrets.xcconfig
make env-prod     # writes Config/Secrets/Prod.secrets.xcconfig
```

Update the generated files with API tokens per environment. **Remember:** any
value compiled into the application is visible to end users. Keep true secrets
on the backend whenever possible.


