{
  description = "Saltic development and release environment";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.11";

  outputs = { nixpkgs, ... }:
    let
      systems = [ "x86_64-linux" ];
      forAllSystems = nixpkgs.lib.genAttrs systems;
    in {
      devShells = forAllSystems (system:
        let
          pkgs = import nixpkgs { inherit system; };
        in {
          default = pkgs.mkShell {
            hardeningDisable = [ "all" ];
            packages = with pkgs; [
              bash
              coreutils
              diffutils
              gawk
              git
              gnugrep
              gnused
              gnutar
              gzip
              just
              qemu
              pkgsCross.riscv32-embedded.buildPackages.gcc
            ];
          };
        });
    };
}
