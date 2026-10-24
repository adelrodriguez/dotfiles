# Raise the open-files soft limit on macOS. The default of 256 is too low for
# many parallel agents, dev servers and file watchers, which fail with EMFILE.
if test (uname) = Darwin
    set -l current (ulimit -n)
    if test "$current" != unlimited; and test "$current" -lt 65536
        ulimit -n 65536 2>/dev/null
    end
end
