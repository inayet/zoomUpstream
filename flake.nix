{
  description = "Zoom Upstream repackaged as a Nix flake with cross-system support";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-parts.url = "github:hercules-ci/flake-parts";
  };

  outputs =
    inputs@{
      self,
      nixpkgs,
      flake-parts,
      ...
    }:
    flake-parts.lib.mkFlake { inherit inputs; } {
      systems = [
        "x86_64-linux"
        "aarch64-linux"
      ];

      perSystem =
        { pkgs, system, ... }:
        {
          packages.zoomUpstream =
            if pkgs.stdenv.isLinux then pkgs.callPackage ./pkgs/zoomUpstream { inherit pkgs; } else null;

          apps.zoomUpstream =
            if pkgs.stdenv.isLinux then
              {
                type = "app";
                program = "${self.packages.${system}.zoomUpstream}/bin/zoom";
              }
            else
              null;

          # Defaults for convenience
          packages.default = self.packages.${system}.zoomUpstream;
          apps.default = self.apps.${system}.zoomUpstream;
        };
    };
}
