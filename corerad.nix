{ lib, buildGoModule, fetchFromGitHub, nixosTests }:

buildGoModule rec {
  pname = "corerad";
  version = "1.2.2";

  src = fetchFromGitHub {
    owner = "jmbaur";
    repo = "corerad";
    rev = "d67e179d9809c3402bee3cbd5f78d0fb3b3c7589";
    hash = "sha256-rmAvz2ANy+uYTnZNc7mOlMOr9JuOJsRukndD66DUmH0=";
  };

  vendorHash = "sha256-dsqFleXpL8yAcdigqxJsk/Sxvp9OTqbGK3xDEiHkM8A=";

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
