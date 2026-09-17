#!/usr/bin/env bash

set -e

ROOT="$(git rev-parse --show-toplevel)"

cd "$ROOT"

CONF="submodules.conf"

NORMAL=$'\e[96m'
WARNING=$'\e[93m'
ERROR=$'\e[91m'
INPUT=$'\e[95m'
RESET=$'\e[0m'

normal() {
	printf '%b%s%b\n' "$NORMAL" "$*" "$RESET"
}

warning() {
	printf '%b%s%b\n' "$WARNING" "$*" "$RESET" >&2
}

error() {
	printf '%b%s%b\n' "$ERROR" "$*" "$RESET" >&2
}

prompt() {
	printf '%b%s%b' "$INPUT" "$*" "$RESET"
}

TMP=""

cleanup() {
	if [ -n "$TMP" ] && [ -d "$TMP" ]; then
		rm -rf "$TMP"
	fi
}

trap cleanup EXIT

ensure_filter_repo() {
	if command -v git-filter-repo >/dev/null 2>&1; then
		return
	fi


	normal "Installing git-filter-repo..."
	python -m pip install git-filter-repo
}

create_conf_if_missing() {
	if [ -f "$CONF" ]; then
		return
	fi


	normal "No submodules.conf found."

	prompt "First submodule path: "
	read -r SUBPATH

	if [ -z "$SUBPATH" ]; then
		error "No path supplied."
		exit 1
	fi


	normal "Create EMPTY GitHub repository:"
	prompt "Git URL: "
	read -r URL

	if [ -z "$URL" ]; then
		error "No URL supplied."
		exit 1
	fi


	printf '%s|%s\n' "$SUBPATH" "$URL" > "$CONF"
}

install_commit_script() {
	mkdir -p .repo-tools

	if [ ! -f .repo-tools/commit-all.sh ]; then
		cat > .repo-tools/commit-all.sh <<'EOF'
#!/usr/bin/env bash

set -e

ROOT="$(git rev-parse --show-toplevel)"

cd "$ROOT"

CONF="submodules.conf"

GITDIR="$(git rev-parse --git-dir)"

SUCCESS_FILE="$GITDIR/commit-all-success"
FAILED_FILE="$GITDIR/commit-all-failed"

NORMAL=$'\e[96m'
WARNING=$'\e[93m'
ERROR=$'\e[91m'
INPUT=$'\e[95m'
RESET=$'\e[0m'

normal() {
	printf '%b%s%b\n' "$NORMAL" "$*" "$RESET"
}

warning() {
	printf '%b%s%b\n' "$WARNING" "$*" "$RESET" >&2
}

error() {
	printf '%b%s%b\n' "$ERROR" "$*" "$RESET" >&2
}

prompt() {
	printf '%b%s%b' "$INPUT" "$*" "$RESET"
}

rm -f "$SUCCESS_FILE" "$FAILED_FILE"

COMPLETED=0

finish() {
	if [ "$COMPLETED" -eq 0 ]; then
		touch "$FAILED_FILE"
	fi
}

trap finish EXIT

MESSAGE=""
MESSAGE_FILE=""

usage() {
	error "Usage:"
	error "	$0 -m \"message\""
	error "	$0 -f messagefile"
	exit 1
}

while [ $# -gt 0 ]
do
	case "$1" in
		-m)
			[ $# -ge 2 ] || usage
			[ -z "$MESSAGE_FILE" ] || usage
			MESSAGE="$2"
			shift 2
			;;
		-f)
			[ $# -ge 2 ] || usage
			[ -z "$MESSAGE" ] || usage
			MESSAGE_FILE="$2"
			shift 2
			;;
		*)
			usage
			;;
	esac
done

if [ -n "$MESSAGE_FILE" ]; then
	if [ ! -f "$MESSAGE_FILE" ]; then
		error "Message file not found:"
		error "	$MESSAGE_FILE"
		exit 1
	fi


	MESSAGE="$(cat "$MESSAGE_FILE")"
fi

if [ -z "$MESSAGE" ]; then
	usage
fi

if [ ! -f "$CONF" ]; then
	error "Missing:"
	error "	$CONF"
	exit 1
fi


SUBMODULE_COMMITTED=0

while IFS='|' read -r SUBMODULE _URL <&3
do
	[ -z "$SUBMODULE" ] && continue


	case "$SUBMODULE" in
		\#*)
			continue
			;;
	esac


	if [ ! -d "$SUBMODULE" ]; then
		warning "Submodule missing:"
		warning "	$SUBMODULE"
		continue
	fi


	if ! git submodule status -- "$SUBMODULE" >/dev/null 2>&1; then
		error "Configured path is not a submodule:"
		error "	$SUBMODULE"
		exit 1
	fi


	if [ -z "$(git -C "$SUBMODULE" rev-parse --show-superproject-working-tree 2>/dev/null)" ]; then
		error "Submodule is not initialized:"
		error "	$SUBMODULE"
		exit 1
	fi


	STATUS="$(git -C "$SUBMODULE" status --porcelain --untracked-files=normal)"
	HAS_STAGED=0
	HAS_UNSTAGED=0

	while IFS= read -r STATUS_LINE
	do
		[ -z "$STATUS_LINE" ] && continue

		INDEX_STATUS="${STATUS_LINE:0:1}"
		WORKTREE_STATUS="${STATUS_LINE:1:1}"

		if [ "$INDEX_STATUS" != " " ] && [ "$INDEX_STATUS" != "?" ]; then
			HAS_STAGED=1
		fi

		if [ "$WORKTREE_STATUS" != " " ]; then
			HAS_UNSTAGED=1
		fi
	done <<< "$STATUS"

	if [ "$HAS_UNSTAGED" -eq 1 ] && [ "$HAS_STAGED" -eq 1 ]; then
		warning "Submodule $SUBMODULE contains staged and unstaged changes."
		normal "1) Abort"
		normal "2) Stage everything and continue"
		normal "3) Commit only staged changes"

		prompt "Choice: "
		read -r CHOICE
		case "$CHOICE" in
			2)
				git -C "$SUBMODULE" add -A
				;;
			3)
				;;
			*)
				exit 1
				;;
		esac
	fi


	if [ "$HAS_UNSTAGED" -eq 1 ] && [ "$HAS_STAGED" -eq 0 ]; then
		warning "Submodule $SUBMODULE contains only unstaged changes."
		normal "1) Abort"
		normal "2) Stage everything and continue"

		prompt "Choice: "
		read -r CHOICE
		case "$CHOICE" in
			2)
				git -C "$SUBMODULE" add -A
				;;
			*)
				exit 1
				;;
		esac
	fi


	if ! git -C "$SUBMODULE" diff --cached --quiet; then
		normal "Committing $SUBMODULE ..."

		git -C "$SUBMODULE" \
			-c core.hooksPath=/dev/null \
			commit -m "$MESSAGE"

		git -C "$SUBMODULE" push
		git add "$SUBMODULE"
		SUBMODULE_COMMITTED=1
	fi
done 3< "$CONF"

if ! git diff --cached --quiet || [ "$SUBMODULE_COMMITTED" -eq 1 ]; then
	normal "Creating parent commit..."

	git \
		-c core.hooksPath=/dev/null \
		commit -m "$MESSAGE"

	git push
else
	normal "Nothing to commit."
fi

rm -f "$FAILED_FILE"
touch "$SUCCESS_FILE"
COMPLETED=1
EOF
	fi


	chmod +x .repo-tools/commit-all.sh
}

verify_tracked_content() {
	local PATHNAME="$1"

	if [ -z "$(git ls-files -- "$PATHNAME")" ]; then
		error "No tracked files found under:"
		error "	$PATHNAME"
		exit 1
	fi
}

verify_clean_content() {
	local PATHNAME="$1"

	if [ -z "$(git status --porcelain --untracked-files=all --ignored -- "$PATHNAME")" ]; then
		return
	fi


	error "Refusing to extract a directory with local changes:"
	error "	$PATHNAME"
	git status --short --untracked-files=all --ignored -- "$PATHNAME"
	exit 1
}

check_ignore() {
	local PATHNAME="$1"

	if ! git check-ignore -q "$PATHNAME"; then
		return
	fi


	warning "Path is currently gitignored."

	git check-ignore -v "$PATHNAME"

	normal "Options:"
	normal "1) Abort"
	normal "2) Add negation rules automatically"

	prompt "Choice: "
	read -r CHOICE

	case "$CHOICE" in
		2)
			;;
		*)
			exit 1
			;;
	esac

	if [ -n "$(git status --porcelain -- .gitignore)" ]; then
		error "Refusing to modify a .gitignore with local changes."
		exit 1
	fi


	if [ ! -f .gitignore ]; then
		touch .gitignore
	fi

	printf '\n!%s/\n!%s/**\n' "$PATHNAME" "$PATHNAME" >> .gitignore

	normal "Added:"
	normal "	!${PATHNAME}/"
	normal "	!${PATHNAME}/**"

	if git check-ignore -q "$PATHNAME" || \
		git status --porcelain --ignored -- "$PATHNAME" | grep -q '^!! '; then
		error "Path contains content that is still ignored."
		exit 1
	fi


	git add -A -- .gitignore "$PATHNAME"

	git \
		-c core.hooksPath=/dev/null \
		commit \
		--only \
		-m "Expose ${PATHNAME} for submodule extraction" \
		-- .gitignore "$PATHNAME"
}

install_commit_hook() {
	local HOOKS_DIR
	local HOOK
	local USER_HOOK

	HOOKS_DIR="$(git rev-parse --git-path hooks)"
	HOOK="$HOOKS_DIR/commit-msg"
	USER_HOOK="$HOOKS_DIR/commit-msg.user"

	mkdir -p "$HOOKS_DIR"

	if [ -f "$HOOK" ] && \
		! grep -q '^# Installed by bootstrap-submodule.sh$' "$HOOK" && \
		! grep -q 'commit-all-active' "$HOOK"; then
		if [ -e "$USER_HOOK" ]; then
			error "Cannot preserve existing commit-msg hook:"
			error "	$USER_HOOK already exists."
			exit 1
		fi


		mv "$HOOK" "$USER_HOOK"
		warning "Preserved existing commit-msg hook as:"
		warning "	$USER_HOOK"
	fi

	cat > "$HOOK" <<'EOF'
#!/usr/bin/env bash
# Installed by bootstrap-submodule.sh

NORMAL=$'\e[96m'
ERROR=$'\e[91m'
RESET=$'\e[0m'

normal() {
	printf '%b%s%b\n' "$NORMAL" "$*" "$RESET"
}

error() {
	printf '%b%s%b\n' "$ERROR" "$*" "$RESET" >&2
}

LOCKFILE="$(git rev-parse --git-dir)/commit-all-active"

SUCCESS_FILE="$(git rev-parse --git-dir)/commit-all-success"

FAILED_FILE="$(git rev-parse --git-dir)/commit-all-failed"

if [ -f "$LOCKFILE" ]; then
	exit 0
fi


rm -f "$SUCCESS_FILE" "$FAILED_FILE"
touch "$LOCKFILE"

trap '
	rm -f "$LOCKFILE"
' EXIT

ROOT="$(git rev-parse --show-toplevel)"
HOOKS_DIR="$(cd "$(dirname "$0")" && pwd)"
USER_HOOK="$HOOKS_DIR/commit-msg.user"

if [ -x "$USER_HOOK" ]; then
	"$USER_HOOK" "$1"
fi

if ! "$ROOT/.repo-tools/commit-all.sh" -f "$1"; then
	error "========================================"
	error "commit-all reported failure."
	error "========================================"
	exit 1
fi

if [ -f "$SUCCESS_FILE" ]; then
	normal "========================================"
	normal "Commit completed via commit-all."
	normal "Refresh GitExtensions."
	normal "========================================"

	exit 1
fi


error "========================================"
error "commit-all did not create its success marker."
error "========================================"

exit 1
EOF

	chmod +x "$HOOK"
}

install_detached_head_hook() {
	local SUBMODULE="$1"
	local SUB_GITDIR
	local HOOK
	local USER_HOOK

	SUB_GITDIR="$(git -C "$SUBMODULE" rev-parse --git-dir)"
	HOOK="$SUB_GITDIR/hooks/pre-push"
	USER_HOOK="$SUB_GITDIR/hooks/pre-push.user"

	mkdir -p "$SUB_GITDIR/hooks"

	if [ -f "$HOOK" ] && \
		! grep -q '^# Installed by bootstrap-submodule.sh$' "$HOOK" && \
		! grep -q 'Submodule is in detached HEAD state' "$HOOK"; then
		if [ -e "$USER_HOOK" ]; then
			error "Cannot preserve existing pre-push hook:"
			error "	$USER_HOOK already exists."
			exit 1
		fi


		mv "$HOOK" "$USER_HOOK"
		warning "Preserved existing pre-push hook as:"
		warning "	$USER_HOOK"
	fi


	cat > "$HOOK" <<'EOF'
#!/usr/bin/env bash
# Installed by bootstrap-submodule.sh

ERROR=$'\e[91m'
RESET=$'\e[0m'

error() {
	printf '%b%s%b\n' "$ERROR" "$*" "$RESET" >&2
}

git symbolic-ref HEAD >/dev/null 2>&1
if [ $? -ne 0 ]; then
	error "Submodule is in detached HEAD state."
	error "Checkout a branch before pushing."

	exit 1
fi

HOOKS_DIR="$(cd "$(dirname "$0")" && pwd)"
USER_HOOK="$HOOKS_DIR/pre-push.user"

if [ -x "$USER_HOOK" ]; then
	"$USER_HOOK" "$@"
fi
EOF

	chmod +x "$HOOK"
}

extract_submodule() {
	local SUBPATH="$1"
	local URL="$2"

	if git submodule status "$SUBPATH" >/dev/null 2>&1; then
		if [ -z "$(git -C "$SUBPATH" rev-parse --show-superproject-working-tree 2>/dev/null)" ]; then
			normal "Initializing submodule: $SUBPATH"
			git submodule update --init -- "$SUBPATH"
		fi


		normal "Skipping existing submodule:"
		normal "	$SUBPATH"

		install_detached_head_hook "$SUBPATH"

		return
	fi


	if [ ! -d "$SUBPATH" ]; then
		error "Missing directory:"
		error "	$SUBPATH"
		exit 1
	fi

	check_ignore "$SUBPATH"

	verify_tracked_content "$SUBPATH"
	verify_clean_content "$SUBPATH"
	ensure_filter_repo

	local REPONAME

	REPONAME="$(basename "$SUBPATH")"
	TMP="$(mktemp -d "${TMPDIR:-/tmp}/${REPONAME}-extract.XXXXXX")"

	normal "Extracting:"
	normal "	$SUBPATH"

	git clone . "$TMP"

	pushd "$TMP" >/dev/null

	git filter-repo \
		--force \
		--path "$SUBPATH" \
		--path-rename "$SUBPATH/":

	git branch -M main
	git remote remove origin >/dev/null 2>&1 || true
	git remote add origin "$URL"
	git push -u origin main

	popd >/dev/null

	rm -rf "$TMP"
	TMP=""
	git rm -r "$SUBPATH"

	git submodule add \
		-b main \
		"$URL" \
		"$SUBPATH"

	git -C "$SUBPATH" switch main
	git config -f .gitmodules \
		"submodule.$SUBPATH.branch" \
		main

	git add .gitmodules
	git add "$SUBPATH"

	git \
		-c core.hooksPath=/dev/null \
		commit \
		--only \
		-m "Convert $SUBPATH to submodule" \
		-- .gitmodules "$SUBPATH"

	install_detached_head_hook "$SUBPATH"
}

create_conf_if_missing

install_commit_script

while IFS='|' read -r SUBPATH URL <&3
do
	SUBPATH="${SUBPATH%$'\r'}"
	URL="${URL%$'\r'}"

	[ -z "$SUBPATH" ] && continue


	case "$SUBPATH" in
		\#*)
			continue
			;;
	esac


	if [ -z "$URL" ]; then
		error "Missing URL for submodule:"
		error "	$SUBPATH"
		exit 1
	fi


	extract_submodule "$SUBPATH" "$URL"

done 3< "$CONF"

install_commit_hook

normal "Done."
