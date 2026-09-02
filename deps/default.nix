{ pkgs }:
let
  inherit (pkgs) lib;
  manifest = lib.importJSON ./cpmfile.json;
  fetchable = _: entry: !(entry.ci or false);
  version =
    entry: lib.replaceStrings [ "%NUMERIC_VERSION%" ] [ (entry.numeric_version or "") ] entry.version;
  artifact =
    entry:
    lib.replaceStrings
      [ "%NUMERIC_VERSION%" "%VERSION%" ]
      [
        (entry.numeric_version or "")
        (version entry)
      ]
      entry.artifact;
  url =
    entry:
    let
      base = "https://${entry.git_host or "github.com"}/${entry.repo}";
    in
    entry.url or (
      if entry ? artifact then
        "${base}/releases/download/${version entry}/${artifact entry}"
      else
        "${base}/archive/${version entry}.tar.gz"
    );
  dep = key: entry: {
    cacheDir = "${lib.toLower (entry.package or key)}/${version entry}";
    archive = pkgs.fetchurl {
      url = url entry;
      sha512 = entry.hash;
    };
    patches = map (name: ".patch/${key}/${name}") (entry.patches or [ ]);
  };
in
lib.mapAttrs dep (lib.filterAttrs fetchable manifest)
