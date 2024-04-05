{ lib, emptyFile }:
let
  inherit (import ./lib.nix { inherit lib; })
    leftShift
    parseIpv6Network
    mkIpv6Address
    hostHexetsFromMacAddress
    ;

  assertions = map ({ assertion, message }: lib.assertMsg assertion message) [
    {
      assertion = leftShift 1 8 == 256;
      message = "1<<8 == 256";
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
