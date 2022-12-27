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
    eachSystem [
      system.aarch64-darwin # Didn’t actually test this
      system.x86_64-darwin
    ] (system:
      let
        pkgs = import nixpkgs { inherit system; };
      in
        {
          packages.default = pkgs.stdenv.mkDerivation rec {
            pname = "emacs";
            version = "git"; # what is a neat way to handle this automatically?
            src = emacs;
            # I build this for myself so I don’t care about old systems. Just
            # set it to latest. This helps with appkit headers or something?
            # https://opensource.apple.com/source/CarbonHeaders/CarbonHeaders-18.1/AvailabilityMacros.h.auto.html
            CFLAGS = "-O3 -march=native -DMAC_OS_X_VERSION_MIN_REQUIRED=1260";
            configureFlags = [
              "--with-imagemagick"
              "--with-json"
              "--with-png"
              "--with-jpeg"
              "--with-tiff"
              "--with-gif"
              "--with-rsvg"
              "--with-sqlite3"
              "--with-lcms"
              "--with-libsystemd"
              "--with-xml2"
              "--with-tree-sitter"
              "--with-harfbuzz"
              "--with-libotf"
              "--with-libgmp"

              "--enable-link-time-optimization"
              "--with-modules"
              "--without-dbus"
            ];
            # Emacs’ build env supports configuring and building in one
            # step. It’s a better idea because it also automatically calls
            # autogen and/or whatever else you might need from source. Keep it
            # simple.
            dontConfigure=true;
            buildPhase = ''
              make configure="${builtins.toString configureFlags}"
            '';
            # On Mac, make install is a necessary build step which includes some
            # runtime .el files in the final build. --prefix has no effect, so
            # we must manually copy the files. Additionally we must ensure the
            # compiled elisp files are newer than their source counterparts, or
            # load-prefer-newer will cause an infinite recursion. See
            # "https://github.com/bbatsov/prelude/issues/1134".
            installPhase = ''
              make install
              find nextstep/Emacs.app -name '*.el[cn]' -exec touch {} +
              mkdir $out
              mv nextstep/Emacs.app $out/
            '';
            nativeBuildInputs = with pkgs; [
              autoconf
              pkg-config
            ];
            buildInputs = with pkgs; [
              gnutls
              imagemagick
              jansson
              ncurses
              texinfo
              tree-sitter
              # These seem like they’d be necessary, but for some reason the
              # build doesn’t fail on my machine without them. I’ve included
              # them anyway, but what gives? Is it really just a sandboxing
              # issue? Other system libs (e.g. jansson) don’t get picked up
              # during Nix build, so I’m not sure what makes these special. And
              # even after specifying these, the actual ./configure output
              # doesn’t mark them as enabled, even though config.log says they
              # were. Strange...
              harfbuzz
              librsvg
              libxml2
            ] ++ (with pkgs.darwin.apple_sdk.frameworks; [
              # This is the list in the official emacs derivation in nixpkgs
              # AppKit Carbon Cocoa IOKit OSAKit Quartz QuartzCore WebKit
              # ImageCaptureCore GSS ImageIO # may be optional
              # But this seems to be the only one we need?
              Cocoa
            ]);
            meta = {
              # :D
              inherit (pkgs.emacs.meta)
                homepage
                license
                description
                unfree
                longDescription;
            };
            passthru.exePath = "/Emacs.app/Contents/MacOS/Emacs";
          };
          apps.default = mkApp {
            drv = self.packages.${system}.default;
          };
        });
  }
