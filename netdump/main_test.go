package main

import (
	"reflect"
	"testing"
)

func TestGetHostDump(t *testing.T) {
	tt := []struct {
		hostID, maxStaticHostID                             int
		want                                                *hostDump
		name, mac, ipv6GuaPrefix, ipv6UlaPrefix, ipv4Prefix string
	}{
		{
			name:            "first host in network",
			hostID:          1,
			maxStaticHostID: (1 << 7) - 1,
			ipv6GuaPrefix:   "",
			ipv6UlaPrefix:   "fc00::/64",
			ipv4Prefix:      "192.168.0.0/24",
			mac:             "",
			want: &hostDump{
				Ipv4:        "192.168.0.1",
				Ipv4Cidr:    "192.168.0.1/24",
				Ipv6Ula:     "fc00::1",
				Ipv6UlaCidr: "fc00::1/64",
			},
		},
		{
			name:            "last host before DHCP pools",
			hostID:          126,
			maxStaticHostID: (1 << 7) - 1,
			ipv6GuaPrefix:   "",
			ipv6UlaPrefix:   "fc00::/64",
			ipv4Prefix:      "192.168.0.0/24",
			mac:             "00:00:00:00:00:00",
			want: &hostDump{
				Ipv4:        "192.168.0.126",
				Ipv4Cidr:    "192.168.0.126/24",
				Ipv6Ula:     "fc00::200:ff:fe00:0",
				Ipv6UlaCidr: "fc00::200:ff:fe00:0/64",
			},
		},
		{
			name:            "last host in large network",
			hostID:          (1 << 15) - 1,
			maxStaticHostID: (1 << 15) - 1,
			ipv6GuaPrefix:   "",
			ipv6UlaPrefix:   "fc00::/64",
			ipv4Prefix:      "10.0.0.0/8",
			mac:             "00:00:00:00:00:00",
			want: &hostDump{
				Ipv4:        "10.0.127.255",
				Ipv4Cidr:    "10.0.127.255/8",
				Ipv6Ula:     "fc00::200:ff:fe00:0",
				Ipv6UlaCidr: "fc00::200:ff:fe00:0/64",
			},
		},
	}

	for _, tc := range tt {
		got, err := getHostDump(tc.hostID, tc.maxStaticHostID, tc.mac, tc.ipv6GuaPrefix, tc.ipv6UlaPrefix, tc.ipv4Prefix)
		if err != nil {
			t.Fatal(err)
		}
		if !reflect.DeepEqual(*got, *tc.want) {
			t.Fatalf("test '%s': got %+v, want %+v", tc.name, got, tc.want)
		}
	}
}
