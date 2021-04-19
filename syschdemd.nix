{ lib, pkgs, config, defaultUser ? "nixos", ... }:

pkgs.substituteAll {
  name = "syschdemd";
  src = ./syschdemd.sh;
  dir = "bin";
  isExecutable = true;

  buildInputs = with pkgs; [ daemonize ];

  inherit (pkgs) daemonize;
  inherit defaultUser;
  # TODO: flake packages can't access `config.security`.
  # inherit (config.security) wrapperDir;
  # TODO: flake packages can't access `config.system`.
  # fsPackagesPath = lib.makeBinPath config.system.fsPackages;
}
