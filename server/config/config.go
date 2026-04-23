package config

import (
	"os"

	"gopkg.in/yaml.v3"
)

type TLSConfig struct {
	Enabled bool   `yaml:"enabled"`
	Cert    string `yaml:"cert"`
	Key     string `yaml:"key"`
}

type Config struct {
	Port  string    `yaml:"port"`
	Token string    `yaml:"token"`
	TLS   TLSConfig `yaml:"tls"`
}

func Load(path string) (*Config, error) {
	data, err := os.ReadFile(path)
	if err != nil {
		return nil, err
	}
	cfg := &Config{
		Port: "8888",
	}
	if err := yaml.Unmarshal(data, cfg); err != nil {
		return nil, err
	}
	return cfg, nil
}
