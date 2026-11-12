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
        let
          zig = pkgs.zig_0_17;
        in
        {
          packages.default = pkgs.stdenv.mkDerivation (finalAttrs: {
            pname = "yazi-service";
            version = "0.1.0";

            src = ./.;

            strictDeps = true;
            nativeBuildInputs = [
              pkgs.pkg-config
              zig
            ];
            buildInputs = [
              pkgs.systemdLibs
            ];

            zigDeps = zig.fetchDeps {
              inherit (finalAttrs) pname version src;
              hash = "sha256-aiE65pHswSG8K5MYtoNiSv0vwWB3A+q7tt2giqurCCg=";
            };

            postConfigure = ''
              ln -s ${finalAttrs.zigDeps} $ZIG_GLOBAL_CACHE_DIR/p
            '';

            meta = with pkgs.lib; {
              description = "An implementation of the File Manager DBus interface for Yazi";
              homepage = "https://github.com/aouerf/yazi-service";
              license = licenses.mit;
              platforms = platforms.linux;
              mainProgram = "yazi-service";
            };
          });

          devShells.default = pkgs.mkShell {
            strictDeps = true;
            packages = [
              pkgs.clang-tools
              pkgs.nixd
              pkgs.pkg-config
              pkgs.zls
              zig
            ];
            buildInputs = with pkgs; [
              systemdLibs
            ];
          };

          treefmt.programs = {
            clang-tidy.enable = true;
            mdformat.enable = true;
            nixfmt.enable = true;
            zig = {
              enable = true;
              package = zig;
            };
          };
        };
    };
}
