{
  description = "Flightmare - Modern Reinforcement Learning Edition";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = nixpkgs.legacyPackages.${system};
        
        # Python with all required packages
        python = pkgs.python311;
        
        # Python packages for flightrl_v2
        pythonPackages = python.pkgs;
        
        # Build flightlib (C++ library with Python bindings)
        flightlib = pythonPackages.buildPythonPackage rec {
          pname = "flightgym";
          version = "0.0.1";
          format = "setuptools";

          src = ./flightlib;

          # Set the FLIGHTMARE_PATH environment variable required by setup.py
          preConfigure = ''
            export FLIGHTMARE_PATH=$(pwd)/..
          '';

          nativeBuildInputs = with pkgs; [
            cmake
            pkg-config
          ];

          buildInputs = with pkgs; [
            eigen
            opencv
            zeromq
            cppzmq
            yaml-cpp
            glog
            openmp
          ];

          propagatedBuildInputs = with pythonPackages; [
            numpy
            ruamel-yaml
            pybind11
          ];

          # Don't run tests during build
          doCheck = false;

          meta = with pkgs.lib; {
            description = "Flightmare C++ physics engine with Python bindings";
            license = licenses.mit;
            platforms = platforms.linux ++ platforms.darwin;
          };
        };

        # Build flightrl_v2 (Python RL framework)
        flightrl_v2 = pythonPackages.buildPythonPackage rec {
          pname = "flightrl_v2";
          version = "2.0.0";
          format = "setuptools";

          src = ./flightrl_v2;

          propagatedBuildInputs = with pythonPackages; [
            flightlib
            gymnasium
            stable-baselines3
            # sb3-contrib - not available in nixpkgs
            torch
            numpy
            matplotlib
            tensorboard
            ruamel-yaml
            pandas
            pillow
            # plotly - may not be in nixpkgs
            tqdm
            imageio
            imageio-ffmpeg
          ] ++ (with pkgs; [
            # Additional packages that might not be in pythonPackages
          ]);

          # Don't run tests during build
          doCheck = false;

          meta = with pkgs.lib; {
            description = "Modern Reinforcement Learning for Flightmare";
            license = licenses.mit;
            platforms = platforms.linux ++ platforms.darwin;
          };
        };

        # Create a combined package with both libraries
        flightmare = pkgs.buildEnv {
          name = "flightmare-${flightrl_v2.version}";
          paths = [ flightlib flightrl_v2 ];
        };

        # Development shell with all dependencies
        devShell = pkgs.mkShell {
          buildInputs = [
            # Build tools
            pkgs.cmake
            pkgs.pkg-config
            pkgs.gcc
            
            # C++ dependencies
            pkgs.eigen
            pkgs.opencv
            pkgs.zeromq
            pkgs.cppzmq
            pkgs.yaml-cpp
            pkgs.glog
            pkgs.openmp
            
            # Python and packages
            python
            pythonPackages.pip
            pythonPackages.setuptools
            pythonPackages.wheel
            pythonPackages.numpy
            pythonPackages.ruamel-yaml
            pythonPackages.pybind11
            pythonPackages.gymnasium
            pythonPackages.stable-baselines3
            pythonPackages.torch
            pythonPackages.matplotlib
            pythonPackages.tensorboard
            pythonPackages.pandas
            pythonPackages.pillow
            pythonPackages.tqdm
            pythonPackages.imageio
            pythonPackages.imageio-ffmpeg
            pythonPackages.pytest
            pythonPackages.pytest-cov
          ];

          shellHook = ''
            export FLIGHTMARE_PATH=$(pwd)
            echo "Flightmare development environment"
            echo "Python: $(python --version)"
            echo "FLIGHTMARE_PATH: $FLIGHTMARE_PATH"
          '';
        };

      in {
        packages = {
          default = flightmare;
          flightlib = flightlib;
          flightrl_v2 = flightrl_v2;
          flightmare = flightmare;
        };

        devShells.default = devShell;

        apps.default = {
          type = "app";
          program = "${python}/bin/python";
        };
      }
    );
}
