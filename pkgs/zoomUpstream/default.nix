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
    xorg.libXtst
    xorg.libXScrnSaver

    # XCB utilities
    xorg.xcbutil
    xorg.xcbutilcursor
    xorg.xcbutilimage
    xorg.xcbutilwm # Fixed: was xcbutiliwm
    xorg.xcbutilrenderutil

    # Qt5 libraries
    qt5.qtbase
    qt5.qtmultimedia
    qt5.qtremoteobjects
    qt5.qtxmlpatterns

    qt5.qt3d
    qt5.qtgamepad
    qt5.qtquickcontrols2
    qt5.qtdeclarative
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
    wrapProgram $out/bin/zoom \
      --prefix PATH : ${lib.makeBinPath [ stdenv.cc.cc.lib pulseaudio xdg-utils ]} \
      --set ZOOM_USE_WAYLAND 1 \
      --add-flags "--use-gl=angle --use-angle=opengl --enable-features=UseOzonePlatform --ozone-platform=wayland --no-sandbox --disable-setuid-sandbox --disable-gpu-sandbox --no-zygote --disable-seccomp-filter-sandbox"
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
