# Copyright © 2022, 2023  Hraban Luyat
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU Affero General Public License as published
# by the Free Software Foundation, version 3 of the License.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU Affero General Public License for more details.
#
# You should have received a copy of the GNU Affero General Public License
# along with this program.  If not, see <https://www.gnu.org/licenses/>.

{
  description = "The extensible, customizable GNU text editor";
  inputs = {
    flake-utils.url = "github:numtide/flake-utils";
    emacs = {
      url = "git://git.sv.gnu.org/emacs.git";
      flake = false;
    };
    community-overlay = {
      url = "github:nix-community/emacs-overlay";
      inputs = {
        nixpkgs.follows = "nixpkgs";
        flake-utils.follows = "flake-utils";
      };
    };
  };
  outputs = {
    self, nixpkgs, flake-utils, emacs, community-overlay
  }:
    with flake-utils.lib;
    let
      macs = [
        system.aarch64-darwin # Didn’t actually test on this arch
        system.x86_64-darwin
      ];
      isMac = system: builtins.elem system macs;
    in
      eachDefaultSystem (system:
        let
          # nixpkgs has an extensively tested derivation for emacs, with one minor
          # problem: the version isn’t overridable, and a patch is applied to the
          # src depending on the version, meaning if you override the src the
          # wrong patch will be applied. To fix that, we have to patch nixpkgs
          # itself, re-import that, and finally override the version (and the src
          # attr).
          orig-pkgs = nixpkgs.legacyPackages.${system};
          # I /think/ there is a better way?
          ov-pkgs = import nixpkgs {
            inherit system;
            overlays = [ community-overlay.overlay ];
          };
          patched-nixpkgs-src = orig-pkgs.applyPatches {
            name = "nixpkgs-emacs-overridable-version";
            src = nixpkgs;
            patches = [ ./nixpkgs-emacs-overridable-version.patch ];
          };
          patched-pkgs = import patched-nixpkgs-src { inherit system; };
          all = {
            # The version is passed to the function that constructs this
            # derivation, and it is /that/ version which is used to determine
            # which patches to apply. You can override the version through
            # overrideAttrs, yes, but it will only change the version property of
            # the derivation. That won’t influence the choice of patches, which
            # will cause a patch fail (see the emacs derivation in nixpkgs).
            packages = rec {
              from-nixpkgs = (patched-pkgs.emacs.override ({
                version = "30.0-git";
              })).overrideAttrs (_: {
                src = emacs;
              });
              default = from-nixpkgs;
            };
            apps = rec {
              from-nixpkgs = mkApp { drv = self.packages.${system}.from-nixpkgs; };
              default = from-nixpkgs;
            };
          };
          darwin = orig-pkgs.lib.attrsets.optionalAttrs (isMac system) {
            packages = rec {
              # On mac, those don’t work well. Also offer build from source.
              from-src = import ./from-src-mac.nix {
                src = emacs;
                pkgs = orig-pkgs;
              };
              # And the Nix wiki suggests this approach at
              # "https://nixos.wiki/wiki/Emacs". Obviously fragile.
              mac-port = let
                rev = "6d4b8346773907e42efacbcf5aac0b27b79cc3b9";
                base = "https://raw.githubusercontent.com/d12frosted/homebrew-emacs-plus/${rev}";
              in
                ov-pkgs.emacsPgtk.overrideAttrs (old: {
                  patches =
                    (old.patches or [])
                    ++ [
                      # Fix OS window role (needed for window managers like yabai)
                      (ov-pkgs.fetchpatch {
                        url = "${base}/patches/emacs-28/fix-window-role.patch";
                        sha256 = "sha256-+z/KfsBm1lvZTZNiMbxzXQGRTjkCFO4QPlEK35upjsE=";
                      })
                      # Use poll instead of select to get file descriptors
                      (ov-pkgs.fetchpatch {
                        url = "${base}/patches/emacs-29/poll.patch";
                        sha256 = "sha256-jN9MlD8/ZrnLuP2/HUXXEVVd6A+aRZNYFdZF8ReJGfY=";
                      })
                      # Enable rounded window with no decoration
                      (ov-pkgs.fetchpatch {
                        url = "${base}/patches/emacs-29/round-undecorated-frame.patch";
                        sha256 = "sha256-qPenMhtRGtL9a0BvGnPF4G1+2AJ1Qylgn/lUM8J2CVI=";
                      })
                      # Make Emacs aware of OS-level light/dark mode
                      (ov-pkgs.fetchpatch {
                        url = "${base}/patches/emacs-28/system-appearance.patch";
                        sha256 = "sha256-oM6fXdXCWVcBnNrzXmF0ZMdp8j0pzkLE66WteeCutv8=";
                      })
                    ];
              });
              default = from-src;
            };
            apps = rec {
              from-src = mkApp { drv = self.packages.${system}.from-src; };
              default = from-src;
            };
          };
        in {
          packages = all.packages // (darwin.packages or {});
          apps = all.apps // (darwin.apps or {});
        });
}
