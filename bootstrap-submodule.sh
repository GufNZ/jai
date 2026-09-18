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
IGNORED_ARCHIVE=""
IGNORED_ACTION=""
FILTER_REPO_PYTHON=""
ROLLBACK_SUBPATH=""

cleanup() {
	cd "$ROOT"

	if [ -n "$TMP" ] && [ -d "$TMP" ]; then
		rm -rf "$TMP"
	fi

	if [ -n "$ROLLBACK_SUBPATH" ]; then
		warning "Restoring tracked source after failed submodule replacement:"
		warning "	$ROLLBACK_SUBPATH"

		if ! git restore \
			--source=HEAD \
			--staged \
			--worktree \
			-- "$ROLLBACK_SUBPATH"; then
			error "Automatic source restoration failed."
		fi
	fi

	if [ -n "$IGNORED_ARCHIVE" ] && [ -f "$IGNORED_ARCHIVE" ]; then
		tar -xzf "$IGNORED_ARCHIVE" -C "$ROOT"
		rm -f "$IGNORED_ARCHIVE"
	fi
}

trap cleanup EXIT

ensure_filter_repo() {
	local PYTHON

	for PYTHON in python3 python
	do
		if command -v "$PYTHON" >/dev/null 2>&1 && \
			"$PYTHON" -c 'import git_filter_repo' >/dev/null 2>&1; then
			FILTER_REPO_PYTHON="$(command -v "$PYTHON")"
			return
		fi
	done

	for PYTHON in python3 python
	do
		if command -v "$PYTHON" >/dev/null 2>&1 && \
			"$PYTHON" -m pip --version >/dev/null 2>&1; then
			FILTER_REPO_PYTHON="$(command -v "$PYTHON")"
			break
		fi
	done

	if [ -z "$FILTER_REPO_PYTHON" ]; then
		error "Python with pip is required to install git-filter-repo."
		exit 1
	fi


	normal "Installing git-filter-repo..."
	"$FILTER_REPO_PYTHON" -m pip install git-filter-repo

	if ! "$FILTER_REPO_PYTHON" -c 'import git_filter_repo' >/dev/null 2>&1; then
		error "git-filter-repo was installed but cannot be imported by:"
		error "	$FILTER_REPO_PYTHON"
		exit 1
	fi
}

bootstrap_usage() {
	error "Usage:"
	error "	$0"
	error "	$0 directory"
	exit 1
}

validate_normal_directory() {
	local SUBPATH="$1"
	local DIRECTORY_ROOT
	local NORMALIZED_SUBPATH

	if [ -z "$SUBPATH" ] || \
		[ ! -d "$SUBPATH" ] || \
		[[ "$SUBPATH" = *'|'* ]] || \
		[[ "$SUBPATH" = *$'\n'* ]] || \
		[[ "$SUBPATH" = *$'\r'* ]]; then
		bootstrap_usage
	fi


	DIRECTORY_ROOT="$(git -C "$SUBPATH" rev-parse --show-toplevel 2>/dev/null)" || bootstrap_usage
	NORMALIZED_SUBPATH="$(git -C "$SUBPATH" rev-parse --show-prefix 2>/dev/null)" || bootstrap_usage
	NORMALIZED_SUBPATH="${NORMALIZED_SUBPATH%/}"


	if [ -z "$NORMALIZED_SUBPATH" ] || [ "$DIRECTORY_ROOT" != "$ROOT" ] || is_submodule "$NORMALIZED_SUBPATH"; then
		bootstrap_usage
	fi


	printf '%s\n' "$NORMALIZED_SUBPATH"
}

add_conf_entry() {
	local SUBPATH="$1"
	local URL

	SUBPATH="$(validate_normal_directory "$SUBPATH")"

	if [ -f "$CONF" ] && awk -F '|' -v path="$SUBPATH" '$1 == path { found = 1 } END { exit !found }' "$CONF"; then
		error "Directory is already configured:"
		error "	$SUBPATH"
		exit 1
	fi


	normal "Create EMPTY GitHub repository:"
	prompt "Git URL: "
	read -r URL

	if [ -z "$URL" ] || \
		[[ "$URL" = *'|'* ]] || \
		[[ "$URL" = *$'\n'* ]] || \
		[[ "$URL" = *$'\r'* ]]; then
		error "No valid URL supplied."
		exit 1
	fi


	printf '%s|%s\n' "$SUBPATH" "$URL" >> "$CONF"
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


	add_conf_entry "$SUBPATH"
}

install_commit_script() {
	local COMMIT_SCRIPT=".repo-tools/commit-all.sh"

	mkdir -p .repo-tools

	if [ -f "$COMMIT_SCRIPT" ] && \
		! grep -q '^# Installed by bootstrap-submodule.sh$' "$COMMIT_SCRIPT"; then
		warning "Preserving existing unmanaged commit helper:"
		warning "	$COMMIT_SCRIPT"
		chmod +x "$COMMIT_SCRIPT"
		return
	fi


	cat > "$COMMIT_SCRIPT" <<'EOF'
#!/usr/bin/env bash
# Installed by bootstrap-submodule.sh

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

read_choice() {
	local NONINTERACTIVE_CHOICE="$1"
	local NONINTERACTIVE_MESSAGE="$2"

	if [ -t 0 ]; then
		prompt "Choice: "
		read -r CHOICE
		return
	fi


	CHOICE="$NONINTERACTIVE_CHOICE"
	warning "$NONINTERACTIVE_MESSAGE"
}

submodule_git() {
	local SUBMODULE="$1"
	local VARIABLE

	shift

	(
		for VARIABLE in $(git rev-parse --local-env-vars)
		do
			unset "$VARIABLE"
		done

		git -C "$SUBMODULE" "$@"
	)
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


	INDEX_MODE="$(git ls-files --stage -- "$SUBMODULE" | awk 'NR == 1 { print $1 }')"

	if [ "$INDEX_MODE" != "160000" ]; then
		error "Configured path is not a submodule:"
		error "	$SUBMODULE"
		exit 1
	fi


	if [ -z "$(submodule_git "$SUBMODULE" rev-parse --show-superproject-working-tree 2>/dev/null)" ]; then
		error "Submodule is not initialized:"
		error "	$SUBMODULE"
		exit 1
	fi


	STATUS="$(submodule_git "$SUBMODULE" status --porcelain --untracked-files=normal)"
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
		submodule_git "$SUBMODULE" status --short
		normal "1) Abort"
		normal "2) Stage everything and continue"
		normal "3) Commit only staged changes"

		read_choice 3 \
			"No interactive input available; committing only staged changes."
		case "$CHOICE" in
			2)
				submodule_git "$SUBMODULE" add -A
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
		submodule_git "$SUBMODULE" status --short
		normal "1) Abort"
		normal "2) Stage everything and continue"

		read_choice 1 \
			"No interactive input available; stage the submodule changes or run commit-all.sh from a terminal."
		case "$CHOICE" in
			2)
				submodule_git "$SUBMODULE" add -A
				;;
			*)
				exit 1
				;;
		esac
	fi


	if ! submodule_git "$SUBMODULE" diff --cached --quiet; then
		normal "Committing $SUBMODULE ..."

		submodule_git "$SUBMODULE" \
			-c core.hooksPath=/dev/null \
			commit -m "$MESSAGE"

		submodule_git "$SUBMODULE" push
		git add "$SUBMODULE"
		SUBMODULE_COMMITTED=1
	fi
done 3< "$CONF"

if [ "$SUBMODULE_COMMITTED" -eq 0 ]; then
	normal "No submodule changes; continuing normal commit."
	rm -f "$FAILED_FILE"
	COMPLETED=1
	exit 0
fi


normal "Creating parent commit..."

git \
	-c core.hooksPath=/dev/null \
	commit -m "$MESSAGE"

git push

rm -f "$FAILED_FILE"
touch "$SUCCESS_FILE"
COMPLETED=1
EOF


	chmod +x "$COMMIT_SCRIPT"
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

	if [ -z "$(git status --porcelain --untracked-files=all -- "$PATHNAME")" ]; then
		return
	fi


	error "Refusing to extract a directory with local changes:"
	error "	$PATHNAME"
	git status --short --untracked-files=all -- "$PATHNAME"
	exit 1
}

prepare_ignored_content() {
	local PATHNAME="$1"

	if [ -z "$(git ls-files --others --ignored --exclude-standard -- "$PATHNAME")" ]; then
		return
	fi


	warning "Ignored files found under:"
	warning "	$PATHNAME"
	git status --short --ignored --untracked-files=all -- "$PATHNAME"

	normal "Options:"
	normal "1) Abort"
	normal "2) Delete ignored files and continue"
	normal "3) Preserve ignored files and continue"

	prompt "Choice: "
	read -r CHOICE

	case "$CHOICE" in
		2)
			IGNORED_ACTION="delete"
			;;
		3)
			IGNORED_ACTION="preserve"
			IGNORED_ARCHIVE="$(mktemp "${TMPDIR:-/tmp}/submodule-ignored.XXXXXX.tar.gz")"
			git ls-files \
				--others \
				--ignored \
				--exclude-standard \
				-z \
				-- "$PATHNAME" |
				tar --null -T - -czf "$IGNORED_ARCHIVE"
			;;
		*)
			exit 1
			;;
	esac
}

remove_ignored_content() {
	local PATHNAME="$1"

	if [ -n "$IGNORED_ACTION" ]; then
		git clean -fdX -- "$PATHNAME"
	fi
}

restore_ignored_content() {
	local PATHNAME="$1"

	if [ "$IGNORED_ACTION" != "preserve" ]; then
		return
	fi


	tar -xzf "$IGNORED_ARCHIVE" -C "$ROOT"
	rm -f "$IGNORED_ARCHIVE"
	IGNORED_ARCHIVE=""
	IGNORED_ACTION=""

	warning "Restored ignored files under:"
	warning "	$PATHNAME"
	warning "Add suitable ignore rules to the submodule if they appear as untracked files."
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


exit 0
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

is_submodule() {
	local SUBPATH="$1"
	local INDEX_MODE

	INDEX_MODE="$(git ls-files --stage -- "$SUBPATH" | awk 'NR == 1 { print $1 }')"
	[ "$INDEX_MODE" = "160000" ]
}

is_pending_submodule_conversion() {
	local SUBPATH="$1"
	local HEAD_MODE

	HEAD_MODE="$(git ls-tree HEAD -- "$SUBPATH" | awk 'NR == 1 { print $1 }')"
	[ "$HEAD_MODE" != "160000" ]
}

commit_submodule_conversion() {
	local SUBPATH="$1"

	git add .gitmodules
	git add -f "$SUBPATH"

	git \
		-c core.hooksPath=/dev/null \
		commit \
		--only \
		-m "Convert $SUBPATH to submodule" \
		-- .gitmodules "$SUBPATH"
}

extract_submodule() {
	local SUBPATH="$1"
	local URL="$2"

	if is_submodule "$SUBPATH"; then
		if [ -z "$(git -C "$SUBPATH" rev-parse --show-superproject-working-tree 2>/dev/null)" ]; then
			normal "Initializing submodule: $SUBPATH"
			git submodule update --init -- "$SUBPATH"
		fi

		normal "Skipping existing submodule:"
		normal "	$SUBPATH"

		if is_pending_submodule_conversion "$SUBPATH"; then
			normal "Completing interrupted submodule conversion:"
			normal "	$SUBPATH"
			commit_submodule_conversion "$SUBPATH"
		fi

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
	prepare_ignored_content "$SUBPATH"
	ensure_filter_repo

	local REPONAME

	REPONAME="$(basename "$SUBPATH")"
	TMP="$(mktemp -d "../${REPONAME}-extract.XXXXXX")"

	normal "Extracting:"
	normal "	$SUBPATH"

	git clone . "$TMP"
	TMP="$(cd "$TMP" && pwd)"

	pushd "$TMP" >/dev/null

	"$FILTER_REPO_PYTHON" -m git_filter_repo \
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
	remove_ignored_content "$SUBPATH"
	ROLLBACK_SUBPATH="$SUBPATH"
	git rm -r "$SUBPATH"

	git submodule add \
		-f \
		-b main \
		"$URL" \
		"$SUBPATH"
	ROLLBACK_SUBPATH=""

	restore_ignored_content "$SUBPATH"

	git -C "$SUBPATH" switch main
	git config -f .gitmodules \
		"submodule.$SUBPATH.branch" \
		main

	commit_submodule_conversion "$SUBPATH"

	install_detached_head_hook "$SUBPATH"
}

if [ $# -gt 1 ]; then
	bootstrap_usage
fi

if [ $# -eq 1 ]; then
	add_conf_entry "$1"
else
	create_conf_if_missing
fi

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
