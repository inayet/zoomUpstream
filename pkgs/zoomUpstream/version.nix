{ fetchurl }:
{
  version = "6.6.0.4410";
  src = fetchurl {
    url = "https://zoom.us/client/latest/zoom_amd64.deb";
    sha256 = "sha256-zkPYOTGIZBFVBv8JNQfNwiNui983Z2ab22CdNglGcs4=";
  };
}
