{
  description = "Ghost — Modular Quickshell/QML desktop shell for Hyprland";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = nixpkgs.legacyPackages.${system};

        # ── Runtime dependencies (required at launch) ──────────────────────
        runtimeDeps = with pkgs; [
          # Core shell runtime
          quickshell
          hyprland
          qt6.full
          qt6ct

          # Audio
          pipewire
          pipewire-pulse
          wireplumber
          playerctl
          mpv-mpris
          mpd-mpris

          # Network / Bluetooth
          networkmanager
          bluez
          bluez-utils

          # Display / input utilities
          wl-clipboard
          slurp
          xdg-user-dirs
          xdg-desktop-portal-hyprland

          # System info
          libnotify
          polkit
          lm_sensors

          # Media & visualiser
          cava
          python3

          # Screen recording
          wf-recorder

          # Wallpaper & theming
          imagemagick
          awww
          matugen

          # Clipboard integration
          wtype
          cliphist

          # Hyprland ecosystem
          hyprsunset
          hyprlock
          hypridle
        ];

        # ── Development extras (not needed at runtime) ─────────────────────
        devDeps = with pkgs; [
          git
          bash
          shellcheck
          python3Packages.python-lsp-server
        ];

        # ── Fonts ──────────────────────────────────────────────────────────
        fonts = with pkgs; [
          (nerdfonts.override { fonts = [ "JetBrainsMono" ]; })
        ];

        # ── The Ghost package ────────────────────────────────────────
        ghost = pkgs.stdenv.mkDerivation {
          pname   = "ghost";
          version = "0.1.0";

          src = ./.;

          nativeBuildInputs = [ pkgs.makeWrapper ];
          buildInputs = runtimeDeps ++ fonts;

          installPhase = ''
            runHook preInstall

            mkdir -p $out/share/ghost
            cp -r . $out/share/ghost/

            mkdir -p $out/bin
            makeWrapper ${pkgs.quickshell}/bin/quickshell $out/bin/ghost \
              --add-flags "-c $out/share/ghost" \
              --set  QT_QPA_PLATFORMTHEME qt6ct \
              --prefix PATH : ${pkgs.lib.makeBinPath runtimeDeps}

            runHook postInstall
          '';

          meta = with pkgs.lib; {
            description  = "A modular Quickshell/QML desktop shell for Hyprland";
            homepage     = "https://github.com/bjschnell/GhostInTheQuickshell";
            license      = licenses.mit;
            platforms    = platforms.linux;
            mainProgram  = "ghost";
          };
        };

      in
      {
        # ── Packages ───────────────────────────────────────────────────────
        packages = {
          default     = ghost;
          ghost = ghost;
        };

        # ── Dev shell (nix develop) ────────────────────────────────────────
        devShells.default = pkgs.mkShell {
          name = "ghost-dev";

          buildInputs = runtimeDeps ++ devDeps ++ fonts;

          shellHook = ''
            export QT_QPA_PLATFORMTHEME=qt6ct
            export GHOST_ROOT="$(pwd)"

            echo ""
            echo "  Ghost dev environment"
            echo "  Run:  quickshell -c \$GHOST_ROOT"
            echo "  Lint: shellcheck install.sh dots-extra/install-arch.sh"
            echo ""
          '';
        };

        # ── NixOS module ───────────────────────────────────────────────────
        nixosModules.default = { config, lib, pkgs, ... }:
          let cfg = config.programs.ghost;
          in {
            options.programs.ghost = {
              enable = lib.mkEnableOption "Ghost desktop shell";

              autostart = lib.mkOption {
                type    = lib.types.bool;
                default = true;
                description = "Add ghost to Hyprland exec-once.";
              };
            };

            config = lib.mkIf cfg.enable {
              environment.systemPackages = [ ghost ];

              wayland.windowManager.hyprland.settings = lib.mkIf cfg.autostart {
                exec-once = [
                  "ghost"
                  "hypridle"
                  "awww-daemon"
                  "systemctl --user start hyprpolkitagent"
                  "wl-paste --type text  --watch cliphist store"
                  "wl-paste --type image --watch cliphist store"
                ];
              };
            };
          };

        # ── Checks (run by `nix flake check`) ─────────────────────────────
        checks = {
          build = ghost;
        };
      }
    );
}
