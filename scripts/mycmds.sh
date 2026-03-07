#!/bin/bash

# mycmds.sh — source mycmds.sh

if command -v tput >/dev/null 2>&1 && [ -t 1 ]; then
    RED="$(tput setaf 1)"; GREEN="$(tput setaf 2)"; YELLOW="$(tput setaf 3)"
    BLUE="$(tput setaf 4)"; MAGENTA="$(tput setaf 5)"; CYAN="$(tput setaf 6)"
    BOLD="$(tput bold)"; DIM="$(tput dim)"; RESET="$(tput sgr0)"
else
    RED="" GREEN="" YELLOW="" BLUE="" MAGENTA="" CYAN=""
    BOLD="" DIM="" RESET=""
fi

doing()   { echo -e "${BLUE}${BOLD}  → $*${RESET}"; }
done_()   { echo -e "${GREEN}${BOLD}  ✓ $*${RESET}"; }
fail()    { echo -e "${RED}${BOLD}  ✗ $*${RESET}"; }
hint()    { echo -e "${YELLOW}  $*${RESET}"; }

_branch() { git branch --show-current 2>/dev/null; }

_in_repo() {
    if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
        fail "not a git repo"; return 1
    fi
}

# ── pull ─────────────────────────────────────
pull() {
    _in_repo || return 1
    local b=$(_branch)
    [ -z "$b" ] && { fail "can't determine branch"; return 1; }
    doing "pulling $b"
    if git pull origin "$b" -q 2>/dev/null; then
        done_ "pulled $b"
    else
        fail "pull failed — resolve conflicts"
    fi
}

# ── fetch ────────────────────────────────────
fetch() {
    _in_repo || return 1
    doing "fetching remote"
    git fetch origin -q 2>/dev/null
    done_ "fetched"
}

# ── push ─────────────────────────────────────
push() {
    _in_repo || return 1
    local b=$(_branch)
    [ -z "$b" ] && { fail "can't determine branch"; return 1; }

    if git ls-remote --exit-code --heads origin "$b" >/dev/null 2>&1; then
        local ahead
        ahead=$(git rev-list --count origin/"$b"..HEAD 2>/dev/null)
        if [ "$ahead" = "0" ]; then
            hint "nothing to push on $b"
            return 0
        fi
        doing "pulling $b first"
        if ! git pull origin "$b" -q 2>/dev/null; then
            fail "pull failed — resolve conflicts before pushing"
            return 1
        fi
    else
        doing "first push for $b"
    fi

    doing "pushing $b"
    if git push -u origin "$b" -q 2>/dev/null; then
        done_ "pushed $b"
    else
        fail "push failed"
    fi
}

# ── ship (commit + push) ────────────────────
ship() {
    _in_repo || return 1

    if git diff --cached --quiet 2>/dev/null; then
        fail "nothing staged — stage files first with git add"
        return 1
    fi

    local msg="$*"
    if [ -z "$msg" ]; then
        echo -ne "${CYAN}${BOLD}  commit message: ${RESET}"
        read -r msg
        [ -z "$msg" ] && { fail "empty message"; return 1; }
    fi

    doing "committing: $msg"
    if ! git commit -m "$msg" -q 2>/dev/null; then
        fail "commit failed"
        return 1
    fi

    local b=$(_branch)
    if git ls-remote --exit-code --heads origin "$b" >/dev/null 2>&1; then
        doing "pulling $b first"
        if ! git pull origin "$b" -q 2>/dev/null; then
            fail "pull failed — resolve conflicts, then push"
            return 1
        fi
    else
        doing "first push for $b"
    fi

    doing "pushing $b"
    if git push -u origin "$b" -q 2>/dev/null; then
        done_ "shipped on $b"
    else
        fail "push failed"
    fi
}

# ── checkout ─────────────────────────────────
checkout() {
    _in_repo || return 1

    if [ -z "$1" ]; then
        hint "usage: checkout <branch>  or  checkout -"
        return 1
    fi

    if [ "$1" = "-" ]; then
        doing "switching to previous branch"
        if git checkout - -q 2>/dev/null; then
            done_ "on $(_branch)"
        else
            fail "no previous branch"
        fi
        return $?
    fi

    local b="$1"
    [ "$b" = "$(_branch)" ] && { hint "already on $b"; return 0; }

    if git show-ref --verify --quiet refs/heads/"$b"; then
        doing "switching to $b"
        git checkout "$b" -q 2>/dev/null
        doing "pulling $b"
        if git pull origin "$b" -q 2>/dev/null; then
            done_ "on $b (up to date)"
        else
            fail "switched to $b but pull failed"
        fi
    else
        doing "looking for $b on remote"
        git fetch origin -q 2>/dev/null
        if git show-ref --verify --quiet refs/remotes/origin/"$b"; then
            git checkout -b "$b" origin/"$b" -q 2>/dev/null
            done_ "checked out $b from remote"
        else
            git checkout -b "$b" -q 2>/dev/null
            done_ "created new branch $b"
        fi
    fi
}

# ── stash ────────────────────────────────────
stash() {
    _in_repo || return 1
    if git diff --quiet HEAD 2>/dev/null && git diff --cached --quiet 2>/dev/null; then
        hint "nothing to stash"
        return 0
    fi
    doing "stashing changes"
    if git stash push -q "$@" 2>/dev/null; then
        done_ "stashed"
    else
        fail "stash failed"
    fi
}

# ── pop ──────────────────────────────────────
pop() {
    _in_repo || return 1
    if ! git stash list 2>/dev/null | grep -q .; then
        hint "no stashes to pop"
        return 0
    fi
    doing "popping last stash"
    if git stash pop -q 2>/dev/null; then
        done_ "restored"
    else
        fail "pop failed — possible conflicts"
    fi
}

# ── undocommit ───────────────────────────────
undocommit() {
    _in_repo || return 1
    local count
    count=$(git rev-list --count HEAD 2>/dev/null)
    [ -z "$count" ] || [ "$count" -eq 0 ] && { fail "no commits to undo"; return 1; }

    local msg
    msg=$(git log -1 --format='%s' 2>/dev/null)
    doing "undoing: $msg"
    git reset --soft HEAD~1 -q 2>/dev/null
    done_ "undone — changes are staged"
}

# ── log ──────────────────────────────────────
log() {
    _in_repo || return 1
    local n="${1:-15}"
    if ! [[ "$n" =~ ^[0-9]+$ ]]; then
        hint "usage: log [number]"
        return 1
    fi
    local total
    total=$(git rev-list --count HEAD 2>/dev/null)
    [ -z "$total" ] || [ "$total" -eq 0 ] && { hint "no commits yet"; return 0; }
    git --no-pager log --oneline --graph --decorate -n "$n"
}

# ── pick ─────────────────────────────────────
pick() {
    _in_repo || return 1
    if [ -z "$1" ]; then
        hint "usage: pick <commit-hash>"
        return 1
    fi
    if ! git cat-file -t "$1" >/dev/null 2>&1; then
        fail "commit $1 not found"
        return 1
    fi
    local msg
    msg=$(git log -1 --format='%s' "$1" 2>/dev/null)
    doing "picking: $msg"
    if git cherry-pick "$1" 2>/dev/null; then
        done_ "picked"
    else
        fail "conflicts — fix then run: git cherry-pick --continue"
    fi
}

# ── delloc ───────────────────────────────────
delloc() {
    _in_repo || return 1
    if [ -z "$1" ]; then
        hint "usage: delloc <branch>"
        return 1
    fi

    local b="$1"
    local cur=$(_branch)

    [ "$b" = "$cur" ] && { fail "can't delete $b — you're on it"; return 1; }

    if ! git show-ref --verify --quiet refs/heads/"$b"; then
        fail "$b doesn't exist locally"
        return 1
    fi

    local merged
    merged=$(git branch --merged "$cur" 2>/dev/null | grep -w "$b")
    if [ -z "$merged" ]; then
        echo -ne "${RED}${BOLD}  $b has unmerged commits. delete? (y/n): ${RESET}"
        read -r c
        [ "$c" != "y" ] && { hint "cancelled"; return 0; }
    fi

    doing "deleting $b"
    git branch -D "$b" -q 2>/dev/null
    done_ "deleted $b"
}

# ── deploy (merge into development) ──────────
deploy() {
    _in_repo || return 1
    local b=$(_branch)
    echo -ne "${YELLOW}  running merge script to ${CYAN}${BOLD}development${RESET}${YELLOW}? (y/n): ${RESET}"
    read -r c
    [ "$c" != "y" ] && { hint "cancelled"; return 0; }
    if [ $# -eq 0 ]; then
        "$TERN_ROOT/git-practices/scripts/merge_into.sh" development
    else
        "$TERN_ROOT/git-practices/scripts/merge_into.sh" "$@"
    fi
}

# ── reset (reset + merge into development) ───
reset() {
    _in_repo || return 1
    local b=$(_branch)
    echo -ne "${YELLOW}  running reset script to ${CYAN}${BOLD}development${RESET}${YELLOW} + merging ${CYAN}${BOLD}$b${RESET}${YELLOW}? (y/n): ${RESET}"
    read -r c
    [ "$c" != "y" ] && { hint "cancelled"; return 0; }
    "$TERN_ROOT/git-practices/scripts/reset_branch.sh" development --merge-into
}

# ── misc ─────────────────────────────────────
cl() { clear; }

# ── repo shortcuts ───────────────────────────
TERN_ROOT="$HOME/OneDrive/Desktop/tern"

_goto() {
    local dir="$TERN_ROOT/$1"
    [ ! -d "$dir" ] && { fail "repo not found: $1"; return 1; }
    cd "$dir" || return 1
    done_ "$1"
}

wht() { _goto "webhook-ternity"; }
tom()     { _goto "tern-of-mind"; }
auth()    { _goto "auth-ternity"; }
ai()      { _goto "ai-interviewer"; }
gp()      { _goto "git-practices"; }

# ── help ─────────────────────────────────────
mycmds() {
    echo ""
    echo -e "${BLUE}${BOLD}  Git${RESET}"
    echo -e "  ${DIM}pull${RESET}                  pull current branch"
    echo -e "  ${DIM}push${RESET}                  push current branch"
    echo -e "  ${DIM}ship [msg]${RESET}            commit staged + push"
    echo -e "  ${DIM}fetch${RESET}                 update refs"
    echo -e "  ${DIM}checkout <branch>${RESET}     switch branch"
    echo -e "  ${DIM}checkout -${RESET}            previous branch"
    echo -e "  ${DIM}undocommit${RESET}            undo last commit"
    echo -e "  ${DIM}delloc <branch>${RESET}       delete local branch"
    echo -e "  ${DIM}log [n]${RESET}               last n commits"
    echo -e "  ${DIM}pick <hash>${RESET}           cherry-pick"
    echo -e "  ${DIM}stash${RESET}                 stash changes"
    echo -e "  ${DIM}pop${RESET}                   pop last stash"
    echo ""
    echo -e "${BLUE}${BOLD}  Merge${RESET}"
    echo -e "  ${DIM}deploy${RESET}                merge into development"
    echo -e "  ${DIM}deploy --continue${RESET}     continue after conflicts"
    echo -e "  ${DIM}deploy --abort${RESET}        abort merge"
    echo -e "  ${DIM}reset${RESET}                 reset development + merge"
    echo ""
    echo -e "${BLUE}${BOLD}  Misc${RESET}"
    echo -e "  ${DIM}cl${RESET}                    clear screen"
    echo ""
    echo -e "${BLUE}${BOLD}  Repos${RESET}"
    echo -e "  ${DIM}wht${RESET}  ${DIM}tom${RESET}  ${DIM}auth${RESET}  ${DIM}ai${RESET}  ${DIM}gp${RESET}"
    echo ""
}

done_ "mycmds loaded — type ${BLUE}${BOLD}mycmds${RESET}${GREEN}${BOLD} for help"
