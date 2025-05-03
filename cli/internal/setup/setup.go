package setup

import (
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"runtime"

	"github.com/rawpair/rawpair/cli/internal/executils"
)

func InstallASDF(shellRcFile string) (string, error) {
	home, _ := os.UserHomeDir()
	asdfDir := filepath.Join(home, ".asdf")
	if _, err := os.Stat(asdfDir); err == nil {
		return "", fmt.Errorf("asdf possibly already installed at %s", asdfDir)
	}

	version := "v0.16.7"
	tarURL := fmt.Sprintf("https://github.com/asdf-vm/asdf/releases/download/%s/asdf-%s-%s-%s.tar.gz", version, version, runtime.GOOS, runtime.GOARCH)
	tarPath := "/tmp/asdf.tar.gz"

	// Download tarball
	err := exec.Command("curl", "-L", "-o", tarPath, tarURL).Run()
	if err != nil {
		return "", fmt.Errorf("failed to download asdf: %w", err)
	}

	// Create .asdf/bin directory
	binDir := filepath.Join(asdfDir, "bin")
	if err := os.MkdirAll(binDir, 0755); err != nil {
		return "", fmt.Errorf("failed to create bin directory: %w", err)
	}

	// Extract to ~/.asdf/bin
	err = exec.Command("tar", "-xzf", tarPath, "-C", binDir).Run()
	if err != nil {
		return "", fmt.Errorf("failed to extract asdf: %w", err)
	}

	if shellRcFile != "" {
		f, err := os.OpenFile(shellRcFile, os.O_APPEND|os.O_WRONLY, 0644)
		if err != nil {
			return "", fmt.Errorf("failed to open shell RC file: %w", err)
		}

		defer f.Close()

		if _, err := f.WriteString("\n\nexport PATH=\"$HOME/.asdf/bin:${ASDF_DATA_DIR:-$HOME/.asdf}/shims:$PATH\"\n"); err != nil {
			return "", fmt.Errorf("failed to update shell RC file: %w", err)
		}

		fmt.Println("To use asdf right now, run:")
		fmt.Printf("   source %s\n", shellRcFile)
	}

	return filepath.Join(binDir, "asdf"), nil
}

func InstallErlang(pathToAsdf string) error {
	output, err := executils.RunCommandAndReturnOutput(pathToAsdf, "plugin", "add", "erlang")
	if err != nil {
		fmt.Println("Failed to add erlang plugin:", output)
		return err
	}

	fmt.Println("Installing Erlang 27.3.2, this may take several minutes...")
	output, err = executils.RunCommandAndReturnOutput(pathToAsdf, "install", "erlang", "27.3.2")
	if err != nil {
		fmt.Println("Failed to install erlang:", output)
		return err
	}

	output, err = executils.RunCommandAndReturnOutput(pathToAsdf, "set", "-u", "erlang", "27.3.2")
	if err != nil {
		fmt.Println("Failed to set erlang version:", output)
		return err
	}

	return nil
}

func InstallElixir(pathToAsdf string) error {
	output, err := executils.RunCommandAndReturnOutput(pathToAsdf, "plugin", "add", "elixir")
	if err != nil {
		fmt.Println("Failed to add elixir plugin:", output)
		return err
	}

	fmt.Println("Installing Elixir 1.18.3, this may take a minute...")
	output, err = executils.RunCommandAndReturnOutput(pathToAsdf, "install", "elixir", "1.18.3")
	if err != nil {
		fmt.Println("Failed to install elixir:", output)
		return err
	}

	output, err = executils.RunCommandAndReturnOutput(pathToAsdf, "set", "-u", "elixir", "1.18.3")
	if err != nil {
		fmt.Println("Failed to set elixir version:", output)
		return err
	}

	return nil
}
