package osutils

import (
	"fmt"
	"log"
	"os"
	"path/filepath"
	"strings"
)

func fileExists(path string) bool {
	_, err := os.Stat(path)
	return err == nil
}

func DetectDistro() (string, error) {
	data, err := os.ReadFile("/etc/os-release")
	if err != nil {
		return "", err
	}
	for _, line := range strings.Split(string(data), "\n") {
		if strings.HasPrefix(line, "ID=") {
			return strings.Trim(strings.SplitN(line, "=", 2)[1], "\""), nil
		}
	}
	return "", fmt.Errorf("could not detect distro")
}

func DetectShellRCFile() (string, error) {
	home, err := os.UserHomeDir()
	if err != nil {
		return "", fmt.Errorf("could not get home directory: %w", err)
	}

	shellEnv := os.Getenv("SHELL")

	shell := filepath.Base(shellEnv)

	log.Printf("Shell ENV: %q\n", shellEnv)

	if shell == "" || shell == "." || shell == "sh" {
		return GetPathToShellRCFile(home), nil
	}

	log.Printf("Detected shell: %q\n", shell)

	switch shell {
	case "bash":
		return filepath.Join(home, ".bashrc"), nil
	case "zsh":
		return filepath.Join(home, ".zshrc"), nil
	case "fish":
		return filepath.Join(home, ".config", "fish", "config.fish"), fmt.Errorf("detected fish shell, but fish is not supported yet")
	default:
		return GetPathToShellRCFile(home), nil
	}
}

func GetPathToShellRCFile(home string) string {
	if fileExists(filepath.Join(home, ".bashrc")) {
		return filepath.Join(home, ".bashrc")
	} else if fileExists(filepath.Join(home, ".zshrc")) {
		return filepath.Join(home, ".zshrc")
	} else if fileExists(filepath.Join(home, ".profile")) {
		return filepath.Join(home, ".profile")
	}

	return ""
}
