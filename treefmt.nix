{ pkgs, ... }:
{
  projectRootFile = "flake.nix";
  programs = {
    actionlint.enable = true;
    just.enable = true;
    nixfmt.enable = true;
    statix.enable = true;
    stylua.enable = true;
    yamlfmt.enable = true;
  };
  settings.formatter = {
    prettier = {
      command = "${pkgs.prettier}/bin/prettier";
      options = [ "--write" ];
      includes = [
        "*.json"
        "*.jsonc"
      ];
    };
    tombi = {
      command = "${pkgs.tombi}/bin/tombi";
      options = [
        "format"
        "--offline"
      ];
      includes = [ "*.toml" ];
    };
  };
}
