#!/usr/bin/env bash

pr_create() {
  local title="" host_key="" host_val="" branch
  local -a gh_opts
  local -A hosts=(
    [hulu]="github.prod.hulu.com"
    [twdc]="github.twdcgrid.net"
    [disney]="github.twdcgrid.net"
    [bamgrid]="github.bamtech.co"
  )

  branch="$(git branch --show-current 2>/dev/null || echo "unknown")"

  while (( $# > 0 )); do
    case "$1" in
      --title=*) title="${1#--title=}"; shift ;;
      --title)   title="$2"; shift 2 ;;
      --host=*)  host_key="${1#--host=}"; shift ;;
      --host)    host_key="$2"; shift 2 ;;
      -h|--help)
        printf '\033[34m\033[1mUsage:\033[0m pr_create [options] [title]\n'
        echo "  Creates a GitHub PR with smart title handling and host management"
        echo
        printf '\033[34m\033[1mOptions:\033[0m\n'
        echo "  --title=TITLE   Specify PR title (branch name will be prepended if not present)"
        echo "  --host=HOST     Set GitHub host. Special values:"
        for key in "${!hosts[@]}"; do
          echo "                  - $key → ${hosts[$key]}"
        done
        echo "  -h, --help      Show this help message"
        echo
        echo "Any additional GitHub CLI options are passed through to 'gh pr create'."
        return 0
        ;;
      *)
        if [[ "$1" == --* ]]; then
          gh_opts+=("$1")
          shift
        else
          title="$*"
          break
        fi
        ;;
    esac
  done

  if [[ -n "$host_key" ]]; then
    host_val="${hosts[$host_key]:-$host_key}"
  fi

  if [[ -z "$title" ]]; then
    title="$branch: Updates"
  elif [[ "$title" != *"$branch"* && "$branch" != "unknown" ]]; then
    title="$branch: $title"
  fi

  local -a cmd=(gh pr create --assignee=@me -w --title="$title")
  (( ${#gh_opts[@]} )) && cmd+=("${gh_opts[@]}")

  if [[ -n "$host_val" ]]; then
    GH_HOST="$host_val" "${cmd[@]}"
  else
    "${cmd[@]}"
  fi

  if [[ $? -eq 0 ]]; then
    printf '\033[32m✓ Pull request created:\033[0m \033[1m%s\033[0m\n' "$title"
    [[ -n "$host_val" ]] && printf '  Using host: \033[36m%s\033[0m\n' "$host_val"
  else
    printf '\033[31m✗ Failed to create pull request\033[0m\n'
    return 1
  fi
}

_pr_create_completions() {
  local cur prev
  cur="${COMP_WORDS[COMP_CWORD]}"
  prev="${COMP_WORDS[COMP_CWORD-1]}"

  case "$prev" in
    --host)
      COMPREPLY=($(compgen -W "hulu twdc disney bamgrid" -- "$cur"))
      return
      ;;
    --title)
      return
      ;;
  esac

  case "$cur" in
    --host=*)
      local prefix="--host="
      local word="${cur#"$prefix"}"
      COMPREPLY=($(compgen -W "hulu twdc disney bamgrid" -- "$word"))
      COMPREPLY=("${COMPREPLY[@]/#/$prefix}")
      return
      ;;
    --title=*)
      return
      ;;
    -*)
      COMPREPLY=($(compgen -W "--title= --host= --help" -- "$cur"))
      return
      ;;
  esac
}

complete -F _pr_create_completions pr_create
