{
  description = "LutinLens development shell";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }: 
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs { inherit system; };
      in {
        devShell = pkgs.mkShell {
          buildInputs = [
            pkgs.flutter
            pkgs.fvm
            pkgs.androidsdk
            pkgs.openjdk
            pkgs.envdir
            pkgs.git
          ];
          shellHook = ''
            echo "→ Loading environment from .envdir"
            envdir .envdir || echo "⚠️ .envdir not found or envdir not installed"
          '';
        };
      }
    );
}
