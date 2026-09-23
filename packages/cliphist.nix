{ optimization, pkgs }:

pkgs.cliphist.overrideAttrs optimization.withGoOverride
