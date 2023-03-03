# wireguard config server

Expects to be called with a config directory of the following structure:

```console
$ tree ./conf-dir

./conf-dir/
├── host1-full.conf
├── host1-split.conf
├── host2-custom.conf
└── host2-full.conf
```

where each file is a wireguard config of the name
`"${hostname}-${configname}.conf"`.
