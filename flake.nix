{
  description = "Flightmare - Modern Reinforcement Learning Edition";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs {
          inherit system;
          config = {
            allowUnfree = true;
          };
        };
        
        # Python with all required packages
        python = pkgs.python311;
        pythonPackages = python.pkgs;
        
        # Build flightlib (C++ library with Python bindings)
        flightlib = pythonPackages.buildPythonPackage rec {
          pname = "flightgym";
          version = "0.0.1";
          format = "setuptools";

          src = ./flightlib;

          # Set the FLIGHTMARE_PATH environment variable required by setup.py
          preConfigure = ''
            export FLIGHTMARE_PATH=$(realpath ..)
            # Create necessary directories
            mkdir -p build externals
          '';
          
          # Patch the setup.py to be more Nix-friendly
          postPatch = ''
            # Remove the parts that try to delete files
            sed -i '/shutil.rmtree/d' setup.py
            sed -i '/Removing some cache/d' setup.py
          '';

          nativeBuildInputs = with pkgs; [
            cmake
            pkg-config
            gcc
          ];

          buildInputs = with pkgs; [
            eigen
            opencv
            zeromq
            cppzmq
            yaml-cpp
            glog
          ] ++ pkgs.lib.optionals pkgs.stdenv.isLinux [
            pkgs.llvmPackages.openmp
          ];

          propagatedBuildInputs = with pythonPackages; [
            numpy
            ruamel-yaml
            pybind11
          ];

          # Pass CMake flags to find system packages
          cmakeFlags = [
            "-DEIGEN_FROM_SYSTEM=ON"
            "-DBUILD_TESTS=OFF"
            "-DBUILD_UNITY_BRIDGE_TESTS=OFF"
            "-DBUILD_BENCH=OFF"
          ];

          # Don't run tests during build
          doCheck = false;
          
          # Ensure the library can find dependencies
          preBuild = ''
            export NIX_CFLAGS_COMPILE="-I${pkgs.eigen}/include/eigen3 $NIX_CFLAGS_COMPILE"
            export CMAKE_PREFIX_PATH="${pkgs.eigen}:${pkgs.opencv}:${pkgs.yaml-cpp}:${pkgs.zeromq}:$CMAKE_PREFIX_PATH"
          '';

          meta = with pkgs.lib; {
            description = "Flightmare C++ physics engine with Python bindings";
            license = licenses.mit;
            platforms = platforms.linux ++ platforms.darwin;
            maintainers = [ ];
          };
        };

        # Build flightrl_v2 (Python RL framework)
        # Note: Some dependencies like sb3-contrib and plotly may need to be installed via pip
        # if they're not available in the specific nixpkgs version
        flightrl_v2 = pythonPackages.buildPythonPackage rec {
          pname = "flightrl_v2";
          version = "2.0.0";
          format = "setuptools";

          src = ./flightrl_v2;

          propagatedBuildInputs = with pythonPackages; [
            flightlib
            gymnasium
            stable-baselines3
            torch
            numpy
            matplotlib
            tensorboard
            ruamel-yaml
            pandas
            pillow
            tqdm
            imageio
            imageio-ffmpeg
          ] ++ pkgs.lib.optionals (pythonPackages ? plotly) [
            pythonPackages.plotly
          ];

          # Don't run tests during build
          doCheck = false;
          
          # Add a postInstall to remind about optional dependencies
          postInstall = ''
            cat > $out/lib/python*/site-packages/flightrl_v2_notice.txt << EOF
    Note: Some optional dependencies may not be available in nixpkgs:
    - sb3-contrib: Install via pip if needed for additional RL algorithms
    - plotly: May be available depending on nixpkgs version
    
    These can be installed in a development environment:
      nix develop
      pip install sb3-contrib plotly
    EOF
          '';

          meta = with pkgs.lib; {
            description = "Modern Reinforcement Learning for Flightmare";
            license = licenses.mit;
            platforms = platforms.linux ++ platforms.darwin;
            maintainers = [ ];
          };
        };

        # Python environment with all packages
        pythonEnv = python.withPackages (ps: [
          flightlib
          flightrl_v2
        ]);

        # Development shell with all dependencies
        devShell = pkgs.mkShell {
          name = "flightmare-dev";
          
          buildInputs = [
            # Build tools
            pkgs.cmake
            pkgs.pkg-config
            pkgs.gcc
            pkgs.git
            
            # C++ dependencies
            pkgs.eigen
            pkgs.opencv
            pkgs.zeromq
            pkgs.cppzmq
            pkgs.yaml-cpp
            pkgs.glog
            
            # Python environment
            pythonEnv
            
            # Additional utilities
            pkgs.htop
            pkgs.tmux
          ] ++ pkgs.lib.optionals pkgs.stdenv.isLinux [
            pkgs.llvmPackages.openmp
          ];

          shellHook = ''
            export FLIGHTMARE_PATH=$(pwd)
            export PYTHONPATH="${pythonEnv}/${python.sitePackages}:$PYTHONPATH"
            
            echo "╔════════════════════════════════════════════════════════╗"
            echo "║      Flightmare Development Environment               ║"
            echo "╚════════════════════════════════════════════════════════╝"
            echo ""
            echo "Python: $(python --version)"
            echo "FLIGHTMARE_PATH: $FLIGHTMARE_PATH"
            echo ""
            echo "Available commands:"
            echo "  python -c 'import flightgym; print(\"FlightGym loaded\")'"
            echo "  python -c 'import flightrl_v2; print(flightrl_v2.__version__)'"
            echo ""
            echo "To get started:"
            echo "  cd flightrl_v2/examples"
            echo "  python 01_basic_training.py --timesteps 1000"
            echo ""
          '';
        };

      in {
        packages = {
          default = pythonEnv;
          flightlib = flightlib;
          flightrl_v2 = flightrl_v2;
          flightmare = pythonEnv;
        };

        devShells.default = devShell;

        apps = {
          default = {
            type = "app";
            program = "${pythonEnv}/bin/python";
          };
          
          train = {
            type = "app";
            program = toString (pkgs.writeShellScript "train-flightmare" ''
              cd ${./flightrl_v2/examples}
              ${pythonEnv}/bin/python 01_basic_training.py "$@"
            '');
          };
        };

        # Provide an overlay for other flakes to use
        overlays.default = final: prev: {
          flightmare = pythonEnv;
          flightlib = flightlib;
          flightrl_v2 = flightrl_v2;
        };
      }
    );
}
