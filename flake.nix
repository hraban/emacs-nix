# Copyright © 2022  Hraban Luyat
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
  };
  outputs = {
    self, nixpkgs, flake-utils, emacs
  }:
    with flake-utils.lib;
    eachDefaultSystem (system:
      let
        # nixpkgs has an extensively tested derivation for emacs, with one minor
        # problem: the version isn’t overridable, and a patch is applied to the
        # src depending on the version, meaning if you override the src the
        # wrong patch will be applied. To fix that, we have to patch nixpkgs
        # itself, re-import that, and finally override the version (and the src
        # attr).
        origPkgs = import nixpkgs { inherit system; };
        pnixpkgs = origPkgs.applyPatches {
          name = "nixpkgs-emacs-overridable-version";
          src = nixpkgs;
          patches = [ ./nixpkgs-emacs-overridable-version.patch ];
        };
        pkgs = import pnixpkgs { inherit system; };
      in
        {
          # The version is passed to the function that constructs this
          # derivation, and it is /that/ version which is used to determine
          # which patches to apply. You can override the version through
          # overrideAttrs, yes, but it will only change the version property of
          # the derivation. That won’t influence the choice of patches, which
          # will cause a patch fail (see the emacs derivation in nixpkgs).
          packages.default = (pkgs.emacs.override ({
            version = "30.0-git";
          })).overrideAttrs (_: {
            src = emacs;
          });
          apps.default = mkApp {
            drv = self.packages.${system}.default;
          };
        });
  }
