# Shared across every machine. Sourced from zshrc.Linux and zshrc.Darwin.
# Managed by dotfiles/install.sh — keep machine-specific things out of here.

# hx-make / hx-harpoon live here
export PATH="$HOME/.local/bin:$PATH"

# The Helix fork built from source (see install.sh --helix)
HELIX_FORK="${HELIX_FORK:-$HOME/repos/me/helix-plugin}"
if [ -x "$HELIX_FORK/target/opt/hx" ]; then
  alias hxp="HELIX_RUNTIME=$HELIX_FORK/runtime $HELIX_FORK/target/opt/hx"
fi
