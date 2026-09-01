{
  inputs = {
    nixpkgs = {
      url = "github:nixos/nixpkgs/nixos-unstable";
    };
    flake-utils = {
      url = "github:numtide/flake-utils";
    };
  };
  outputs =
    { nixpkgs, flake-utils, ... }:
    flake-utils.lib.eachDefaultSystem (
      system:
      let
        pkgs = import nixpkgs { inherit system; };
        packages = with pkgs; [
          stylua
          selene
          just
          neovim
          lua-language-server
          lua51Packages.nlua
          lua51Packages.busted
        ];
      in
      {
        devShells.default = pkgs.mkShell {
          name = "smart-splits.nvim";
          inherit packages;
        };
        devShells.ci = pkgs.mkShell {
          name = "ci";
          inherit packages;
        };
      }
    );
}
