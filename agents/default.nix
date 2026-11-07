{ ... }:
{
  home.file = {
    ".config/agents/env.tpl".source = ./env.tpl;
    "Makefile".source = ./Makefile;
  };
}
