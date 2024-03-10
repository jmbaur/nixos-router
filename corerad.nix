{ lib, buildGoModule, fetchFromGitHub, nixosTests }:

buildGoModule rec {
  pname = "corerad";
  version = "1.2.2";

  src = fetchFromGitHub {
    owner = "jmbaur";
    repo = "corerad";
    rev = "76bf06553757b0d7f51b3784fa3f3774343ba0d9";
    hash = "sha256-7DXir1zjrCzm7hz/kcImfOs5tT68Je9oorBWMNiJ3wo=";
  };

  vendorHash = "sha256-EXWRPDfeCuMhKyUalJ09SVfprb6ofigPJkgKfpOJX34=";

  # Since the tarball pulled from GitHub doesn't contain git tag information,
  # we fetch the expected tag's timestamp from a file in the root of the
  # repository.
  preBuild = ''
    buildFlagsArray=(
      -ldflags="
        -X github.com/mdlayher/corerad/internal/build.linkTimestamp=$(<.gittagtime)
        -X github.com/mdlayher/corerad/internal/build.linkVersion=v${version}
      "
    )
  '';

  passthru.tests = {
    inherit (nixosTests) corerad;
  };

  meta = with lib; {
    homepage = "https://github.com/mdlayher/corerad";
    description = "Extensible and observable IPv6 NDP RA daemon";
    license = licenses.asl20;
    maintainers = with maintainers; [ mdlayher ];
    platforms = platforms.linux;
    mainProgram = "corerad";
  };
}
