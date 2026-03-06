function c
  open -a "Cursor" $argv
end

if status is-interactive
  abbr -a pn pnpm
  abbr -a l "ls -l"
  abbr -a la "ls -a"
  abbr -a ll "ls -la"
  abbr -a ls "ls -G"
  abbr -a z zed
  abbr -a zshrc "c ~/.zshrc"
end
