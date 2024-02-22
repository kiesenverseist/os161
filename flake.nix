{
  description = "Flake for os161 at unsw";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs?ref=nixos-unstable";
    # could maybe look at compiling from source later
    os161-deb = {
      url = "http://www.cse.unsw.edu.au/~cs3231/os161-files/os161-utils_2.0.8-4.deb";
      flake = false;
    };
  };

  outputs = { self, ...}@inputs:
  let
    system = "x86_64-linux";
    pkgs = import inputs.nixpkgs {inherit system;};
  in 
  {
    # as this package is unpatched, it probably wont work outside of nix shell
    packages.${system} = {
      os161-utils = 
      let
        inherit system;
        inherit (pkgs) stdenv lib;
        src = inputs.os161-deb;
      in stdenv.mkDerivation
      {
        name = "os161-utils";
        inherit system src;
        buildInputs = [
          pkgs.dpkg
          pkgs.libmpc
          pkgs.mpfr
          pkgs.gmp
        ];
        unpackPhase = "true";
        installPhase = ''
          mkdir -p $out
          dpkg -x $src $out
          mv $out/usr/local/* $out/
          rm -r $out/usr
        '';
        postFixup = ''
          patchelf --add-needed ${pkgs.libmpc}/lib/libmpc.so.3 $out/libexec/gcc/mips-harvard-os161/4.8.3/cc1 
          patchelf --add-needed ${pkgs.mpfr}/lib/libmpfr.so.6 $out/libexec/gcc/mips-harvard-os161/4.8.3/cc1 
          patchelf --add-needed ${pkgs.gmp}/lib/libgmp.so.10 $out/libexec/gcc/mips-harvard-os161/4.8.3/cc1 
        '';
      };
    };

    devShells.${system}.default = 
    let 
      os161-utils = self.packages.${system}.os161-utils;
    in pkgs.mkShell {
      buildInputs = [ 
        os161-utils
        pkgs.python3
        pkgs.bear
      ];
      MAKESYSPATH="${os161-utils}/share/mk";
    };
  };
}
