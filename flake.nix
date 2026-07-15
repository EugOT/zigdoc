{
  description = "zigdoc";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  outputs =
    {
      self,
      nixpkgs,
    }:
    let
      systems = [
        "aarch64-darwin"
        "aarch64-linux"
        "x86_64-darwin"
        "x86_64-linux"
      ];
      forAllSystems = nixpkgs.lib.genAttrs systems;
      pkgsFor = system: import nixpkgs { inherit system; };
    in
    {
      devShells = forAllSystems (
        system:
        let
          pkgs = pkgsFor system;
          zig = pkgs.zig_0_16 or pkgs.zig;
        in
        {
          default = pkgs.mkShell {
            packages = [
              zig
            ];
          };
        }
      );

      packages = forAllSystems (
        system:
        let
          pkgs = pkgsFor system;
          zig = pkgs.zig_0_16 or pkgs.zig;
        in
        {
          default = pkgs.stdenv.mkDerivation {
            pname = "zigdoc";
            version = "0.0.0";
            src = self;

            nativeBuildInputs = [
              zig.hook
            ];

            zigBuildFlags = [
              "-Dcpu=baseline"
              "-Doptimize=ReleaseFast"
            ];

            installPhase = ''
              runHook preInstall
              install -Dm755 zig-out/bin/zigdoc $out/bin/zigdoc
              runHook postInstall
            '';
          };
        }
      );

      formatter = forAllSystems (system: (pkgsFor system).nixfmt);
    };
}
