{
  perSystem =
    {
      pkgs,
      self',
      ...
    }:
    let
      gauche-bleeding = pkgs.gauche.overrideAttrs (old: {
        version = "0.9.16_pre3+20261016";
        src = pkgs.fetchurl {
          url = "https://practical-scheme.net/gauche/releases/0.9.16_pre3+20261016.tgz";
          hash = "sha256-ln74pwLbHl6mbEvHN70WfjpALRNnvbG2i9ftsYj1TWo=";
        };

        # Bleeding-edge tarballs don't need gaucheBootstrap and already contain generated files
        nativeBuildInputs = [
          pkgs.pkg-config
          pkgs.texinfo
        ];
        autoreconfPhase = null;
      });
    in
    {
      packages.gauche-bleeding = gauche-bleeding;

      make-shells.default.packages = [
        self'.packages.gauche-bleeding
      ];
    };
}
