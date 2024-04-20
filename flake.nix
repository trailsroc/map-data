{
  description = "flake for #TR mapbox data";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs?ref=nixos-unstable";
    pre-commit-hooks.url = "github:cachix/pre-commit-hooks.nix";
    flake-parts.url = "github:hercules-ci/flake-parts";
  };

  outputs = inputs @ {
    self,
    nixpkgs,
    pre-commit-hooks,
    flake-parts,
  }:
    flake-parts.lib.mkFlake {inherit inputs;} {
      systems = [
        "x86_64-linux"
      ];
      perSystem = {
        pkgs,
        system,
        ...
      }: {
        checks = {
          pre-commit-check = pre-commit-hooks.lib.${system}.run {
            src = ./.;
            hooks = {
              alejandra.enable = true;
              check-added-large-files.enable = true;
              check-builtin-literals.enable = true;
              check-executables-have-shebangs.enable = true;
              check-json.enable = true;
              check-shebang-scripts-are-executable.enable = true;
              check-merge-conflicts.enable = true;
              check-yaml.enable = true;
              python-debug-statements.enable = true;
              end-of-file-fixer.enable = true;
              mixed-line-endings.enable = true;
              trim-trailing-whitespace.enable = true;
              shellcheck.enable = true;
              shfmt.enable = true;
              ruff.enable = true;
              ruff.entry = "ruff check";

              ruff-format = {
                enable = true;
                name = "ruff format";
                entry = "ruff format";
                files = "\\.py$";
              };
            };
          };
        };

        devShells.default = let
          pkgs = nixpkgs.legacyPackages.${system};
        in
          pkgs.mkShell {
            inherit (self.checks.${system}.pre-commit-check) shellHook;
            buildInputs = self.checks.${system}.pre-commit-check.enabledPackages;
            packages = with pkgs; [
              (pkgs.python3.withPackages (p: [
                p.gpxpy
                p.click
                p.numpy
                p.astropy
                p.matplotlib
                p.geopandas
                p.ipython
                p.pydantic
                p.devtools
                (p.callPackage ./pyogrio.nix {})
                (p.callPackage ./geojson.nix {})
              ]))
              ruff
              sqlite
              pre-commit
            ];
          };
      };
    };
}
