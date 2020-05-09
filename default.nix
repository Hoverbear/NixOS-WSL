# Build with
#   nix-build -A system -A config.system.build.tarball --show-trace
let
    # Snapshots of specific git revisions used to compose the system
    snapshots = rec {
        # The main pkg repo
        nixpkgs = builtins.fetchGit {
            name = "nixpkgs";
            # `git ls-remote https://github.com/nixos/nixpkgs nixpkgs-unstable`
            rev = "5f14d99efed32721172a819b6e78a5520bab4bc6";
            url = "https://github.com/nixos/nixpkgs";
            ref = "refs/heads/nixpkgs-unstable";
        };
    };
    # Imported nix expressions.
    nix = rec {
        pkgs = import snapshots.nixpkgs {
            config.allowUnfree = true;
        };
        os = import "${snapshots.nixpkgs}/nixos";
    };

    profile = "${snapshots.nixpkgs}/nixos/modules/profiles/minimal.nix";

    # The end configuration of the VM
    personality = rec {
        configuration = {
            imports = [
                profile
            ];

            users.users.root = {
                shell = "${syschdemd}/bin/syschdemd";
                # Otherwise WSL fails to login as root with "initgroups failed 5"
                extraGroups = [ "root" ];
            };

            boot.isContainer = true;
            environment.etc.hosts.enable = false;
            environment.etc."resolv.conf".enable = false;
            networking.dhcpcd.enable = false;
            # Described as "it should not be overwritten" in NixOS documentation,
            # but it's on /run per default and WSL mounts /run as a tmpfs, hence
            # hiding the wrappers.
            security.wrapperDir = "/wrappers";

            security.sudo.wheelNeedsPassword = false;

            # Disable systemd units that don't make sense on WSL
            systemd.services."serial-getty@ttyS0".enable = false;
            systemd.services."serial-getty@hvc0".enable = false;
            systemd.services."getty@tty1".enable = false;
            systemd.services."autovt@".enable = false;

            systemd.services.firewall.enable = false;
            systemd.services.systemd-resolved.enable = false;
            systemd.services.systemd-udevd.enable = false;

            # Don't allow emergency mode, because we don't have a console.
            systemd.enableEmergencyMode = false;
            system.fsPackages = [];
            system.build.tarball = nix.pkgs.callPackage "${snapshots.nixpkgs}/nixos/lib/make-system-tarball.nix" {
                stdenv = nix.pkgs.stdenv;
                closureInfo = nix.pkgs.closureInfo;
                pixz = nix.pkgs.pixz;

                contents = [];
                storeContents = with nix.pkgs; pkgs2storeContents [
                    stdenv
                    bash
                    gzip
                    preparer
                ];
                extraCommands = "${preparer}/bin/wsl-prepare";
                compressCommand = "gzip";
                compressionExtension = ".gz";
            };
        };
        system = "x86_64-linux";
    };

    pkgs2storeContents = l : map (x: { object = x; symlink = "none"; }) l;

    preparer = nix.pkgs.writeShellScriptBin "wsl-prepare" ''
        set -e

        mkdir -m 0755 ./bin ./etc
        mkdir -m 1777 ./tmp

        # WSL requires a /bin/sh - only temporary, NixOS's activate will overwrite
        ln -s ${nix.pkgs.stdenv.shell} ./bin/sh

        # WSL also requires a /bin/mount, otherwise the host fs isn't accessible
        ln -s /nix/var/nix/profiles/system/sw/bin/mount ./bin/mount

        # It's now a NixOS!
        touch ./etc/NIXOS
    '';

    syschdemd = import ./syschdemd.nix {
        lib = nix.pkgs.lib;
        pkgs = nix.pkgs;
        config = personality.configuration;
        defaultUser = "root";
    };

in nix.os personality
