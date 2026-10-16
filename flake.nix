# DO-NOT-EDIT. This file was auto-generated using github:denful/flake-file.
# Use `nix run .#write-flake` to regenerate it.
{
  outputs =
    inputs:
    inputs.flake-parts.lib.mkFlake { inherit inputs; } (
      (inputs.import-tree.filterNot (inputs.nixpkgs.lib.hasSuffix "npins/default.nix")) ./nix
    );

  inputs = {
    flake-file.url = "github:vic/flake-file";
    flake-parts = {
      url = "github:hercules-ci/flake-parts";
      inputs.nixpkgs-lib.follows = "nixpkgs";
    };
    flat-flake = {
      url = "github:linyinfeng/flat-flake";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    git-hooks-nix = {
      url = "github:cachix/git-hooks.nix";
      inputs = {
        flake-compat.follows = "";
        nixpkgs.follows = "nixpkgs";
      };
    };
    import-tree.url = "github:denful/import-tree";
    make-shell = {
      url = "github:nicknovitski/make-shell";
      inputs.flake-compat.follows = "";
    };
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    pedantix = {
      url = "github:Swarsel/pedantix";
      inputs = {
        flake-parts.follows = "flake-parts";
        git-hooks-nix.follows = "git-hooks-nix";
        nixpkgs.follows = "nixpkgs";
        treefmt-nix.follows = "treefmt-nix";
      };
    };
    treefmt-nix = {
      url = "github:numtide/treefmt-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };
}
