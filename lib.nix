let
  inherit (import <nixpkgs> { }) lib;

  hexChars = lib.stringToCharacters "0123456789abcdef";
  # base32Chars = lib.stringToCharacters "abcdefghijklmnopqrstuvwxyz234567";

  # Return an integer between 0 and 15 representing the hex digit
  fromHexDigit = c:
    (lib.findFirst (x: x.fst == c) c (lib.zipLists hexChars (lib.range 0 (lib.length hexChars - 1)))).snd;

  fromHex = s: lib.foldl (a: b: a * 16 + fromHexDigit b) 0 (lib.stringToCharacters (lib.toLower s));

  # Breakup into 2-byte integer chunks.
  bytes = hexstr:
    let
      len = lib.stringLength hexstr;
      paddedStr = lib.fixedWidthString (len + (lib.mod len 2)) "0" hexstr;
    in
    map (n: fromHex (builtins.substring (2 * n) 2 paddedStr))
      (lib.range 0 (((lib.stringLength paddedStr) / 2) - 1));

  toNetworkHexString = s: lib.toLower (lib.toHexString s);
in
{
  # Make an IPv6 address based on the network bits and the mac address of a
  # host. The network must be greater than or equal to a /64 IPv6 prefix size.
  #
  # Example: mkIpv6Address "2001:db8" "b9:20:42:35:6b:5f"
  #          => "2001:0db8:0000:0000:bb20:42ff:fe35:6b5f"
  mkIpv6Address = network: macAddress:
    let
      # Makes one half of an IPv6 hextet
      toOctetV6 = s: lib.fixedWidthString 2 "0" (toNetworkHexString s);

      splitNetwork = lib.splitString ":" network;
      paddedNetwork = splitNetwork ++ (builtins.genList (_: "0") (4 - (lib.length splitNetwork)));
      macNums = map fromHex (lib.splitString ":" macAddress);

      ff = fromHex "ff";
      fe = fromHex "fe";
    in
    lib.concatStringsSep ":" (
      (map (lib.fixedWidthString 4 "0") paddedNetwork)
      ++ map (lib.concatMapStrings toOctetV6) [
        [ (builtins.bitXor (builtins.elemAt macNums 0) 2) (builtins.elemAt macNums 1) ]
        [ (builtins.elemAt macNums 2) ff ]
        [ fe (builtins.elemAt macNums 3) ]
        [ (builtins.elemAt macNums 4) (builtins.elemAt macNums 5) ]
      ]
    );
}
