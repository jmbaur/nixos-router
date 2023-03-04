# Wireguard Config Server

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

## Usage

`curl -u _:<private_key> localhost:8080/<host>/<config_name>`
