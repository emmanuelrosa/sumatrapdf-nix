{ stdenv
, lib
, mkWindowsApp
, wine
, fetchurl
, makeDesktopItem
, makeDesktopIcon   # This comes with erosanix. It's a handy way to generate desktop icons.
, copyDesktopItems
, copyDesktopIcons  # This comes with erosanix. It's a handy way to generate desktop icons.
, unzip }: let
  # The default settings used if user doesn't already have a settings file.
  # Tabs are disabled because they lead to UI issues when using Wine.
  defaultSettings = ./SumatraPDF-settings.txt;

  # This registry file sets winebrowser (xdg-open) as the default handler for
  # text files, instead of Wine's notepad.
  # Selecting "Settings -> Advanced Options" should then use xdg-open to open the SumatraPDF config file.
  txtReg = ./txt.reg;
in mkWindowsApp rec {
  inherit wine;

  pname = "sumatrapdf";
  version = "3.3.3";

  src = fetchurl {
    url = "https://kjkpubsf.sfo2.digitaloceanspaces.com/software/sumatrapdf/rel/SumatraPDF-${version}-64.zip";
    sha256 = "1b9l2hjngllzb478gvhp3dzn8hpxp9yj3q1wnq59d9356bi33md4";
  };

  # In most cases, you'll either be using an .exe or .zip as the src.
  # Even in the case of a .zip, you probably want to unpack with the launcher script.
  dontUnpack = true;   

  # You need to set the WINEARCH, which can be either "win32" or "win64".
  # Note that the wine package you choose must be compatible with the Wine architecture.
  wineArch = "win64";

  # Sometimes it can take a while to install an application to generate an app layer.
  # `enableInstallNotification`, which is set to true by default, uses notify-send
  # to generate a system notification so that the user is aware that something is happening.
  # There are two notifications: one before the app installation and one after.
  # The notification will attempt to use the app's icon, if it can find it. And will fallback
  # to hard-coded icons if needed.
  # If an app installs quickly, these notifications can actually be distracting.
  # In such a case, it's better to set this option to false.
  # This package doesn't benefit from the notifications, but I've explicitly enabled them
  # for demonstration purposes.
  enableInstallNotification = true;

  # `fileMap` can be used to set up automatic symlinks to files which need to be persisted.
  # The attribute name is the source path and the value is the path within the $WINEPREFIX.
  # But note that you must ommit $WINEPREFIX from the path.
  fileMap = { "$HOME/.config/${pname}/SumatraPDF-settings.txt" = "drive_c/${pname}/SumatraPDF-settings.txt";
              "$HOME/.cache/${pname}" = "drive_c/${pname}/${pname}cache";
  };

  nativeBuildInputs = [ unzip copyDesktopItems copyDesktopIcons ];

  # This code will become part of the launcher script.
  # It will execute if the application needs to be installed,
  # which would happen either if the needed app layer doesn't exist,
  # or for some reason the needed Windows layer is missing, which would
  # invalidate the app layer.
  # WINEPREFIX, WINEARCH, AND WINEDLLOVERRIDES are set
  # and wine, winetricks, and cabextract are in the environment.
  winAppInstall = ''
    d="$WINEPREFIX/drive_c/${pname}"
    config_dir="$HOME/.config/sumatrapdf"

    mkdir -p "$d"
    unzip ${src} -d "$d"

    mkdir -p "$config_dir"
    cp -v -n "${defaultSettings}" "$config_dir/SumatraPDF-settings.txt"
    chmod ug+w "$config_dir/SumatraPDF-settings.txt"
  '';

  # This code will become part of the launcher script.
  # It will execute after winAppInstall (if needed)
  # to run the application.
  # WINEPREFIX, WINEARCH, AND WINEDLLOVERRIDES are set
  # and wine, winetricks, and cabextract are in the environment.
  # Command line arguments are in $ARGS, not $@
  # You need to set up symlinks for any files/directories that need to be persisted.
  # To figure out what needs to be persisted, take at look at $(dirname $WINEPREFIX)/upper
  winAppRun = ''
    regedit ${txtReg}
    wine "$WINEPREFIX/drive_c/${pname}/SumatraPDF-${version}-64.exe" "$ARGS"
  '';

  # This is a normal mkDerivation installPhase, with some caveats.
  # The launcher script will be installed at $out/bin/.launcher
  # DO NOT DELETE OR RENAME the launcher. Instead, link to it as shown.
  installPhase = ''
    runHook preInstall

    ln -s $out/bin/.launcher $out/bin/${pname}

    runHook postInstall
  '';

  desktopItems = let
    mimeType = builtins.concatStringsSep ";" [ "application/pdf"
                 "application/epub+zip"
                 "application/x-mobipocket-ebook"
                 "application/vnd.amazon.mobi8-ebook"
                 "application/x-zip-compressed-fb2"
                 "application/x-cbt"
                 "application/x-cb7"
                 "application/x-7z-compressed"
                 "application/vnd.rar"
                 "application/x-tar"
                 "application/zip"
                 "image/vnd.djvu"
                 "image/vnd.djvu+multipage"
                 "application/vnd.ms-xpsdocument"
                 "application/oxps"
                 "image/jpeg"
                 "image/png"
                 "image/gif"
                 "image/webp"
                 "image/tiff"
                 "image/tiff-multipage"
                 "image/x-tga"
                 "image/bmp"
                 "image/x-dib" ];
  in [
    (makeDesktopItem {
      inherit mimeType;

      name = pname;
      exec = pname;
      icon = pname;
      desktopName = "Sumatra PDF";
      genericName = "Document Viewer";
      categories = "Office;Viewer;";
    })
  ];

  desktopIcon = makeDesktopIcon {
    name = "sumatrapdf";

    src = fetchurl {
      url = "https://github.com/sumatrapdfreader/${pname}/raw/${version}rel/gfx/SumatraPDF-256x256x32.png";
      sha256 = "1l7d95digqbpgg42lrv9740n4k3wn482m7dcwxm6z6n5kidhfp4b";
    };
  };

  meta = with lib; {
    description = "A free PDF, eBook (ePub, Mobi), XPS, DjVu, CHM, Comic Book (CBZ and CBR) viewer for Windows.";
    homepage = "https://www.sumatrapdfreader.org/free-pdf-reader";
    license = licenses.gpl3;
    maintainers = with maintainers; [ emmanuelrosa ];
    platforms = [ "x86_64-linux" ];
  };
}

