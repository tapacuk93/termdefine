import Foundation

struct GlossaryEntry {
    let term: String
    let kind: String
    let text: String
}

/// Built-in explanations for the commands and abbreviations that show up in a terminal.
/// Checked before `whatis`, because these read better than a man-page summary line.
enum Glossary {

    static func entry(for term: String) -> GlossaryEntry? {
        let key = term.lowercased()
        if let e = table[key] { return e }
        // `git-commit`, `foo.sh`, `ls:` etc.
        let stripped = key.trimmingCharacters(in: CharacterSet(charactersIn: ".:,;"))
        if stripped != key, let e = table[stripped] { return e }
        return nil
    }

    private static let table: [String: GlossaryEntry] = {
        var map: [String: GlossaryEntry] = [:]
        for (term, kind, text) in raw {
            map[term] = GlossaryEntry(term: term, kind: kind, text: text)
        }
        return map
    }()

    // (term, kind, explanation)
    private static let raw: [(String, String, String)] = [
        // ── Navigation & files ────────────────────────────────────────────
        ("ls", "command", "List directory contents. “list”. -l long format, -a include dotfiles, -h human-readable sizes, -t sort by time."),
        ("cd", "builtin", "Change Directory. `cd -` jumps back to the previous directory, `cd` alone goes home."),
        ("pwd", "builtin", "Print Working Directory — the absolute path of the folder you're currently in."),
        ("mkdir", "command", "Make Directory. -p creates intermediate parents and doesn't error if it already exists."),
        ("rmdir", "command", "Remove Directory — only works on empty directories."),
        ("rm", "command", "Remove files. -r recurses into directories, -f forces without prompting. There is no undo."),
        ("cp", "command", "Copy files or directories. -r for directories, -a to preserve attributes, -n to not overwrite."),
        ("mv", "command", "Move (or rename) files and directories."),
        ("ln", "command", "Link — create a link to a file. `ln -s target name` makes a symbolic link (a shortcut/alias)."),
        ("touch", "command", "Update a file's timestamps, creating an empty file if it doesn't exist."),
        ("cat", "command", "Concatenate — print file contents to standard output, or join several files together."),
        ("less", "command", "Pager: scroll through output a screen at a time. q quits, / searches, G jumps to the end."),
        ("more", "command", "Older, simpler pager than `less`."),
        ("head", "command", "Print the first lines of a file. -n 20 for the first 20."),
        ("tail", "command", "Print the last lines of a file. -f follows the file as it grows — the classic log watcher."),
        ("find", "command", "Walk a directory tree looking for files by name, size, age, type, etc."),
        ("tree", "command", "Print a directory as an indented tree."),
        ("file", "command", "Guess what type a file actually is, by inspecting its contents."),
        ("stat", "command", "Show a file's metadata: size, permissions, owner, timestamps, inode."),
        ("basename", "command", "Strip the directory (and optionally the suffix) from a path."),
        ("dirname", "command", "Print the directory part of a path."),
        ("realpath", "command", "Resolve a path to its absolute, symlink-free form."),

        // ── Text processing ───────────────────────────────────────────────
        ("grep", "command", "Global Regular Expression Print — search text for lines matching a pattern. -i ignores case, -r recurses, -v inverts, -n shows line numbers."),
        ("egrep", "command", "`grep -E`: grep with extended regular expressions."),
        ("rg", "command", "ripgrep — a fast recursive grep that respects .gitignore by default."),
        ("ag", "command", "The Silver Searcher — a fast recursive code search tool."),
        ("sed", "command", "Stream EDitor — transform text as it flows through. `sed 's/old/new/g'` is the classic substitution."),
        ("awk", "command", "Pattern-directed scanning and processing language, named after its authors Aho, Weinberger and Kernighan. `awk '{print $2}'` prints the second column."),
        ("cut", "command", "Extract columns from each line. -d sets the delimiter, -f picks the fields."),
        ("tr", "command", "Translate or delete characters, e.g. `tr 'a-z' 'A-Z'` to uppercase."),
        ("sort", "command", "Sort lines. -n numeric, -r reverse, -u unique, -k picks the sort column."),
        ("uniq", "command", "Collapse adjacent duplicate lines. -c counts them. Usually preceded by `sort`."),
        ("wc", "command", "Word Count — count lines (-l), words (-w) and bytes (-c)."),
        ("tee", "command", "Split a pipeline: write input to a file *and* pass it along to standard output."),
        ("xargs", "command", "Turn lines of input into arguments for another command. `find . -name '*.log' | xargs rm`."),
        ("diff", "command", "Show the differences between two files. -u gives the unified format used by patches."),
        ("patch", "command", "Apply a diff file to a source tree."),
        ("jq", "command", "A command-line JSON processor: filter, reshape and pretty-print JSON."),
        ("yq", "command", "Like `jq`, but for YAML."),
        ("echo", "builtin", "Print its arguments to standard output."),
        ("printf", "builtin", "Print formatted text, like C's printf. More predictable than `echo` across shells."),
        ("seq", "command", "Print a sequence of numbers, e.g. `seq 1 10`."),
        ("yes", "command", "Repeatedly print a string (default `y`) — used to auto-answer prompts."),

        // ── Permissions & ownership ───────────────────────────────────────
        ("chmod", "command", "CHange MODe — set file permissions. `chmod +x file` makes it executable; `755` = owner rwx, group/other r-x."),
        ("chown", "command", "CHange OWNer of a file, e.g. `chown user:group file`."),
        ("chgrp", "command", "CHange GRouP ownership of a file."),
        ("umask", "builtin", "User MASK — the permission bits masked *off* from newly created files (commonly 022)."),
        ("sudo", "command", "Substitute User DO — run a command as another user, usually root. Prompts for your password."),
        ("su", "command", "Substitute User — switch to another user's shell account."),
        ("whoami", "command", "Print the username you're currently acting as."),
        ("id", "command", "Show your user id, group id and group memberships."),
        ("passwd", "command", "Change a user's password."),

        // ── Processes ─────────────────────────────────────────────────────
        ("ps", "command", "Process Status — list running processes. `ps aux` is the everything-everywhere form."),
        ("top", "command", "Live view of processes sorted by CPU or memory use."),
        ("htop", "command", "A friendlier, colourised `top` with scrolling and mouse support."),
        ("kill", "builtin", "Send a signal to a process by PID. Default is TERM (polite); `kill -9` is KILL (immediate)."),
        ("killall", "command", "Send a signal to every process matching a *name* rather than a PID."),
        ("pkill", "command", "Kill processes matched by name or other attributes."),
        ("pgrep", "command", "Find process IDs matching a name or pattern."),
        ("jobs", "builtin", "List the background jobs belonging to this shell."),
        ("fg", "builtin", "ForeGround — bring a background job back to the foreground."),
        ("bg", "builtin", "BackGround — resume a suspended job in the background."),
        ("nohup", "command", "NO HangUP — run a command so it survives the terminal being closed."),
        ("nice", "command", "Run a command with an adjusted scheduling priority."),
        ("time", "builtin", "Measure how long a command takes (real, user and system time)."),
        ("watch", "command", "Re-run a command every N seconds and show the latest output."),
        ("caffeinate", "command", "macOS: prevent the Mac from sleeping while a command runs."),
        ("open", "command", "macOS: open a file, folder or URL with its default app. `open .` reveals the folder in Finder."),
        ("pbcopy", "command", "macOS: PasteBoard COPY — pipe text into the clipboard."),
        ("pbpaste", "command", "macOS: PasteBoard PASTE — print the clipboard's contents."),

        // ── Disks & archives ──────────────────────────────────────────────
        ("df", "command", "Disk Free — show free space per mounted filesystem. -h for human-readable units."),
        ("du", "command", "Disk Usage — how much space a directory tree occupies. `du -sh *` is the usual invocation."),
        ("mount", "command", "Attach a filesystem to the directory tree, or list what's currently mounted."),
        ("umount", "command", "Detach a mounted filesystem."),
        ("diskutil", "command", "macOS disk management: list, erase, mount, partition and repair volumes."),
        ("tar", "command", "Tape ARchive — bundle files into one archive. `tar -czf x.tgz dir` creates, `-xzf` extracts."),
        ("gzip", "command", "Compress a file with the GNU zip algorithm (.gz)."),
        ("gunzip", "command", "Decompress a .gz file."),
        ("zip", "command", "Create a .zip archive."),
        ("unzip", "command", "Extract a .zip archive."),

        // ── Network ───────────────────────────────────────────────────────
        ("curl", "command", "Client URL — transfer data to or from a server. -O saves to a file, -H adds a header, -X sets the method."),
        ("wget", "command", "Download files over HTTP/FTP, with recursion and resume support."),
        ("ssh", "command", "Secure SHell — log into a remote machine over an encrypted connection."),
        ("scp", "command", "Secure CoPy — copy files between machines over SSH."),
        ("sftp", "command", "Secure File Transfer Protocol — an interactive file transfer session over SSH."),
        ("rsync", "command", "Remote SYNC — efficiently sync directories, copying only what changed. -av is the common pair."),
        ("ping", "command", "Send ICMP echo requests to check whether a host is reachable and how fast."),
        ("traceroute", "command", "Show the network hops packets take to reach a host."),
        ("dig", "command", "Domain Information Groper — query DNS records."),
        ("nslookup", "command", "Older interactive DNS lookup tool."),
        ("host", "command", "Simple DNS lookup utility."),
        ("netstat", "command", "Show network connections, routing tables and interface statistics."),
        ("lsof", "command", "LiSt Open Files — which processes have which files or ports open. `lsof -i :3000` finds who's on a port."),
        ("ifconfig", "command", "Configure or display network interfaces (the older BSD tool)."),
        ("nc", "command", "netcat — read and write raw TCP/UDP connections. The network Swiss army knife."),
        ("telnet", "command", "Plain-text remote login; today mostly used to poke at a TCP port."),

        // ── Shell & environment ───────────────────────────────────────────
        ("env", "command", "Print the environment variables, or run a command with a modified environment."),
        ("export", "builtin", "Mark a shell variable so child processes inherit it: `export PATH=…`."),
        ("alias", "builtin", "Define a shorthand for a longer command, e.g. `alias ll='ls -la'`."),
        ("unalias", "builtin", "Remove an alias."),
        ("source", "builtin", "Run a script in the *current* shell so its variables and functions stick. Same as `.`."),
        ("which", "command", "Show which executable on your PATH would run for a given name."),
        ("whereis", "command", "Locate the binary, source and man page for a command."),
        ("type", "builtin", "Say what a name is: alias, shell builtin, function, or file on disk."),
        ("history", "builtin", "List the commands you've run. `!42` re-runs number 42, `!!` re-runs the last one."),
        ("man", "command", "MANual — read a command's reference page. `man 3 printf` picks section 3."),
        ("whatis", "command", "Print the one-line description from a command's man page."),
        ("apropos", "command", "Search the man page descriptions by keyword — `man -k`."),
        ("exit", "builtin", "Leave the shell, optionally with a status code."),
        ("clear", "command", "Clear the terminal screen (⌃L does the same)."),
        ("read", "builtin", "Read a line of input into a shell variable."),
        ("test", "builtin", "Evaluate a condition; the `[ ... ]` form is the same command."),
        ("set", "builtin", "Set shell options or positional parameters. `set -e` exits on error, `set -x` traces commands."),
        ("trap", "builtin", "Run a command when the shell receives a signal — used for cleanup handlers."),
        ("date", "command", "Print or set the system date and time; formats with `+%Y-%m-%d`."),
        ("cal", "command", "Print a calendar."),
        ("sleep", "command", "Do nothing for N seconds."),
        ("uname", "command", "Print system information. `uname -a` gives kernel, host and architecture."),
        ("sysctl", "command", "Read or write kernel state variables."),
        ("defaults", "command", "macOS: read and write app preferences in the user defaults system."),
        ("launchctl", "command", "macOS: manage launchd services (daemons and agents)."),
        ("sw_vers", "command", "macOS: print the OS version and build number."),
        ("softwareupdate", "command", "macOS: check for and install system updates from the command line."),
        ("screen", "command", "Terminal multiplexer — detachable sessions that survive disconnects."),
        ("tmux", "command", "Terminal MUltipleXer — split panes, multiple windows, detachable sessions."),

        // ── Shells ────────────────────────────────────────────────────────
        ("sh", "shell", "The POSIX shell — the lowest common denominator scripting shell."),
        ("bash", "shell", "Bourne Again SHell — the long-standing default Linux shell."),
        ("zsh", "shell", "Z SHell — the default macOS shell since Catalina; bash-compatible with better completion."),
        ("fish", "shell", "Friendly Interactive SHell — autosuggestions and syntax highlighting out of the box, but not POSIX."),
        ("ksh", "shell", "Korn SHell."),
        ("csh", "shell", "C SHell — C-like syntax; largely superseded by tcsh/zsh."),

        // ── Dev tooling ───────────────────────────────────────────────────
        ("git", "command", "Distributed version control. Tracks changes as commits you can branch, merge and push."),
        ("commit", "git", "A snapshot of your repository at a point in time, with a message and a parent."),
        ("rebase", "git", "Replay your commits on top of another branch, rewriting history to keep it linear."),
        ("stash", "git", "Shelve uncommitted changes so you can switch branches, then `git stash pop` to bring them back."),
        ("origin", "git", "The conventional name for the remote repository you cloned from."),
        ("head", "git", "`HEAD` — a pointer to the commit you currently have checked out."),
        ("make", "command", "Build tool driven by a Makefile of targets, dependencies and recipes."),
        ("cmake", "command", "Cross-platform build system generator — produces Makefiles or Ninja/Xcode projects."),
        ("gcc", "command", "GNU Compiler Collection — the C/C++ compiler driver."),
        ("clang", "command", "The LLVM C/C++/Objective-C compiler; what Xcode uses."),
        ("swiftc", "command", "The Swift compiler."),
        ("brew", "command", "Homebrew — the macOS package manager. `brew install`, `brew upgrade`, `brew list`."),
        ("npm", "command", "Node Package Manager — installs and runs JavaScript packages and scripts."),
        ("npx", "command", "Run a Node package binary without installing it globally."),
        ("yarn", "command", "An alternative Node package manager."),
        ("pnpm", "command", "Performant NPM — a Node package manager that hard-links a shared store to save disk."),
        ("pip", "command", "Package Installer for Python."),
        ("python", "command", "The Python interpreter. On macOS you usually want `python3`."),
        ("node", "command", "The Node.js JavaScript runtime."),
        ("deno", "command", "A secure JavaScript/TypeScript runtime with built-in tooling."),
        ("bun", "command", "A fast JavaScript runtime, bundler and package manager."),
        ("cargo", "command", "Rust's build tool and package manager."),
        ("go", "command", "The Go toolchain: `go build`, `go run`, `go test`."),
        ("docker", "command", "Build and run applications in containers."),
        ("kubectl", "command", "Kube ConTroL — the Kubernetes cluster CLI."),
        ("terraform", "command", "Declarative infrastructure-as-code provisioning tool."),
        ("vim", "command", "Modal text editor. `:q!` quits without saving, `:wq` saves and quits, i enters insert mode."),
        ("nvim", "command", "Neovim — a modernised fork of vim."),
        ("nano", "command", "A simple terminal text editor; shortcuts are listed at the bottom (^X to exit)."),
        ("emacs", "command", "Extensible text editor and environment. C-x C-c exits."),

        // ── Abbreviations & concepts ──────────────────────────────────────
        ("stdin", "abbreviation", "STanDard INput — file descriptor 0, where a program reads input from by default."),
        ("stdout", "abbreviation", "STanDard OUTput — file descriptor 1, where normal program output goes."),
        ("stderr", "abbreviation", "STanDard ERRor — file descriptor 2, a separate stream for errors so they survive piping."),
        ("pid", "abbreviation", "Process IDentifier — the number the kernel uses to refer to a running process."),
        ("ppid", "abbreviation", "Parent Process IDentifier — the PID of the process that spawned this one."),
        ("tty", "abbreviation", "TeleTYpewriter — the terminal device a process is attached to. `tty` prints yours."),
        ("pts", "abbreviation", "Pseudo-Terminal Slave — the device name of a virtual terminal, e.g. /dev/ttys002."),
        ("cwd", "abbreviation", "Current Working Directory — the folder a process resolves relative paths against."),
        ("path", "abbreviation", "`$PATH` — the colon-separated list of directories the shell searches for executables."),
        ("home", "abbreviation", "`$HOME` — your home directory, also written `~`."),
        ("shell", "concept", "The program that reads your commands and runs them — bash, zsh, fish and friends."),
        ("cli", "abbreviation", "Command-Line Interface."),
        ("tui", "abbreviation", "Text User Interface — a full-screen interface drawn with text, like htop or vim."),
        ("repl", "abbreviation", "Read-Eval-Print Loop — an interactive prompt that evaluates expressions as you type them."),
        ("regex", "abbreviation", "REGular EXpression — a pattern language for matching text."),
        ("symlink", "concept", "Symbolic link — a file that points at another path. Created with `ln -s`."),
        ("inode", "concept", "The on-disk record holding a file's metadata and data pointers; the filename just points at it."),
        ("dotfile", "concept", "A file whose name starts with `.` — hidden by default, usually configuration (.zshrc, .gitconfig)."),
        ("rc", "abbreviation", "Run Commands — the suffix on startup config files like .bashrc and .zshrc, from an old CTSS command."),
        ("pipe", "concept", "`|` — send one command's standard output into the next command's standard input."),
        ("redirect", "concept", "`>` writes output to a file (truncating), `>>` appends, `<` reads input from a file, `2>` redirects errors."),
        ("sigterm", "abbreviation", "SIGnal TERMinate (15) — the polite “please shut down” signal, which a program can handle."),
        ("sigkill", "abbreviation", "SIGnal KILL (9) — immediate termination that a process cannot catch or ignore."),
        ("sigint", "abbreviation", "SIGnal INTerrupt (2) — what ⌃C sends."),
        ("eof", "abbreviation", "End Of File — signalled interactively with ⌃D."),
        ("exit code", "concept", "The number a command returns: 0 means success, anything else is failure. `$?` holds the last one."),
        ("posix", "abbreviation", "Portable Operating System Interface — the standard that makes Unix-like systems behave alike."),
        ("gnu", "abbreviation", "GNU's Not Unix — the free software project supplying many core Linux userland tools."),
        ("bsd", "abbreviation", "Berkeley Software Distribution — the Unix lineage macOS's userland comes from, so flags often differ from GNU."),
        ("ansi", "abbreviation", "The escape-code standard terminals use for colour and cursor movement."),
        ("utf-8", "abbreviation", "Unicode Transformation Format, 8-bit — the standard variable-width text encoding."),
        ("ascii", "abbreviation", "American Standard Code for Information Interchange — the original 7-bit character set."),
        ("json", "abbreviation", "JavaScript Object Notation — a text data format of objects, arrays, strings and numbers."),
        ("yaml", "abbreviation", "YAML Ain't Markup Language — an indentation-based configuration format."),
        ("csv", "abbreviation", "Comma-Separated Values — plain-text tabular data."),
        ("url", "abbreviation", "Uniform Resource Locator — the address of a resource, e.g. https://example.com/path."),
        ("ssl", "abbreviation", "Secure Sockets Layer — the predecessor to TLS; the name stuck in tool and library names."),
        ("tls", "abbreviation", "Transport Layer Security — the encryption behind https."),
        ("dns", "abbreviation", "Domain Name System — translates hostnames into IP addresses."),
        ("tcp", "abbreviation", "Transmission Control Protocol — ordered, reliable, connection-based networking."),
        ("udp", "abbreviation", "User Datagram Protocol — fire-and-forget packets, no delivery guarantee."),
        ("ip", "abbreviation", "Internet Protocol — the addressing and routing layer of the internet."),
        ("api", "abbreviation", "Application Programming Interface."),
        ("sdk", "abbreviation", "Software Development Kit."),
        ("env var", "concept", "Environment variable — a name/value pair inherited by child processes, like PATH or EDITOR."),
    ]
}
