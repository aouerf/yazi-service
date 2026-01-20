# yazi-service

An implementation of the [File Manager DBus interface](https://www.freedesktop.org/wiki/Specifications/file-manager-interface) for [Yazi](https://yazi-rs.github.io).

This allows the web browser downloads' "show in folder" functionality to work properly with Yazi on Linux.

## Implementations

- [ ] org.freedesktop.FileManager1
  - [x] ShowFolders
  - [x] ShowItems
  - [ ] ShowItemProperties

## Setup

The following programs will be called at runtime and should be installed on your system:

- [yazi](https://github.com/sxyazi/yazi)
- [xdg-terminal-exec](https://github.com/Vladimir-csp/xdg-terminal-exec) (to launch a terminal emulator)

### Firefox

Under [Advanced Preferences](about:config), `widget.use-xdg-desktop-portal.open-uri` must be set to either `2` (auto, default) or `0` (never).
Setting it to `1` (always) will use `org.freedesktop.portal.OpenURI` instead of `org.freedesktop.FileManager1`.

## Building

### Nix

`nix build github:aouerf/yazi-service`

### Manually

Install the following dependencies:

- [zig](https://ziglang.org)
- [libsystemd](https://www.freedesktop.org/software/systemd/man/latest/libsystemd.html)

Then run:

```sh
git clone https://github.com/aouerf/yazi-service
cd yazi-service
zig build --release=safe
```

The binary and service files can be found under the `zig-out` directory.

## Installing

### Nix

The package is available as `packages.${system}.default`;

You can also add the package to your nixpkgs instance through an overlay. For example, on a NixOS system using flakes:

```nix
# flake.nix
{
    inputs.yazi-service.url = "github:aouerf/yazi-service";
    outputs = inputs: {
      nixosConfigurations.${hostname} = inputs.nixpkgs.lib.nixosSystem {
        modules = [{
          nixpkgs.overlays = [(_: prev: {
            yazi-service = inputs.yazi-service.packages.${prev.stdenv.hostPlatform.system}.default;
          })];
        }]
      };
    };
}
```

Then the package can be installed like normal:

```nix
{ pkgs, ... }:
{
  # NixOS
  environment.systemPackages = [ pkgs.yazi-service ];

  # Home Manager
  home.packages = [ pkgs.yazi-service ];
}
```
