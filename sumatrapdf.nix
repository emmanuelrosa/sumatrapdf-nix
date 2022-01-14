{ stdenv
, lib
, mkWindowsApp
, wine
, fetchurl
, makeDesktopItem
, makeDesktopIcon
, copyDesktopItems
, copyDesktopIcons
, unzip }:
mkWindowsApp rec {
  inherit wine;

  pname = "sumatrapdf";
  version = "3.3.3";

  src = fetchurl {
    url = "https://kjkpubsf.sfo2.digitaloceanspaces.com/software/sumatrapdf/rel/SumatraPDF-${version}-64.zip";
    sha256 = "1b9l2hjngllzb478gvhp3dzn8hpxp9yj3q1wnq59d9356bi33md4";
  };

  dontUnpack = true;
  wineArch = "win64";
  nativeBuildInputs = [ unzip copyDesktopItems copyDesktopIcons ];

  winAppInstall = ''
    d="$WINEPREFIX/drive_c/${pname}"
    mkdir -p "$d"
    unzip ${src} -d "$d"
  '';

  winAppRun = ''
    config_dir="$HOME/.config/sumatrapdf"
    cache_dir="$HOME/.cache/sumatrapdf"

    mkdir -p "$config_dir" "$cache_dir"
    touch "$config_dir/SumatraPDF-settings.txt"
    ln -s "$config_dir/SumatraPDF-settings.txt" "$WINEPREFIX/drive_c/${pname}/SumatraPDF-settings.txt"
    ln -s "$cache_dir" "$WINEPREFIX/drive_c/${pname}/${pname}cache"

    wine "$WINEPREFIX/drive_c/${pname}/SumatraPDF-${version}-64.exe"
  '';

  installPhase = ''
    runHook preInstall

    ln -s $out/bin/.launcher $out/bin/${pname}

    runHook postInstall
  '';

  desktopItems = [
    (makeDesktopItem {
      name = pname;
      exec = pname;
      icon = pname;
      desktopName = "Sumatra PDF";
      genericName = "PDF Viewer";
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

