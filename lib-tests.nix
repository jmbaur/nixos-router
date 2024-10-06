{ lib, emptyFile }:
let
  inherit (import ./lib.nix { inherit lib; })
    hostHexetsFromMacAddress
    leftShift
    mkIpv6Address
    mkUlaNetwork
    networkMaskHextets
    parseIpv6Network
    power
    ;

  assertions = map ({ assertion, message }: lib.assertMsg assertion message) [
    {
      assertion = power 2 2 == 4;
      message = "pow(2, 2) == 4";
    }
    {
      assertion = leftShift 1 8 == 256;
      message = "1<<8 == 256";
    }
    {
      assertion =
        networkMaskHextets 64 == [
          65535
          65535
          65535
          65535
          0
          0
          0
          0
        ];
      message = "simple network mask";
    }
    {
      assertion =
        mkUlaNetwork [
          0
          0
          0
          0
          0
          0
          0
          0
        ] 64 == "fc00:0000:0000:0000:0000:0000:0000:0000/64";
      message = "simple ULA network";
    }
    {
      assertion =
        mkUlaNetwork [
          65535
          0
          0
          0
          0
          0
          0
          0
        ] 64 == "fdff:0000:0000:0000:0000:0000:0000:0000/64";
      message = "less simple ULA network";
    }
    {
      assertion =
        (parseIpv6Network "2001:db8::/48") == {
          hextets = [
            8193
            3512
            0
            0
            0
            0
            0
            0
          ];
          prefixLength = 48;
        };
      message = "parse simple IPv6 network";
    }
    {
      assertion =
        (parseIpv6Network "2001:db8:ffff::ffff/33") == {
          hextets = [
            8193
            3512
            32768
            0
            0
            0
            0
            0
          ];
          prefixLength = 33;
        };
      message = "parse IPv6 network with leftover bits in host portion";
    }
    {
      assertion =
        mkIpv6Address
          [
            8193
            3512
            0
            0
            0
            0
            0
            0
          ]
          [
            0
            0
            0
            0
            0
            0
            0
            1
          ] == "2001:0db8:0000:0000:0000:0000:0000:0001";
      message = "make simple IPv6 address";
    }
    {
      assertion =
        hostHexetsFromMacAddress "b9:20:42:35:6b:5f" == [
          0
          0
          0
          0
          47904
          17151
          65077
          27487
        ];
      message = "parse MAC address into host IPv6 hextets";
    }
  ];
in
builtins.deepSeq assertions emptyFile
