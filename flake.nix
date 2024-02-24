{
  description = "Flake for os161 at unsw";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs?ref=nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";

    os161-binutils-src = {
      url =
        "http://www.cse.unsw.edu.au/~cs3231/os161-files/binutils-2.24+os161-2.1.tar.gz";
      flake = false;
    };
    os161-gcc-src = {
      url =
        "http://www.cse.unsw.edu.au/~cs3231/os161-files/gcc-4.8.3+os161-2.1.tar.gz";
      flake = false;
    };
    os161-gdb-src = {
      url =
        "http://www.cse.unsw.edu.au/~cs3231/os161-files/gdb-7.8+os161-2.1.tar.gz";
      flake = false;
    };
    os161-sys161-src = {
      url =
        "http://www.cse.unsw.edu.au/~cs3231/os161-files/sys161-2.0.8.tar.gz";
      flake = false;
    };
    config-guess = {
      url =
        "https://git.savannah.gnu.org/cgit/config.git/plain/config.guess?id=20403c5701973a4cbd7e0b4bbeb627fcd424a0f1";
      flake = false;
    };
  };

  outputs = { self, ... }@inputs:
    inputs.flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import inputs.nixpkgs { inherit system; };
        stdenv = pkgs.stdenv;
        self-pkgs = self.packages.${system};
        enableParallelBuilding = true;
        installPhase = ''
          mkdir -p $out/bin
          make install -j$(nproc)
          cd $out/bin
          for i in mips-*; do ln -s $i os161-`echo $i | cut -d- -f4-`; done
        '';
        updateAutotoolsGnuConfigScriptsPhase = ''echo "skipping"'';
      in {
        packages = rec {
          os161-binutils = stdenv.mkDerivation {
            name = "os161-binutils";
            inherit system enableParallelBuilding installPhase
              updateAutotoolsGnuConfigScriptsPhase;
            src = inputs.os161-binutils-src;
            configureFlags =
              [ "--nfp" "--disable-werror" "--target=mips-harvard-os161" ];
          };

          os161-sys161 = stdenv.mkDerivation {
            name = "os161-sys161";
            inherit system enableParallelBuilding installPhase
              updateAutotoolsGnuConfigScriptsPhase;
            src = inputs.os161-sys161-src;
            CFLAGS = "-fcommon";
            configureFlags = [ "mipseb" ];
          };

          os161-gcc = stdenv.mkDerivation {
            name = "os161-gcc";
            inherit system enableParallelBuilding installPhase
              updateAutotoolsGnuConfigScriptsPhase;
            src = inputs.os161-gcc-src;

            buildInputs =
              [ self-pkgs.os161-binutils pkgs.libmpc pkgs.mpfr pkgs.gmp ];

            CXXFLAGS = "-Wno-error=format-security --std=c++03";

            configurePhase = ''
              mkdir buildgcc
              cd buildgcc # dont cd out of it, so later phases execute here too
              cp ${inputs.config-guess} config.guess
              chmod u+x config.guess
              ../configure \
                --enable-languages=c,lto \
                --nfp --disable-shared --disable-threads \
                --disable-libmudflap --disable-libssp \
                --disable-libstdcxx --disable-nls \
                --with-as=${self-pkgs.os161-binutils}/bin/os161-as \
                --with-ld=${self-pkgs.os161-binutils}/bin/os161-ld \
                --target=mips-harvard-os161 \
                --prefix=$out
            '';
          };

          os161-gdb = stdenv.mkDerivation {
            name = "os161-gdb";
            inherit system enableParallelBuilding installPhase
              updateAutotoolsGnuConfigScriptsPhase;
            src = inputs.os161-gdb-src;

            buildInputs = [ self-pkgs.os161-binutils pkgs.ncurses ];

            CFLAGS = "--std=gnu89";

            configurePhase = ''
              ./configure --target=mips-harvard-os161 --prefix=$out --with-python=no
            '';
          };
        };

        devShells.default = pkgs.mkShell {
          buildInputs = [
            self-pkgs.os161-binutils
            self-pkgs.os161-gcc
            self-pkgs.os161-gdb
            self-pkgs.os161-sys161
            pkgs.bmake
            pkgs.python3
            pkgs.bear
          ];
        };
      });
}
