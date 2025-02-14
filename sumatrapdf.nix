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
in mkWindowsApp rec {
  inherit wine;

  pname = "sumatrapdf";
  version = "3.5.2";

  src = builtins.fetchurl {
    url = "https://www.sumatrapdfreader.org/dl/rel/${version}/SumatraPDF-${version}-64.zip";
    sha256 = "sha256:1299a6n4m13a22sig53dmlz3nf3pr1q9kfyz49lcwk8qr6av7k36";
  };

  # By default, when a Wine prefix is first created Wine will produce a warning prompt if Mono is not installed.
  # This doesn't happen with the Wine "full" packages, but it does happen with the "base" packages.
  # When this option is set to 'false', DLL overrides are used when the Wine prefix is created, to bypass the prompt.
  enableMonoBootPrompt = false;

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
  # To figure out what needs to be persisted, take at look at $(dirname $WINEPREFIX)/upper,
  # while the app is running.
  fileMap = { "$HOME/.config/${pname}/SumatraPDF-settings.txt" = "drive_c/${pname}/SumatraPDF-settings.txt";
              "$HOME/.cache/${pname}" = "drive_c/${pname}/${pname}cache";
  };

  # By default, `fileMap` is applied right before running the app and is cleaned up after the app terminates. If the following option is set to "true", then `fileMap` is also applied prior to `winAppInstall`. This is set to "false" by default.
  fileMapDuringAppInstall = false;

  # By default `mkWindowsApp` doesn't persist registry changes made during runtime. Therefore, if an app uses the registry then set this to "true". The registry files are saved to `$HOME/.local/share/mkWindowsApp/$pname/`.
  persistRegistry = false;

  # By default mkWindowsApp creates ephemeral (temporary) WINEPREFIX(es). 
  # Setting persistRuntimeLayer to true causes mkWindowsApp to retain the WINEPREFIX, for the short term. 
  # This option is designed for apps which can't have their automatic updates disabled.
  # It allows package maintainers to not have to constantly update their mkWindowsApp packages.
  # It is NOT meant for long-term persistance; If the Windows or App layers change, the Runtime layer will be discarded.
  persistRuntimeLayer = false;

  # The method used to calculate the input hashes for the layers.
  # This should be set to "store-path", which is the strictest and most reproduceable method. But it results in many rebuilds of the layers since the slightest change to the package inputs will change the input hashes.
  # An alternative is "version" which is a relaxed method and results in fewer rebuilds but is less reproduceable. If you are considering using "version", contact me first. There may be a better way.
  inputHashMethod = "store-path";

  # When enabled, the Direct3D backend is changed from OpenGL to vulkan.
  # Used mainly for Direct3D games.
  enableVulkan = false;

  # Can be used to precisely select the Direct3D implementation.
  #
  # | enableVulkan | rendererOverride | Direct3D implementation |
  # |--------------|------------------|-------------------------|
  # | false        | null             | OpenGL                  |
  # | true         | null             | Vulkan (DXVK)           |
  # | *            | dxvk-vulkan      | Vulkan (DXVK)           |
  # | *            | wine-opengl      | OpenGL                  |
  # | *            | wine-vulkan      | Vulkan (VKD3D)          |
  rendererOverride = null;

  # When enabled, the environment variable $MANGOHUD is set to the path to mangohud.
  # Mainly used for games.
  enableHUD = false;

  # Wine creates a number of symlinks in the Windows user profile directory.
  # This attribute set allows specific symlinks to be disabled.
  # For example, if you find that an application creates a Windows shortcut in your Linux home directory,
  # the Desktop symlink can be disabled with { desktop = false; }.
  # When a symlink is disabled, it's replaced with a directory. That way anything written to it remains in a mkWindowsApp layer.
  # Acceptable attributes, all of which default to the boolean value 'true', are:
  # desktop, documents, downloads, music, pictures, and videos.
  enabledWineSymlinks = { };

  # Starting with version 10, Wine uses Wayland if it's available. But, usually Wayland compositors enable xwayland,
  # which causes Wine to default to X11.
  # When `graphicsDriver` is set to "auto", Wine is allowed to determine whether to use Wayland or X11.
  # When set to "wayland", DISPLAY is unset prior to running Wine, causing it to use Wayland.
  # When set to "prefer-wayland", DISPLAY is unset only if WAYLAND_DISPLAY is set, causing Wine to use Wayland only when Wayland is available.
  graphicsDriver = "auto";

  # When set to true, and if systemd-inhibit is found in $PATH, the launcher script will obtain an idle inhibit lock when executing the Windows app.
  # An idle inhibit lock can prevent the screen from turning off. Thus, this is most useful for Windows games.
  inhibitIdle = false;

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


  # This code runs before winAppRun, but only for the first instance.
  # Therefore, if the app is already running, winAppRun will not execute.
  # Use this to do any setup prior to running the app.
  winAppPreRun = ''
  '';

  # This code will become part of the launcher script.
  # It will execute after winAppInstall and winAppPreRun (if needed),
  # to run the application.
  # WINEPREFIX, WINEARCH, AND WINEDLLOVERRIDES are set
  # and wine, winetricks, and cabextract are in the environment.
  # Command line arguments are in $ARGS, not $@
  # DO NOT BLOCK. For example, don't run: wineserver -w
  winAppRun = ''
    wine "$WINEPREFIX/drive_c/${pname}/SumatraPDF-${version}-64.exe" "$ARGS"
  '';

  # This code will run after winAppRun, but only for the first instance.
  # Therefore, if the app was already running, winAppPostRun will not execute.
  # In other words, winAppPostRun is only executed if winAppPreRun is executed.
  # Use this to do any cleanup after the app has terminated
  winAppPostRun = "";

  # This is a normal mkDerivation installPhase, with some caveats.
  # The launcher script will be installed at $out/bin/.launcher
  # DO NOT DELETE OR RENAME the launcher. Instead, link to it as shown.
  installPhase = ''
    runHook preInstall

    ln -s $out/bin/.launcher $out/bin/${pname}

    runHook postInstall
  '';

  desktopItems = let
    mimeTypes = ["application/pdf"
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
      inherit mimeTypes;

      name = pname;
      exec = pname;
      icon = pname;
      desktopName = "Sumatra PDF";
      genericName = "Document Viewer";
      categories = ["Office" "Viewer"];
    })
  ];

  desktopIcon = makeDesktopIcon {
    name = "sumatrapdf";

    src = fetchurl {
      url = "https://github.com/sumatrapdfreader/sumatrapdf/raw/${version}rel/gfx/SumatraPDF-256x256x32.png";
      sha256 = "sha256-i1wHW5zFmm9q56ydKhCxfExiATlpZyrIe3fhF1tJ7dA=";
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

