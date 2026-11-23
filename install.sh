#!/bin/sh
# Installs vim-abaqusmsg for Vim on Linux/macOS.
#   sh install.sh            install
#   sh install.sh --uninstall
#
# Vim reads ~/.vimrc or ~/.vim/vimrc and uses ~/.vim. Newer Vim versions also
# support $XDG_CONFIG_HOME/vim (default ~/.config/vim), but only when neither
# ~/.vimrc nor ~/.vim/vimrc exists and $XDG_CONFIG_HOME/vim/vimrc does.
set -e
src=$(cd "$(dirname "$0")" && pwd)
xdgdir="${XDG_CONFIG_HOME:-$HOME/.config}/vim"
pkg="pack/abaqus/start/vim-abaqusmsg"

if [ ! -f "$HOME/.vimrc" ] && [ ! -f "$HOME/.vim/vimrc" ] && [ -f "$xdgdir/vimrc" ]; then
  vimdir="$xdgdir"
else
  vimdir="$HOME/.vim"
fi
dest="$vimdir/$pkg"

if [ "$1" = "--uninstall" ]; then
  for d in "$HOME/.vim/$pkg" "$xdgdir/$pkg"; do
    [ -d "$d" ] && rm -rf "$d" && echo "Removed $d"
  done
  exit 0
fi

rm -rf "$dest"
mkdir -p "$dest"
cp -R "$src/autoload" "$src/doc" "$src/ftdetect" "$src/ftplugin" "$src/syntax" "$dest/"
echo "Installed to $dest"

if command -v vim >/dev/null 2>&1; then
  vim -u NONE -i NONE -es -c "helptags $dest/doc" -c 'qa!' || true
  echo "Help tags generated (:help abaqusmsg)."
fi

for rc in "$HOME/.vimrc" "$HOME/.vim/vimrc" "$xdgdir/vimrc"; do
  if [ -f "$rc" ] && grep -n '\*\.msg' "$rc" >/dev/null; then
    echo "WARNING: $rc has lines for *.msg files that may override the plugin:"
    grep -n '\*\.msg' "$rc" | sed 's/^/    line /'
  fi
done
echo "Done. Make sure your vimrc has 'filetype plugin on' and 'syntax on'."
