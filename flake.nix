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
        
        # Fetch pybind11 source for CMake
        pybind11Src = pkgs.fetchFromGitHub {
          owner = "pybind";
          repo = "pybind11";
          rev = "v2.11.1";
          sha256 = "sha256-sO/Fa+QrAKyq2EYyYMcjPrYI+bdJIrDoj6L3JHoDo3E=";
        };
        
        # Fetch yaml-cpp source for CMake
        yamlCppSrc = pkgs.fetchFromGitHub {
          owner = "jbeder";
          repo = "yaml-cpp";
          rev = "yaml-cpp-0.7.0";
          sha256 = "sha256-2tFWccifn0c2lU/U1WNg2FHrBohjx8CXMllPJCevaNk=";
        };
        
        # Fetch googletest source for CMake
        gtestSrc = pkgs.fetchFromGitHub {
          owner = "google";
          repo = "googletest";
          rev = "release-1.12.1";
          sha256 = "sha256-W+OxRTVtemt2esw4P7IyGWXOonUN5ZuscjvzqkYvZbM=";
        };
        
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
            
            # Copy pre-fetched sources to externals directory
            cp -r ${pybind11Src} externals/pybind11-src
            chmod -R +w externals/pybind11-src
            
            cp -r ${yamlCppSrc} externals/yaml-cpp-src
            chmod -R +w externals/yaml-cpp-src
            
            cp -r ${gtestSrc} externals/gtest-src
            chmod -R +w externals/gtest-src
            
            # Patch yaml-cpp's CMakeLists.txt to use CMake 3.12
            sed -i 's/cmake_minimum_required(VERSION 3\.4)/cmake_minimum_required(VERSION 3.12)/' externals/yaml-cpp-src/CMakeLists.txt
          '';
          
          # Patch the setup.py to be more Nix-friendly
          postPatch = ''
            # Replace the shutil.rmtree calls with pass to maintain syntax
            sed -i 's/shutil\.rmtree(p)/pass  # removed for Nix build/' setup.py
            sed -i 's/print("Removing some cache file: ", p)/pass  # removed for Nix build/' setup.py
            
            # Patch CMakeLists.txt to skip external project downloads
            # Comment out the external project includes
            sed -i '/include(cmake\/pybind11.cmake)/d' CMakeLists.txt
            sed -i '/include(cmake\/yaml.cmake)/d' CMakeLists.txt
            sed -i '/include(cmake\/gtest.cmake)/d' CMakeLists.txt
            
            # Add the pre-fetched sources directly
            sed -i '45i add_subdirectory(externals/pybind11-src)' CMakeLists.txt
            sed -i '46i add_subdirectory(externals/yaml-cpp-src)' CMakeLists.txt
            sed -i '47i add_subdirectory(externals/gtest-src)' CMakeLists.txt
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
            zmqpp
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
            # Ensure we're in the source root for setup.py
            cd $sourceRoot || cd ..
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
            pkgs.zmqpp
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
      }
    ) // {
      # Overlays at the top level (not per-system)
      overlays.default = final: prev: {
        flightmare = prev.python311.withPackages (ps: [
          (ps.callPackage ./flightlib {})
          (ps.callPackage ./flightrl_v2 {})
        ]);
      };
    };
}
