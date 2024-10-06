{
  lib ? (import <nixpkgs> { }).lib,
}:
let
  inherit (builtins)
    bitAnd
    bitOr
    bitXor
    elemAt
    genList
    hashString
    head
    substring
    tail
    ;

  inherit (lib)
    concatMapStringsSep
    findFirst
    fixedWidthNumber
    flatten
    flip
    foldl
    length
    min
    mod
    optional
    range
    splitString
    stringToCharacters
    sublist
    toHexString
    toInt
    toLower
    zipLists
    zipListsWith
    ;

  power' =
    product: base: exp:
    if exp == 0 then product else power' (product * base) base (exp - 1);

  power = power' 1;

  leftShift = flip power' 2;

  hexChars = stringToCharacters "0123456789abcdef";

  # Return an integer between 0 and 15 representing the hex digit
  fromHexDigit =
    c: (findFirst (x: x.fst == c) c (zipLists hexChars (range 0 (length hexChars - 1)))).snd;

  fromHex = s: foldl (a: b: a * 16 + fromHexDigit b) 0 (stringToCharacters (toLower s));

  toNetworkHexString = num: toLower (toHexString num);

  toHextetString = hextetNum: fixedWidthNumber 4 (toNetworkHexString hextetNum);
in
rec {
  inherit leftShift power;

  generateHextets =
    value:
    let
      hash = hashString "sha256" value;
    in
    genList (x: fromHex (substring x 4 hash)) 8;

  # Parse an IPv6 network address in CIDR form.
  #
  # Example: parseIpv6Network "2001:db8::/32"
  #          => { hextets = [ 8193 3512 0 0 0 0 0 0 ]; prefixLength = 32; }
  parseIpv6Network =
    networkCidr:
    let
      split = splitString "/" networkCidr;

      prefixLength = toInt (elemAt split 1);

      unfilledHextets = map (splitString ":") (splitString "::" (elemAt split 0));

      numNeededHextets = foldl (sum: xs: sum + length xs) 0 unfilledHextets;

      unmodifiedHextets = flatten [
        (map fromHex (elemAt unfilledHextets 0))
        (genList (_: 0) numNeededHextets)
        (map fromHex (elemAt unfilledHextets 1))
      ];

      fullHextets = sublist 0 (prefixLength / 16) unmodifiedHextets;

      nextHextetBits = mod prefixLength 16;

      partialHextet = optional (nextHextetBits != 0) (
        bitAnd (elemAt unmodifiedHextets (length fullHextets)) (
          leftShift ((leftShift 1 nextHextetBits) - 1) (16 - nextHextetBits)
        )
      );

      hextets =
        fullHextets ++ partialHextet ++ genList (_: 0) (8 - (length fullHextets) - (length partialHextet));
    in
    {
      inherit prefixLength hextets;
    };

  # Make an IPv6 address based on the network and host portion of the address.
  #
  # Example: mkIpv6Address [ 8193 3512 0 0 0 0 0 0 ] [ 0 0 0 0 0 0 0 1 ]
  #          => "2001:0db8:0000:0000:0000:0000:0000:0001"
  mkIpv6Address =
    networkHextets: hostHextets:
    assert length networkHextets == 8;
    assert length hostHextets == 8;
    concatMapStringsSep ":" toHextetString (zipListsWith bitOr networkHextets hostHextets);

  # Generates the hextets of an IPv6 address with the last 64 bits populated
  # based on the host's MAC address.
  #
  # Example: hostHexetsFromMacAddress "b9:20:42:35:6b:5f"
  #          => [ 0 0 0 0 47904 17151 65077 27487 ]
  hostHexetsFromMacAddress =
    macAddress:
    let
      ff = fromHex "ff";
      fe = fromHex "fe";

      macNums = map fromHex (splitString ":" macAddress);

      mkHextet = upper: lower: bitOr (leftShift upper 8) lower;
    in
    assert length macNums == 6; # ensure the MAC address is the correct length
    (genList (_: 0) 4)
    ++ [
      (mkHextet (bitXor (elemAt macNums 0) 2) (elemAt macNums 1))
      (mkHextet (elemAt macNums 2) ff)
      (mkHextet fe (elemAt macNums 3))
      (mkHextet (elemAt macNums 4) (elemAt macNums 5))
    ];

  # Generate a list of hextets for a network address from a prefix length.
  #
  # Example: networkMaskHextets 64
  #          => [ 65535 65535 65535 65535 0 0 0 0 ]
  networkMaskHextets =
    let
      networkMaskHextets' =
        hextets: bits:
        let
          bits' = bits - 16;
        in
        if bits' < 0 then
          hextets ++ genList (_: 0) (8 - length hextets)
        else
          networkMaskHextets' (
            hextets
            ++ [
              ((leftShift 1 (min 16 bits)) - 1)
            ]
          ) bits';
    in
    networkMaskHextets' [ ];

  # A ULA address is any address in the fc00::/7 network.
  mkUlaNetwork =
    hextets: prefixLength:
    let
      firstHextet = fromHex "fc00";

      firstHextet' = (
        bitOr firstHextet (
          # take the last 9 bits of the first hextet
          bitAnd 511 (head hextets)
        )
      );

      hextets' = [ firstHextet' ] ++ (sublist 0 7 (tail hextets));

      address = mkIpv6Address (
        # This isn't entirely necessary, but makes the address look normal in
        # config files.
        zipListsWith bitAnd hextets' (networkMaskHextets prefixLength)
      ) (genList (_: 0) 8);
    in
    assert length hextets == 8;
    "${address}/${toString prefixLength}";
}
