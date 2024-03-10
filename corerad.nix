{ lib, buildGoModule, fetchFromGitHub, nixosTests }:

buildGoModule rec {
  pname = "corerad";
  version = "1.2.2";

  src = fetchFromGitHub {
    owner = "jmbaur";
    repo = "corerad";
    rev = "5545eaa680a4fd1f34d4e7667469a373c978edc7";
    hash = "sha256-UilbhdtmJjDJt1z2fkHuWfnvj2yWi7EQRZPWaQs6cZI=";
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
