{ pkgs }:

pkgs.cliphist.overrideAttrs (old: {
  doCheck = false;
  ldflags = [
    "-s"
    "-w"
  ]
  ++ (old.ldflags or [ ]);
  env = (old.env or { }) // {
    GOAMD64 = "v3";
    GOFLAGS = "-trimpath";
  };
})
