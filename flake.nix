{
  description = "A Nix flake for SumatraPDF";

  inputs.erosanix.url = "github:emmanuelrosa/erosanix";
  inputs.nixpkgs.url = "github:NixOS/nixpkgs/master";

  outputs = { self, nixpkgs, erosanix }: {

    packages.x86_64-linux = let
      pkgs = import "${nixpkgs}" {
        system = "x86_64-linux";
      };

    in with (pkgs // erosanix.packages.x86_64-linux // erosanix.lib.x86_64-linux); {
      default = self.packages.x86_64-linux.sumatrapdf;

      sumatrapdf = callPackage ./sumatrapdf.nix {
        inherit mkWindowsApp makeDesktopIcon copyDesktopIcons;

        wine = wineWowPackages.full;
      };
    };

    apps.x86_64-linux.sumatrapdf = {
      type = "app";
      program = "${self.packages.x86_64-linux.sumatrapdf}/bin/sumatrapdf";
    };

    apps.x86_64-linux.default = self.apps.x86_64-linux.sumatrapdf;
  };
}
