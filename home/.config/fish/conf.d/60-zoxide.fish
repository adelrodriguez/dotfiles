if type -q zoxide
    zoxide init fish --cmd cd | source
    complete --command cd --no-files --arguments '(__zoxide_z_complete)'
end
