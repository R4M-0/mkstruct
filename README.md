## `mkstruct` — Text-to-Folder Generator

`mkstruct` is a lightweight Bash utility that transforms text-based directory trees into actual physical file systems. Whether you are scaffolding a new project from a documentation snippet or recreating a GitHub-style tree structure locally, `mkstruct` handles the heavy lifting safely.

---

### Features

* **Format Agnostic:** Supports standard 2-space indentation and complex "tree" command output (using `│`, `├──`, etc.).
* **Dry Run Mode:** Preview exactly what will happen before a single folder is created.
* **Safety First:** Prevents path traversal (`..`) and absolute path execution to keep your system secure.
* **Auto-Parent Creation:** Automatically creates parent directories if a nested file is defined.
* **Colorized Output:** Clear visual feedback for directories, files, and errors.

---

### Installation

1. Save the script as `mkstruct`.
2. Make it executable:
```bash
chmod +x mkstruct

```


3. (Optional) Move it to your path:
```bash
mv mkstruct /usr/local/bin/

```



---

### Usage

#### 1. From a File

Create a text file (e.g., `layout.txt`) and run:

```bash
mkstruct layout.txt

```

#### 2. From Stdin

Perfect for copying snippets from the web or documentation:

```bash
cat << 'EOF' | mkstruct --stdin
my_app/
  src/
    api/
      routes.py
    main.py
  requirements.txt
EOF

```

#### 3. To a Specific Location

Use the `--base` flag to build the structure somewhere other than your current directory:

```bash
mkstruct structure.txt --base ./projects/new-app

```

#### 4. Dry Run (Test Mode)

See what would happen without creating any files:

```bash
mkstruct structure.txt --dry-run

```

---

### Input Formats

The script intelligently handles two main types of input:

**Indented Format:**

```text
project/
  docs/
    index.md
  src/
    utils.py
  README.md

```

**Tree Format (GitHub/Terminal Style):**

```text
project/
├── docs/
│   └── index.md
├── src/
│   └── utils.py
└── README.md

```

> **Note:** Directories **must** end with a trailing slash (`/`) to be recognized as folders.

---

### Options Reference

| Option | Description |
| --- | --- |
| `--base <path>` | Sets the root directory where the structure starts. |
| `--dry-run` | Logs actions to the console without modifying the disk. |
| `--stdin` | Reads the structure from standard input. |
| `--help` | Displays the help menu. |

---

### Safety Note

For security reasons, `mkstruct` will reject any input containing:

1. **Absolute Paths** (e.g., `/etc/passwd`)
2. **Parent Directory References** (e.g., `../secrets`)
