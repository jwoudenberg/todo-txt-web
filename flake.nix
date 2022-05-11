{
  description = "todo-txt-web";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  inputs.flake-utils.url = "github:numtide/flake-utils";

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = nixpkgs.legacyPackages.${system};
        app = pkgs.stdenv.mkDerivation rec {
          name = "todo-txt-web-${version}";
          version = "0.1.0";
          depsBuildBuild = [ pkgs.nim ];
          buildInputs = [ pkgs.pcre ];
          src = ./src;
          buildPhase = ''
            TMP=$(realpath .)
            nim compile \
              -d:release \
              --nimcache:$TMP \
              --out:todo-txt-web \
              ${src}/main.nim
          '';
          installPhase = ''
            install -Dt \
              $out/bin \
              todo-txt-web
          '';

          NIX_LDFLAGS = "-lpcre";

          meta = with pkgs.lib; {
            description = "Web frontend for a todo.txt file";
            homepage = "https://github.com/jwoudenberg/todo-txt-web";
            license = licenses.mit;
            platforms = with platforms; linux ++ darwin;
          };
        };

      in {
        defaultPackage = app;
        devShell = pkgs.mkShell { buildInputs = [ pkgs.nim ]; };
      });
}
