// wg-config-server serves up wireguard configs when a client is able to
// authenticate with their private key
package main

import (
	"bufio"
	"bytes"
	"errors"
	"flag"
	"fmt"
	"io"
	"io/fs"
	"log"
	"net/http"
	"os"
	"path/filepath"
	"strings"
)

var errInvalidConfig = errors.New("invalid config")

func noConfigsFound(w http.ResponseWriter) {
	w.WriteHeader(http.StatusBadRequest)
	fmt.Fprintln(w, "No configs found")
}

func handler(configs map[string]map[string]string) func(w http.ResponseWriter, r *http.Request) {
	return func(w http.ResponseWriter, r *http.Request) {
		path := strings.Split(strings.Trim(r.URL.Path, "/"), "/")
		if len(path) != 2 {
			w.WriteHeader(http.StatusNotFound)
			fmt.Fprint(w, "Not found")
			return
		}
		hostName := path[0]
		configName := path[1]

		_, privateKey, hasBasicAuth := r.BasicAuth()
		if !hasBasicAuth {
			w.Header().Set("WWW-Authenticate", "Basic realm=\"wireguard\"")
			w.WriteHeader(http.StatusUnauthorized)
			fmt.Fprintln(w, "Missing private key in basic auth")
			return
		}

		hostConfigs, ok := configs[hostName]
		if !ok {
			log.Println("No host found")
			noConfigsFound(w)
			return
		}

		config, ok := hostConfigs[configName]
		if !ok {
			log.Println("No config found")
			noConfigsFound(w)
			return
		}

		parsed, parsedPrivateKey, err := parseConfig(config)
		if err != nil {
			log.Println("Failed to parse config")
			noConfigsFound(w)
			return
		}

		if parsedPrivateKey != privateKey {
			log.Println("Private keys do not match")
			noConfigsFound(w)
			return
		}

		fmt.Fprintln(w, parsed)
	}
}

func parseConfig(config string) (string, string, error) {
	r := bufio.NewReader(strings.NewReader(config))

	var parsedConfig, parsedPrivateKey string

	var seenInterfaceSection, pastPrivateKey bool
	for {
		var lineToPush string

		line, err := r.ReadString('\n')
		if err != nil {
			if err == io.EOF {
				break
			} else {
				return "", "", err
			}
		}

		if !seenInterfaceSection && strings.HasPrefix(line, "[Interface]") {
			lineToPush = "[Interface]\n"
		} else if !pastPrivateKey && strings.HasPrefix(line, "PrivateKey") {
			if strings.HasPrefix(line, "PrivateKey=") {
				parsedPrivateKey = strings.TrimSpace(line[len("PrivateKey="):])
			} else if strings.HasPrefix(line, "PrivateKeyFile=") {
				privateKeyFile := strings.TrimSpace(line[len("PrivateKeyFile="):])
				data, err := os.ReadFile(privateKeyFile)
				if err != nil {
					return "", "", err
				}
				parsedPrivateKey = string(bytes.TrimSpace(data))
			}

			lineToPush = fmt.Sprintf("PrivateKey=%s\n", parsedPrivateKey)
			pastPrivateKey = true
		} else {
			lineToPush = line
		}

		parsedConfig += lineToPush
	}

	if parsedConfig == "" || parsedPrivateKey == "" {
		return "", "", errInvalidConfig
	}

	return parsedConfig, parsedPrivateKey, nil
}

func loadConfigs(start string, dir fs.FS) (map[string]map[string]string, error) {
	configs := make(map[string]map[string]string)

	root := "."
	fs.WalkDir(dir, root, func(path string, d fs.DirEntry, err error) error {
		if err != nil {
			return nil
		}

		if path == root {
			return nil
		}

		if d.IsDir() {
			return fs.SkipDir
		}

		ext := filepath.Ext(path)
		if ext != ".conf" {
			return nil
		}

		split := strings.Split(filepath.Base(path[:len(path)-len(ext)]), "-")
		if len(split) < 2 {
			return nil
		}

		hostName := split[0]
		configName := strings.Join(split[1:], "-")

		bytes, err := os.ReadFile(filepath.Join(start, path))
		if err != nil {
			return err
		}

		_, ok := configs[hostName]
		if !ok {
			configs[hostName] = make(map[string]string)
		}

		parsed, _, err := parseConfig(string(bytes))
		if err != nil {
			log.Printf("failed to parse config at %s, omitting this config\n", path)
			return nil
		}

		configs[hostName][configName] = parsed

		return nil
	})

	return configs, nil
}

func main() {
	addr := flag.String("addr", "[::1]:8080", "server bind address")
	confDir := flag.String("conf-dir", ".", "directory of wireguard configurations")
	flag.Parse()

	configs, err := loadConfigs(*confDir, os.DirFS(*confDir))
	if err != nil {
		log.Printf("error parsing configs: %v\n", err)
		configs = nil
	}

	if err := http.ListenAndServe(*addr, http.HandlerFunc(handler(configs))); err != nil {
		log.Fatal(err)
	}
}
