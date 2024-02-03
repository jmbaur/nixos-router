{ lib ? (import <nixpkgs> { }).lib }:
let
  bitShift = num: n:
    if n == 0
    then
      num
    else
      bitShift (num * 2) (n - 1);

  hexChars = lib.stringToCharacters "0123456789abcdef";

  # Return an integer between 0 and 15 representing the hex digit
  fromHexDigit = c:
    (lib.findFirst (x: x.fst == c) c (lib.zipLists hexChars (lib.range 0 (lib.length hexChars - 1)))).snd;

  fromHex = s: lib.foldl (a: b: a * 16 + fromHexDigit b) 0 (lib.stringToCharacters (lib.toLower s));

  toNetworkHexString = num: lib.toLower (lib.toHexString num);

  toHextetString = hextetNum: lib.fixedWidthString 4 "0" (toNetworkHexString hextetNum);
in
rec {
  inherit bitShift;

  # Parse an IPv6 network address in CIDR form.
  #
  # Example: parseIpv6Network "2001:db8::/64"
  #          => { network = [ 8193 3512 0 0 0 0 0 0 ]; prefixLength = 64; }
  parseIpv6Network = networkCidr:
    let
      split = lib.splitString "/" networkCidr;
      prefixLength = lib.toInt (lib.elemAt split 1);
      networkSplit = lib.filter
        (hextet: hextet != "") # filter out IPv6 shorthand syntax ("::")
        (lib.splitString ":" (lib.elemAt split 0));
    in
    assert lib.length split == 2; {
      inherit prefixLength;
      hextets = map fromHex networkSplit
        ++ builtins.genList (_: 0) (8 - lib.length networkSplit);
    };

  # Make an IPv6 address based on the network and host portion of the address.
  #
  # Example: mkIpv6Address [ 8193 3512 0 0 0 0 0 0 ] [ 0 0 0 0 0 0 0 1 ]
  #          => "2001:0db8:0000:0000:0000:0000:0000:0001"
  mkIpv6Address = networkHextets: hostHextets:
    assert lib.length networkHextets == 8;
    assert lib.length hostHextets == 8;
    lib.concatMapStringsSep ":" toHextetString
      (lib.zipListsWith lib.bitOr networkHextets hostHextets);

  # Generates the hextets of an IPv6 address with the last 64 bits populated
  # based on the host's MAC address.
  #
  # Example: hostHexetsFromMacAddress "b9:20:42:35:6b:5f"
  #          => [ 0 0 0 0 47904 17151 65077 27487 ]
  hostHexetsFromMacAddress = macAddress:
    let
      ff = fromHex "ff";
      fe = fromHex "fe";

      macNums = map fromHex (lib.splitString ":" macAddress);

      mkHextet = upper: lower: lib.bitOr (bitShift upper 8) lower;
    in
    assert lib.length macNums == 6; # ensure the MAC address is the correct length
    (builtins.genList (_: 0) 4) ++ [
      (mkHextet (builtins.bitXor (builtins.elemAt macNums 0) 2) (builtins.elemAt macNums 1))
      (mkHextet (builtins.elemAt macNums 2) ff)
      (mkHextet fe (builtins.elemAt macNums 3))
      (mkHextet (builtins.elemAt macNums 4) (builtins.elemAt macNums 5))
    ];
}
