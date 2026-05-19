# WeBWorK Developer Guide

This guide is for developers who want to contribute to WeBWorK or run it locally for development. For general information and end-user documentation, see [README.md](README.md) and the [WeBWorK wiki](https://webwork.maa.org/wiki/Main_Page).

## Tech Stack

| Component | Technology |
|---|---|
| Backend | Perl, [Mojolicious](https://mojolicious.org/) web framework |
| Templates | Mojolicious Embedded Perl (`.html.ep` files) |
| Frontend | JavaScript (ES6+), Bootstrap |
| CSS | SCSS, PostCSS, Autoprefixer |
| Database | MariaDB |
| Job Queue | [Minion](https://docs.mojolicious.org/Minion) (SQLite-backed) |
| Math Rendering | MathJax |
| Problem Generation | [PG](https://github.com/openwebwork/pg) (separate repository) |
| Deployment | Docker / Hypnotoad / systemd |

## Prerequisites

### Docker path (recommended)

- [Docker](https://docs.docker.com/get-docker/) and Docker Compose

### Native path

- Perl (see `DockerfileStage1` for the tested version)
- MariaDB (or MySQL equivalent)
- Node.js
- The [pg](https://github.com/openwebwork/pg) repository cloned alongside webwork2
- System packages for Perl modules (see `DockerfileStage1` for the full list)

## Local Development Setup (Docker)

1. **Copy config files:**

   ```bash
   cp docker-config/docker-compose.dist.yml docker-compose.yml
   cp docker-config/env.dist .env
   ```

2. **Create the courses directory:**

   ```bash
   mkdir -p ../ww-docker-data/courses
   ```

3. **Build and start (two-stage build, recommended):**

   ```bash
   docker build --tag webwork-base:forWW220 -f DockerfileStage1 .
   docker compose build
   docker compose up -d
   ```

   For a single-stage build, edit `docker-compose.yml` and change `dockerfile: DockerfileStage2` to `dockerfile: Dockerfile`, then run `docker compose build && docker compose up -d`.

4. **Mount local source for live development** (optional):

   Uncomment this line in `docker-compose.yml` under the `app` service volumes to mount your local checkout into the container:

   ```yaml
   - ".:/opt/webwork/webwork2"
   ```

   When mounting locally, you must build the frontend assets on your host — the mount replaces the container's pre-built copies:

   ```bash
   cd htdocs && npm install && npm run generate-assets
   ```

5. **Access WeBWorK** at http://localhost:8080/webwork2

   The Docker entrypoint automatically creates an `admin` course with a default login:

   - **URL:** http://localhost:8080/webwork2/admin
   - **Username:** `admin`
   - **Password:** `admin`

6. **Disable two-factor authentication** (recommended for local development):

   Two-factor auth is enabled by default for all courses. To disable it, add the following to `conf/localOverrides.conf` (or mount a custom copy in Docker):

   ```perl
   $twoFA{enabled} = 0;
   ```

### Docker commands

```bash
docker compose logs -f app       # Follow application logs
docker compose down               # Stop and remove containers
docker compose up -d --build      # Rebuild and restart
```

## Local Development Setup (Native)

1. **Install Perl dependencies.** See `DockerfileStage1` for the full list of system packages and Perl modules required.

2. **Set up MariaDB.** Create a `webwork` database and a user with read/write access.

3. **Clone the PG repository** alongside webwork2:

   ```bash
   git clone https://github.com/openwebwork/pg.git ../pg
   ```

4. **Copy and edit configuration files:**

   ```bash
   cp conf/site.conf.dist conf/site.conf
   cp conf/localOverrides.conf.dist conf/localOverrides.conf
   ```

   In `conf/site.conf`, set:
   - `$server_root_url` to `http://localhost:3000`
   - `$pg_dir` to the path of your `pg` checkout
   - `$database_password` to your MariaDB password

5. **Start the development server** (with hot reload):

   ```bash
   ./bin/dev_scripts/webwork2-morbo
   ```

   If permissions require it, run as the server user:

   ```bash
   sudo -u www-data ./bin/dev_scripts/webwork2-morbo
   ```

6. **Start the job queue worker** (in a separate terminal):

   ```bash
   ./bin/webwork2 minion worker
   ```

   Note: the Minion worker does not hot reload. Restart it manually after changing task modules.

7. **Create the admin course:**

   ```bash
   bin/addcourse admin --db-layout=sql_single \
     --users=courses.dist/adminClasslist.lst \
     --professors=admin
   ```

   This creates the `admin` course with a default user `admin` (password: `admin`).

8. **Disable two-factor authentication** (recommended for local development):

   Add the following to `conf/localOverrides.conf`:

   ```perl
   $twoFA{enabled} = 0;
   ```

9. **Access WeBWorK** at http://localhost:3000/webwork2

## Project Structure

```
webwork2/
├── bin/                    # CLI scripts and executables
│   └── dev_scripts/        # Development-only scripts (morbo, etc.)
├── lib/                    # Core Perl source code
│   ├── Mojolicious/        # Mojolicious app and plugins
│   └── WeBWorK/            # WeBWorK business logic
│       ├── ContentGenerator/  # Page controllers (one per page type)
│       ├── Authen/         # Authentication modules
│       ├── DB/             # Database layer (Schema, Record, Utils)
│       └── ...
├── templates/              # Mojolicious .html.ep templates
├── htdocs/                 # Frontend assets (JS, CSS, images, themes)
│   ├── js/                 # JavaScript modules organized by feature
│   ├── css/                # Compiled CSS
│   ├── themes/             # UI themes (math4, math4-red, etc.)
│   └── package.json        # Frontend dependencies and build scripts
├── conf/                   # Configuration files (.dist templates)
├── assets/                 # Static assets (LaTeX themes, stop words)
├── courses.dist/           # Sample course directory structure
├── docker-config/          # Docker configuration and entrypoint
├── doc/                    # License files
├── logs/                   # Application logs
└── tmp/                    # Temporary files
```

## Architecture Overview

### Application entry point

The Mojolicious app is defined in `lib/Mojolicious/WeBWorK.pm` and started via `bin/webwork2`:

```bash
./bin/webwork2 daemon      # Start in development mode
./bin/webwork2 prefork     # Start in production mode (hypnotoad)
```

### ContentGenerator pattern

Each page type has a corresponding Perl module in `lib/WeBWorK/ContentGenerator/`. These modules handle routing, authorization, and rendering for their respective pages. Examples: `Grades.pm`, `ProblemSets.pm`, `CourseAdmin.pm`, `Instructor/UserList.pm`.

### Database layer

The DB layer has three tiers:

- **`lib/WeBWorK/DB.pm`** — Top-level API for all database operations
- **`lib/WeBWorK/DB/Schema/`** — Schema definitions and query builders
- **`lib/WeBWorK/DB/Record/`** — Data record objects (user, set, problem, etc.)

### PG integration

The Problem Generation system lives in the separate [pg](https://github.com/openwebwork/pg) repository. It is loaded at runtime from the path configured in `$pg_dir`.

## Frontend Development

Frontend assets live in `htdocs/`. To work on JavaScript or CSS:

```bash
cd htdocs
npm install
npm run generate-assets
```

See `htdocs/package.json` for the full list of frontend dependencies.

Themes are located in `htdocs/themes/`.

## Configuration

WeBWorK uses a `.dist` file convention: files ending in `.dist` are templates that should be copied (without the `.dist` suffix) and customized. Never modify `.dist` files directly — your changes will be lost on upgrade.

**Config load order:**

1. `conf/site.conf` — Server-specific settings (URL, DB credentials, PG path)
2. `conf/defaults.config` — Default values for all options (**do not modify**)
3. `conf/localOverrides.conf` — Your customizations, overrides values from `defaults.config`

Optional authentication configs (LTI, LDAP, CAS, SAML2, Shibboleth) can be included from `localOverrides.conf`.

See [conf/README.md](conf/README.md) for full configuration and deployment documentation.

## Code Style and Linting

Formatting is enforced by CI on every pull request.

### Perl

Configured via `.perltidyrc`:

- Line width: 120 characters
- Indentation: tabs (4-space equivalent)
- Cuddled else blocks

Format Perl files with:

```bash
perltidy -pro=.perltidyrc <file>
```

### JavaScript / CSS / HTML

Configured via `.prettierrc`:

- Line width: 120 characters
- Single quotes, no trailing commas
- Indentation: tabs

```bash
cd htdocs
npm run prettier-check     # Check formatting
npm run prettier-format    # Auto-fix formatting
```

### Editor config

The `.editorconfig` file provides consistent settings across editors (UTF-8, LF line endings, tab indentation).

## Useful Scripts

| Script | Description |
|---|---|
| `bin/webwork2` | Main application entry point (Mojolicious commands) |
| `bin/dev_scripts/webwork2-morbo` | Development server with hot reload |
| `bin/wwsh` | WeBWorK interactive shell |
| `bin/addcourse` | Create a new course |
| `bin/delcourse` | Delete a course |
| `bin/addadmin` | Add an admin user |
| `bin/OPL-update` | Update the Open Problem Library |
| `bin/check_modules.pl` | Verify Perl module dependencies |
| `bin/importClassList.pl` | Import a class roster |

## Contributing

1. Fork the repository and create a feature branch from `develop`.
2. Follow the code style guidelines above — CI will check formatting automatically.
3. Open a pull request against `develop`. The `main` branch is reserved for hotfix pull requests only.
4. For discussion or questions, use [GitHub Discussions](https://github.com/openwebwork/webwork2/discussions).

For more developer resources, see the [WeBWorK developer wiki](https://webwork.maa.org/wiki/Category:Developers).

## Troubleshooting

### CSS/JS not loading when mounting local source

When you mount `.:/opt/webwork/webwork2` in Docker, your local files replace the container's pre-built assets. Build them on your host:

```bash
cd htdocs && npm install && npm run generate-assets
```

Verify that `htdocs/static-assets.json` was created — this is the asset manifest the app uses to resolve hashed filenames. If the file is missing, the app cannot find the compiled CSS/JS and pages will appear unstyled.

**Node.js version note:** On Node 22+, a fix was applied to `htdocs/generate-assets.js` to ensure the chokidar `ready` event fires correctly and `static-assets.json` is written.

### Container exits with `cp: cannot stat '*.json': No such file or directory`

The OPL volume has a stale state — the SQL dump exists but JSON metadata files are missing. Remove the volume and let Docker recreate it:

```bash
docker compose down
docker volume rm webwork2_oplVolume
docker compose up -d
```

The first startup after this will be slower as it re-clones the Open Problem Library.

### Two-factor authentication prompt blocking login

Add `$twoFA{enabled} = 0;` to `conf/localOverrides.conf` and restart the app. See step 6 in the Docker setup above.
