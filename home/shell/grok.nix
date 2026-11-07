{ config, lib, pkgs, ... }:
{
  # Grok rewrites its completion during updates. APM and secrets stay runtime-owned.
  home.activation.grokCompletion = lib.hm.dag.entryAfter [ "writeBoundary" "linkGeneration" ] ''
    run ${pkgs.python3}/bin/python3 ${../mutable.py} completion \
      ${lib.escapeShellArg config.home.homeDirectory} ${./fish/completions/grok.fish}
  '';
}
