// netdump will dump generated IP addresses for hosts or networks. For hosts,
// it chooses IPs within a subnet. For networks, it chooses subnets within
// larger subnets.
package main

import (
	"encoding/binary"
	"encoding/json"
	"errors"
	"flag"
	"fmt"
	"log"
	"math"
	"net"
	"net/netip"
)

const ipv6NetworkSize = 64

var (
	errIDTooLarge              = errors.New("network/host ID too large")
	errInvalidID               = errors.New("invalid host ID")
	errMaxStaticHostIDTooLarge = errors.New("max static host ID too large")
	errNetworkTooSmall         = errors.New("ipv6 network too small")

	makeIPv4AddressOverlay = mustMakeIPAddressOverlay(4)
	makeIPv6AddressOverlay = mustMakeIPAddressOverlay(16)
)

type hostDump struct {
	Ipv4        string  `json:"ipv4"`
	Ipv4Cidr    string  `json:"ipv4Cidr"`
	Ipv6Ula     string  `json:"ipv6Ula"`
	Ipv6UlaCidr string  `json:"ipv6UlaCidr"`
	Ipv6Gua     *string `json:"ipv6Gua"`
	Ipv6GuaCidr *string `json:"ipv6GuaCidr"`
}

func mustMakeIPAddressOverlay(size int) func(num uint64, prefix int) ([]byte, error) {
	if size != 4 && size != 16 {
		log.Panicf("invalid byte slice size %d", size)
	}

	return func(num uint64, prefix int) ([]byte, error) {
		bs := make([]byte, size)

		if num >= (1<<prefix)-1 {
			return bs, errIDTooLarge
		}

		var start int
		if size == 16 {
			// IPv6 byte layout requires `start` to be the closest multiple
			// of 2.
			start = int(math.Ceil(float64(prefix)/16)-1) * 2
		} else {
			start = int(math.Ceil(float64(prefix)/8)) - 1
		}

		tmp := []byte{} // len(tmp) is either 2 or 4
		switch {
		case num > (1<<32)-1:
			tmp = binary.BigEndian.AppendUint64(tmp, num)
		case num > (1<<16)-1:
			// pad with 0 so length is multiple of two
			if size == 16 {
				tmp = append(tmp, 0)
			}
			tmp = binary.BigEndian.AppendUint32(tmp, uint32(num))
		case num > (1<<8)-1:
			tmp = binary.BigEndian.AppendUint16(tmp, uint16(num))
		default:
			// pad with 0 so length is multiple of two
			if size == 16 {
				tmp = append(tmp, 0)
			}
			tmp = append(tmp, byte(num))
		}

		for i := 0; i < len(tmp); i++ {
			bs[start+i] = tmp[i]
		}

		return bs, nil
	}
}

// makeHostV6 returns the hosts ip address, ip address in CIDR form, and an
// error
func makeHostV6(prefixStr string, hostID int) (string, string, error) {
	prefix, err := netip.ParsePrefix(prefixStr)
	if err != nil {
		return "", "", err
	}
	bs := make([]byte, 4)
	binary.BigEndian.PutUint32(bs, uint32(hostID))

	ip := prefix.Addr().As16()
	ip[12] += bs[0]
	ip[13] += bs[1]
	ip[14] += bs[2]
	ip[15] += bs[3]

	ipaddr := netip.AddrFrom16(ip)

	return ipaddr.String(), netip.PrefixFrom(ipaddr, prefix.Bits()).String(), nil
}

func makeHostV4(prefixStr string, hostID int) (string, string, error) {
	v4Prefix, err := netip.ParsePrefix(prefixStr)
	if err != nil {
		return "", "", err
	}

	// 2 reserved IPs per network:
	// - network address
	// - broadcast multicast address
	availableIPv4Addresses := 1<<(32-v4Prefix.Bits()) - 2
	if hostID > availableIPv4Addresses {
		return "", "", errIDTooLarge
	}

	// For dual-stack, the host ID needs to fit within the 32 bits of IPv4, so
	// we hardcode the byte indexes for the IPv6 address slice.
	bs := make([]byte, 4)
	binary.BigEndian.PutUint32(bs, uint32(hostID))

	v4Array := v4Prefix.Addr().As4()
	v4Array[0] += bs[0]
	v4Array[1] += bs[1]
	v4Array[2] += bs[2]
	v4Array[3] += bs[3]

	ipv4 := netip.AddrFrom4(v4Array)

	return ipv4.String(), netip.PrefixFrom(ipv4, v4Prefix.Bits()).String(), nil
}

func ipv6AddrFromMac(prefixStr, macStr string) (string, string, error) {
	prefix, err := netip.ParsePrefix(prefixStr)
	if err != nil {
		return "", "", err
	}

	mac, err := net.ParseMAC(macStr)
	if err != nil {
		return "", "", fmt.Errorf("%w: %s", err, macStr)
	}

	mac[0] ^= 0b10

	ip := prefix.Addr().As16()
	ip[8] = 0xff
	ip[9] = 0xfe
	ip[10] = mac[0]
	ip[11] = mac[1]
	ip[12] = mac[2]
	ip[13] = mac[3]
	ip[14] = mac[4]
	ip[15] = mac[5]

	addr := netip.AddrFrom16(ip)
	return addr.String(), netip.PrefixFrom(addr, prefix.Bits()).String(), nil
}

func getHostDump(hostID, maxStaticHostID int, mac, guaPrefixStr, ulaPrefixStr, v4PrefixStr string) (*hostDump, error) {
	if hostID <= 0 || hostID > maxStaticHostID {
		return nil, errInvalidID
	}

	var err error

	var ula, ulaCidr string
	if mac != "" {
		ula, ulaCidr, err = ipv6AddrFromMac(ulaPrefixStr, mac)
		if err != nil {
			return nil, err
		}
	} else {
		ula, ulaCidr, err = makeHostV6(ulaPrefixStr, hostID)
		if err != nil {
			return nil, err
		}
	}

	var ipv6Gua, ipv6GuaCidr *string
	if guaPrefixStr != "" {
		gua, guaCidr, err := makeHostV6(guaPrefixStr, hostID)
		if err != nil {
			return nil, err
		}
		ipv6Gua = &gua
		ipv6GuaCidr = &guaCidr
	}

	ipv4, ipv4Cidr, err := makeHostV4(v4PrefixStr, hostID)
	if err != nil {
		return nil, err
	}

	return &hostDump{
		Ipv4:        ipv4,
		Ipv4Cidr:    ipv4Cidr,
		Ipv6Ula:     ula,
		Ipv6UlaCidr: ulaCidr,
		Ipv6Gua:     ipv6Gua,
		Ipv6GuaCidr: ipv6GuaCidr,
	}, nil
}

func getV6NetworkPrefix(prefixStr string, networkID int) (*netip.Prefix, error) {
	parentPrefix, err := netip.ParsePrefix(prefixStr)
	if err != nil {
		return nil, err
	}

	parentPrefix = parentPrefix.Masked()
	if parentPrefix.Bits() >= ipv6NetworkSize {
		return nil, errNetworkTooSmall
	}

	if networkID >= 1<<(128-ipv6NetworkSize-parentPrefix.Bits()) {
		return nil, errIDTooLarge
	}

	networkV6Overlay, err := makeIPv6AddressOverlay(uint64(networkID), ipv6NetworkSize)
	if err != nil {
		return nil, err
	}

	array := parentPrefix.Addr().As16()
	for i := 0; i < len(networkV6Overlay); i++ {
		array[i] += networkV6Overlay[i]
	}

	prefix := netip.PrefixFrom(netip.AddrFrom16(array), ipv6NetworkSize)
	return &prefix, nil
}

func getV4NetworkPrefix(prefixStr string, networkID int) (*netip.Prefix, error) {
	v4Prefix, err := netip.ParsePrefix(prefixStr)
	if err != nil {
		return nil, err
	}
	v4Prefix = v4Prefix.Masked()
	if v4Prefix.Bits() >= 24 {
		return nil, errNetworkTooSmall
	}
	if networkID >= 1<<(32-8-v4Prefix.Bits()) {
		return nil, errIDTooLarge
	}

	nextMultipleOf8 := int(math.Floor(float64(v4Prefix.Bits())/8))*8 + 8
	networkV4Overlay, err := makeIPv4AddressOverlay(uint64(networkID), nextMultipleOf8)
	if err != nil {
		return nil, err
	}

	v4Array := v4Prefix.Addr().As4()
	for i := 0; i < len(networkV4Overlay); i++ {
		v4Array[i] += networkV4Overlay[i]
	}

	networkV4Prefix := netip.PrefixFrom(netip.AddrFrom4(v4Array), nextMultipleOf8)
	return &networkV4Prefix, nil
}

func main() {
	id := flag.Int("id", -1, "The host ID")
	mac := flag.String("mac", "", "The MAC address of the host")
	maxStaticHostID := flag.Int("max-static-host-id", (1<<7)-1, "Maximum ID of static hosts in the network") // half of a /24 ipv4 network
	guaPrefix := flag.String("ipv6-gua-prefix", "", "IPv6 GUA network prefix")
	ulaPrefix := flag.String("ipv6-ula-prefix", "", "IPv6 ULA network prefix")
	v4Prefix := flag.String("ipv4-prefix", "", "IPv4 network prefix")
	flag.Parse()

	dump, err := getHostDump(*id, *maxStaticHostID, *mac, *guaPrefix, *ulaPrefix, *v4Prefix)
	if err != nil {
		log.Fatal(err)
	}

	data, err := json.Marshal(dump)
	if err != nil {
		log.Fatal(err)
	}

	if _, err := fmt.Printf("%s", data); err != nil {
		log.Fatal(err)
	}
}
