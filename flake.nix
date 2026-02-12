{
  description = "yazi-service";

  inputs = {
    nixpkgs.url = "nixpkgs/nixpkgs-unstable";
    flake-parts.url = "github:hercules-ci/flake-parts";
    treefmt-nix = {
      url = "github:numtide/treefmt-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    inputs:
    inputs.flake-parts.lib.mkFlake { inherit inputs; } {
      imports = [
        inputs.treefmt-nix.flakeModule
      ];
      systems = [
        "aarch64-linux"
        "x86_64-linux"
      ];
      perSystem =
        { pkgs, ... }:
        {
          packages.default = pkgs.stdenv.mkDerivation {
            pname = "yazi-service";
            version = "0.1.0";

            src = ./.;

            strictDeps = true;
            nativeBuildInputs = with pkgs; [
              zig
              pkg-config
            ];
            buildInputs = with pkgs; [
              systemdLibs
            ];

            meta = with pkgs.lib; {
              description = "An implementation of the File Manager DBus interface for Yazi";
              homepage = "https://github.com/aouerf/yazi-service";
              license = licenses.mit;
              platforms = platforms.linux;
              mainProgram = "yazi-service";
            };
          };

          devShells.default = pkgs.mkShell {
            strictDeps = true;
            packages = with pkgs; [
              clang-tools
              nixd
              pkg-config
              zig
              zls
            ];
            buildInputs = with pkgs; [
              systemdLibs
            ];
          };

          treefmt.programs = {
            clang-tidy.enable = true;
            mdformat.enable = true;
            nixfmt.enable = true;
            zig.enable = true;
          };
        };
    };
}
