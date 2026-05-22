#!/usr/bin/env bash
# Dependencies: git-lfs, gh, uv (all provisioned by install.sh before this runs)

PERSONA_RL_DIR="${PERSONA_RL_DIR:-$HOME/dev/persona_rl}"

echo "==> persona_rl"

if [ ! -d "$PERSONA_RL_DIR" ]; then
  gh repo clone persona-ai-inc/persona_rl "$PERSONA_RL_DIR"
else
  git -C "$PERSONA_RL_DIR" pull --ff-only
fi

(cd "$PERSONA_RL_DIR" && uvx gitman update persona)
