package main

import (
	"testing"
)

func TestParseConfig(t *testing.T) {
	tt := []struct {
		config  string
		parsed  string
		privKey string
		err     error
	}{
		{
			config:  "",
			parsed:  "",
			privKey: "",
			err:     errInvalidConfig,
		},
		{
			config:  "[Interface]\nPrivateKey=foobar\n",
			parsed:  "[Interface]\nPrivateKey=foobar\n",
			privKey: "foobar",
			err:     nil,
		},
		{
			config:  "[Interface]\nPrivateKey=foobar\n\n[Peer]AllowedIPs=::1\n",
			parsed:  "[Interface]\nPrivateKey=foobar\n\n[Peer]AllowedIPs=::1\n",
			privKey: "foobar",
			err:     nil,
		},
		{
			config:  "# some helpful comment\n[Interface]\nAddress=::1\nPrivateKey=foobar\n",
			parsed:  "# some helpful comment\n[Interface]\nAddress=::1\nPrivateKey=foobar\n",
			privKey: "foobar",
			err:     nil,
		},
	}

	for _, tc := range tt {
		parsed, privKey, err := parseConfig(tc.config)
		if tc.err != err {
			t.Fatalf("wanted error: %v, got error: %v\n", tc.err, err)
		}
		if tc.parsed != parsed {
			t.Fatalf("wanted parsed:\n%v, got parsed:\n%v\n", tc.parsed, parsed)
		}
		if tc.privKey != privKey {
			t.Fatalf("wanted privKey: %v, got privKey: %v\n", tc.privKey, privKey)
		}
	}
}
