{
  description = "Demo lispPackagesLite app using flakes";
  inputs = {
    flake-utils.url = "github:numtide/flake-utils";
    gitignore = {
      inputs.nixpkgs.follows = "nixpkgs";
      url = "github:hercules-ci/gitignore.nix";
    };
    emacs = {
      url = "git://git.sv.gnu.org/emacs.git";
      flake = false;
    };
  };
  outputs = {
    self, nixpkgs, gitignore, flake-utils, emacs
  }:
    with flake-utils.lib;
    eachSystem [
      system.aarch64-darwin # Didn’t actually test this
      system.x86_64-darwin
    ] (system:
      let
        pkgs = import nixpkgs { inherit system; };
        cleanSource = src: gitignore.lib.gitignoreSource (pkgs.lib.cleanSource src);
      in
        {
          packages.default = pkgs.stdenv.mkDerivation rec {
            pname = "emacs";
            version = "git";
            src = emacs;
            # I build this for myself so I don’t care about old systems. Just
            # set it to latest. This helps with appkit headers or something?
            # https://opensource.apple.com/source/CarbonHeaders/CarbonHeaders-18.1/AvailabilityMacros.h.auto.html
            CFLAGS = "-O3 -march=native -DMAC_OS_X_VERSION_MIN_REQUIRED=1260";
            configureFlags = [
              "--enable-link-time-optimization"
              "--with-imagemagick"
              "--with-json"
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
            # On Emacs, make install is a necessary build step which includes
            # some runtime .el files in the final build. --prefix has no
            # effect, so we must manually copy the files. Additionally we must
            # ensure the compiled elisp files are newer than their source
            # counterparts, or load-prefer-newer will cause an infinite
            # recursion. See "https://github.com/bbatsov/prelude/issues/1134".
            installPhase = ''
              make install
              find nextstep/Emacs.app -name '*.elc' -exec touch {} +
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
            ] ++ (with pkgs.darwin.apple_sdk.frameworks; [
              # This is the list in the official emacs derivation in nixpkgs
              # AppKit Carbon Cocoa IOKit OSAKit Quartz QuartzCore WebKit
              # ImageCaptureCore GSS ImageIO # may be optional
              Cocoa
            ]);
            passthru.exePath = "/Emacs.app/Contents/MacOS/Emacs";
          };
          apps.default = mkApp {
            drv = self.packages.${system}.default;
          };
        });
  }
