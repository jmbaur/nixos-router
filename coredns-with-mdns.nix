{ coredns, writeShellApplication, git, lib }:
(coredns.overrideAttrs (old: {
  patches = [ ./coredns-with-mdns.patch ];
  vendorHash = lib.fakeSha256;
  preBuild = ''
    go generate ./...
  '' + (old.preBuild or "");
  passthru = old.passthru // {
    update = writeShellApplication {
      name = "update-coredns-with-mdns";
      runtimeInputs = [ old.passthru.go git ];
      text = ''
        orig_pwd=$(pwd)
        cd "$(mktemp -d)"
        git clone --depth=1 --branch=${old.src.rev} https://github.com/coredns/coredns
        cd coredns
        echo "mdns:github.com/openshift/coredns-mdns" >> plugin.cfg
        go get github.com/openshift/coredns-mdns
        git diff > "''${orig_pwd}/coredns-with-mdns.patch"
      '';
    };
  };
})).override {
  overrideModAttrs = _: { outputHash = lib.fakeHash; };
}
