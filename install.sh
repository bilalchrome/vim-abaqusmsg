#!/bin/sh
# Installs vim-abaqusmsg for Vim (and Neovim, if present) on Linux/macOS.
#   sh install.sh            install
#   sh install.sh --uninstall
set -e
src=$(cd "$(dirname "$0")" && pwd)
targets="$HOME/.vim/pack/abaqus/start/vim-abaqusmsg"
if command -v nvim >/dev/null 2>&1; then
  targets="$targets ${XDG_DATA_HOME:-$HOME/.local/share}/nvim/site/pack/abaqus/start/vim-abaqusmsg"
fi

for dest in $targets; do
  if [ "$1" = "--uninstall" ]; then
    rm -rf "$dest" && echo "Removed $dest"
    continue
  fi
  rm -rf "$dest"
  mkdir -p "$dest"
  cp -R "$src/autoload" "$src/doc" "$src/ftdetect" "$src/ftplugin" "$src/syntax" "$dest/"
  echo "Installed to $dest"
done
[ "$1" = "--uninstall" ] && exit 0

if command -v vim >/dev/null 2>&1; then
  vim -u NONE -i NONE -es -c "helptags $HOME/.vim/pack/abaqus/start/vim-abaqusmsg/doc" -c 'qa!' || true
  echo "Help tags generated (:help abaqusmsg)."
fi

for rc in "$HOME/.vimrc" "$HOME/.vim/vimrc"; do
  if [ -f "$rc" ] && grep -n '\*\.msg' "$rc" >/dev/null; then
    echo "WARNING: $rc has lines for *.msg files that may override the plugin:"
    grep -n '\*\.msg' "$rc" | sed 's/^/    line /'
  fi
done
echo "Done. Make sure your vimrc has 'filetype plugin on' and 'syntax on'."
