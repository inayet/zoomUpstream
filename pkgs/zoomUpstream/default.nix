{
  lib,
  makeWrapper,
  qt5,
  qt6,
  wrapGAppsHook,
  pkgs,
  stdenv,
  fetchurl,
  autoPatchelfHook,
  dpkg,
  copyDesktopItems,
  makeDesktopItem,
  alsa-lib,
  atk,
  at-spi2-atk,
  at-spi2-core,
  cairo,
  cups,
  dbus,
  expat,
  fontconfig,
  freetype,
  gdk-pixbuf,
  glib,
  gtk3,
  libdrm,
  libglvnd,
  libpulseaudio,
  pulseaudio,
  xdg-utils,

  wayland,
  libxkbcommon,
  pipewire,
  wireplumber,
  xdg-desktop-portal,
  xdg-desktop-portal-gtk,

  xdg-desktop-portal-wlr,

  libsecret,

  libuuid,
  mesa,
  nspr,
  nss,
  pango,
  systemd,
  udev,
  xorg,
  ...
}:

let
  versionInfo = import ./version.nix { inherit fetchurl; };
in

stdenv.mkDerivation rec {
  pname = "zoomUpstream";
  version = versionInfo.version;

  src = versionInfo.src;
  dontWrapQtApps = true;
  nativeBuildInputs = [
    autoPatchelfHook
    dpkg
    copyDesktopItems
    makeWrapper
    wrapGAppsHook
  ];
  buildInputs = [
    alsa-lib
    atk
    at-spi2-atk
    at-spi2-core
    cairo
    cups
    dbus
    expat
    fontconfig
    freetype
    gdk-pixbuf
    glib
    gtk3
    libdrm
    libglvnd
    libpulseaudio
    pulseaudio
    xdg-utils

    wayland
    libxkbcommon
    pipewire
    wireplumber
    xdg-desktop-portal
    xdg-desktop-portal-gtk
    pkgs.kdePackages.xdg-desktop-portal-kde
    xdg-desktop-portal-wlr

    libsecret

    libuuid
    mesa
    nspr
    nss
    pango
    systemd
    udev

    # X11 libraries
    xorg.libX11
    xorg.libxcb
    xorg.libXcomposite
    xorg.libXcursor
    xorg.libXdamage
    xorg.libXext
    xorg.libXfixes
    xorg.libXi
    xorg.libXrender
    xorg.libXrandr
    xorg.libXtst
    xorg.libXScrnSaver
    xorg.libxshmfence

    # XCB utilities
    xorg.xcbutil
    xorg.xcbutilcursor
    xorg.xcbutilimage
    xorg.xcbutilwm # Fixed: was xcbutiliwm
    xorg.xcbutilrenderutil
    xorg.xcbutilkeysyms

    # Dropped Qt5 libraries (Qt6-only)
    # qt5.qtbase
    # qt5.qtmultimedia
    # qt5.qtremoteobjects
    # qt5.qtxmlpatterns

    # qt5.qt3d
    # qt5.qtgamepad
    # qt5.qtquickcontrols2
    # qt5.qtdeclarative
  ];

  unpackPhase = ''
    runHook preUnpack
    dpkg-deb -x $src .
    runHook postUnpack
  '';

  installPhase = ''
    runHook preInstall
    mkdir -p $out
    cp -r opt/zoom $out/
    mkdir -p $out/bin
    ln -s $out/zoom/zoom $out/bin/zoom
    runHook postInstall
  '';

  postFixup = ''
    # Common library and plugin paths for Zoom and its CEF host
    qtLibPath="$out/zoom/Qt/lib"
    cefLibPath="$out/zoom/cef"
    appLibPath="$out/zoom"
    qtPluginPath="$out/zoom/Qt/plugins"
    qmlImportPath="$out/zoom/Qt/qml"

    # Wrap main Zoom binary
    wrapProgram $out/bin/zoom \
      --prefix PATH : ${lib.makeBinPath [ pulseaudio xdg-utils dbus xdg-desktop-portal xdg-desktop-portal-gtk pkgs.kdePackages.xdg-desktop-portal-kde xdg-desktop-portal-wlr pipewire wireplumber ]} \
      --prefix LD_LIBRARY_PATH : "$qtLibPath:$cefLibPath:$appLibPath" \
      --prefix XDG_DATA_DIRS : ${lib.makeSearchPath "share" [ xdg-desktop-portal xdg-desktop-portal-gtk pkgs.kdePackages.xdg-desktop-portal-kde xdg-desktop-portal-wlr ]} \
      --run 'if [ -z "''${XDG_RUNTIME_DIR:-}" ]; then export XDG_RUNTIME_DIR="$(mktemp -d -t zoomrt-XXXXXX)"; fi' \
      --run 'if [ -z "''${DBUS_SESSION_BUS_ADDRESS:-}" ] && command -v dbus-run-session >/dev/null 2>&1 && [ -z "''${ZOOM_WRAPPER_DBUS:-}" ]; then export ZOOM_WRAPPER_DBUS=1; exec dbus-run-session -- "$0" "$@"; fi' \
      --run 'if [ ! -S "''${XDG_RUNTIME_DIR}/pipewire-0" ] && command -v pipewire >/dev/null 2>&1; then (pipewire >/dev/null 2>&1 &); fi' \
      --run 'if [ ! -S "''${XDG_RUNTIME_DIR}/pulse/native" ] && command -v pipewire-pulse >/dev/null 2>&1; then (pipewire-pulse >/dev/null 2>&1 &); fi' \
      --run 'if command -v wireplumber >/dev/null 2>&1; then (wireplumber >/dev/null 2>&1 &); fi' \
      --run 'if command -v xdg-desktop-portal >/dev/null 2>&1; then (xdg-desktop-portal >/dev/null 2>&1 &); fi' \
      --run 'if command -v xdg-desktop-portal-gtk >/dev/null 2>&1; then (xdg-desktop-portal-gtk >/dev/null 2>&1 &); fi' \
      --set QT_PLUGIN_PATH "$qtPluginPath" \
      --set QML2_IMPORT_PATH "$qmlImportPath" \
      --set QT_STYLE_OVERRIDE Fusion \
      --set ZOOM_USE_WAYLAND 1 \
      --set QT_QPA_PLATFORM "wayland;xcb" \
      --set QTWEBENGINE_DISABLE_SANDBOX 1 \
      --set QTWEBENGINE_CHROMIUM_FLAGS "--enable-features=UseOzonePlatform,WebRTCPipeWireCapturer --ozone-platform-hint=auto --enable-wayland-ime --ignore-gpu-blocklist" \
      --add-flags "--use-gl=desktop --ozone-platform-hint=auto --enable-wayland-ime --no-sandbox --disable-setuid-sandbox --disable-gpu-sandbox --no-zygote --disable-seccomp-filter-sandbox --ignore-gpu-blocklist"

    # Ensure the CEF host gets the same flags and environment
    wrapProgram $out/zoom/ZoomWebviewHost \
      --prefix PATH : ${lib.makeBinPath [ xdg-utils dbus xdg-desktop-portal xdg-desktop-portal-gtk pkgs.kdePackages.xdg-desktop-portal-kde xdg-desktop-portal-wlr pipewire wireplumber ]} \
      --prefix LD_LIBRARY_PATH : "$qtLibPath:$cefLibPath:$appLibPath" \
      --prefix XDG_DATA_DIRS : ${lib.makeSearchPath "share" [ xdg-desktop-portal xdg-desktop-portal-gtk pkgs.kdePackages.xdg-desktop-portal-kde xdg-desktop-portal-wlr ]} \
      --run 'if [ -z "''${XDG_RUNTIME_DIR:-}" ]; then export XDG_RUNTIME_DIR="$(mktemp -d -t zoomrt-XXXXXX)"; fi' \
      --run 'if [ ! -S "''${XDG_RUNTIME_DIR}/pipewire-0" ] && command -v pipewire >/dev/null 2>&1; then (pipewire >/dev/null 2>&1 &); fi' \
      --run 'if [ ! -S "''${XDG_RUNTIME_DIR}/pulse/native" ] && command -v pipewire-pulse >/dev/null 2>&1; then (pipewire-pulse >/dev/null 2>&1 &); fi' \
      --run 'if command -v wireplumber >/dev/null 2>&1; then (wireplumber >/dev/null 2>&1 &); fi' \
      --run 'if command -v xdg-desktop-portal >/dev/null 2>&1; then (xdg-desktop-portal >/dev/null 2>&1 &); fi' \
      --run 'if command -v xdg-desktop-portal-gtk >/dev/null 2>&1; then (xdg-desktop-portal-gtk >/dev/null 2>&1 &); fi' \
      --set QT_PLUGIN_PATH "$qtPluginPath" \
      --set QML2_IMPORT_PATH "$qmlImportPath" \
      --set QT_STYLE_OVERRIDE Fusion \
      --set QT_QPA_PLATFORM "wayland;xcb" \
      --set QTWEBENGINE_DISABLE_SANDBOX 1 \
      --set QTWEBENGINE_CHROMIUM_FLAGS "--enable-features=UseOzonePlatform,WebRTCPipeWireCapturer --ozone-platform-hint=auto --enable-wayland-ime --ignore-gpu-blocklist" \
      --add-flags "--use-gl=desktop --ozone-platform-hint=auto --enable-wayland-ime --no-sandbox --disable-setuid-sandbox --disable-gpu-sandbox --no-zygote --disable-seccomp-filter-sandbox --ignore-gpu-blocklist"
  '';

  desktopItems = [
    (makeDesktopItem {
      name = "zoomUpstream";
      exec = "${placeholder "out"}/bin/zoom";
      icon = "${placeholder "out"}/zoom/icon.png";
      comment = "Zoom Video Conferencing (upstream)";
      desktopName = "Zoom";
      categories = [
        "Network"
        "VideoConference"
      ];
    })
  ];

  meta = with lib; {
    description = "Zoom Video Conferencing client (upstream binary repackaged for Nix)";
    homepage = "https://zoom.us";
    license = licenses.unfree;
    maintainers = with maintainers; [ ];
    platforms = platforms.linux;
  };
}
