// SPDX-License-Identifier: MPL-2.0

package cmd

import (
	"fmt"
	"log"
	"os"
	"os/exec"
	"path/filepath"
	"regexp"
	"runtime"
	"strings"

	"github.com/AlecAivazis/survey/v2"
	"github.com/Masterminds/semver/v3"
	"github.com/spf13/cobra"
)

func extractSemver(text string) (string, error) {
	re := regexp.MustCompile(`v?(\d+\.\d+\.\d+)`)
	matches := re.FindStringSubmatch(text)
	if len(matches) < 2 {
		return "", fmt.Errorf("no semantic version found")
	}
	return matches[1], nil // stripped leading "v"
}

func isAtLeast(versionStr, minVersionStr string) bool {
	version, err := semver.NewVersion(versionStr)
	if err != nil {
		log.Fatalf("Invalid version: %s", err)
	}

	constraints, err := semver.NewConstraint(">=" + minVersionStr)
	if err != nil {
		log.Fatalf("Invalid constraint: %s", err)
	}

	return constraints.Check(version)
}

func detectDistro() (string, error) {
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

func detectShellRCFile() (string, error) {
	home, err := os.UserHomeDir()
	if err != nil {
		return "", fmt.Errorf("could not get home directory: %w", err)
	}

	shell := filepath.Base(os.Getenv("SHELL"))

	if shell == "" || shell == "." || shell == "sh" {
		out, err := exec.Command("ps", "-p", fmt.Sprint(os.Getppid()), "-o", "comm=").Output()
		if err == nil {
			shell = strings.TrimSpace(string(out))
		}
	}

	switch shell {
	case "bash":
		return filepath.Join(home, ".bashrc"), nil
	case "zsh":
		return filepath.Join(home, ".zshrc"), nil
	case "fish":
		return filepath.Join(home, ".config", "fish", "config.fish"), fmt.Errorf("detected fish shell, but fish is not supported yet")
	default:
		// Fallback: just write to ~/.profile
		return filepath.Join(home, ".profile"), nil
	}
}

func checkInstalled(name string) bool {
	_, err := exec.LookPath(name)
	return err == nil
}

func runCommandAndReturnOutput(cmd string, args ...string) string {
	command := exec.Command(cmd, args...)
	out, err := command.CombinedOutput()
	if err != nil {
		return fmt.Sprintf("error: %s\noutput: %s", err, string(out))
	}
	return string(out)
}

func installASDF() error {
	home, _ := os.UserHomeDir()
	asdfDir := filepath.Join(home, ".asdf")
	if _, err := os.Stat(asdfDir); err == nil {
		return fmt.Errorf("asdf possibly already installed at %s", asdfDir)
	}

	version := "v0.16.7"
	tarURL := fmt.Sprintf("https://github.com/asdf-vm/asdf/releases/download/%s/asdf-%s-%s-%s.tar.gz", version, version, runtime.GOOS, runtime.GOARCH)
	tarPath := "/tmp/asdf.tar.gz"

	// Download tarball
	err := exec.Command("curl", "-L", "-o", tarPath, tarURL).Run()
	if err != nil {
		return fmt.Errorf("failed to download asdf: %w", err)
	}

	// Create .asdf/bin directory
	binDir := filepath.Join(asdfDir, "bin")
	if err := os.MkdirAll(binDir, 0755); err != nil {
		return fmt.Errorf("failed to create bin directory: %w", err)
	}

	// Extract to ~/.asdf/bin
	err = exec.Command("tar", "-xzf", tarPath, "-C", binDir).Run()
	if err != nil {
		return fmt.Errorf("failed to extract asdf: %w", err)
	}

	// Add sourcing lines to shell RC file
	shellRcFile, err := detectShellRCFile()
	if err != nil {
		return fmt.Errorf("failed to detect shell RC file: %w", err)
	}

	f, err := os.OpenFile(shellRcFile, os.O_APPEND|os.O_WRONLY, 0644)
	if err != nil {
		return fmt.Errorf("failed to open shell RC file: %w", err)
	}

	defer f.Close()

	if _, err := f.WriteString("\n\nexport PATH=\"$HOME/.asdf/bin:${ASDF_DATA_DIR:-$HOME/.asdf}/shims:$PATH\"\n"); err != nil {
		return fmt.Errorf("failed to update shell RC file: %w", err)
	}

	fmt.Println("To use asdf right now, run:")
	fmt.Printf("   source %s\n", shellRcFile)

	return nil
}

var depCommands = map[string][]string{
	"ubuntu": {
		"apt-get update",
		"apt-get install -y curl git autoconf build-essential libssl-dev libncurses-dev libwxgtk3.0-gtk3-dev libgl1-mesa-dev libglu1-mesa-dev libpng-dev libssh-dev unixodbc-dev",
	},
	"debian": {
		"apt-get update",
		"apt-get install -y curl git autoconf build-essential libssl-dev libncurses-dev libwxgtk3.0-gtk3-dev libgl1-mesa-dev libglu1-mesa-dev libpng-dev libssh-dev unixodbc-dev",
	},
	"fedora": {
		"dnf install -y curl git make automake gcc gcc-c++ kernel-devel openssl-devel ncurses-devel wxGTK3-devel mesa-libGL-devel mesa-libGLU-devel libpng-devel libssh-devel unixODBC-devel",
	},
	"arch": {
		"pacman -Sy --noconfirm curl git base-devel openssl ncurses wxgtk3 mesa glu libpng libssh unixodbc",
	},
}

var ensureDepsCmd = &cobra.Command{
	Use:   "ensureDeps",
	Short: "Install build dependencies required by Erlang and Elixir asdf plugins",
	Long: `Installs system packages required to build Erlang and Elixir via asdf plugins.

This command detects your Linux distribution and outputs
the appropriate commands to install necessary libraries and development tools.

Supports most common Linux distributions: Ubuntu, Debian, Fedora, Arch.
`,
	Run: func(cmd *cobra.Command, args []string) {

		fmt.Println("Proceeding with asdf, Erlang, and Elixir detection...")

		hasASDF := checkInstalled("asdf")
		hasErlang := checkInstalled("erl")
		hasElixir := checkInstalled("elixir")

		if hasErlang && hasElixir {
			erlangVersion := strings.TrimSpace(runCommandAndReturnOutput("erl",
				"-eval",
				`{ok, Version} = file:read_file(filename:join([code:root_dir(), "releases", erlang:system_info(otp_release), "OTP_VERSION"])), io:fwrite(Version), halt().`,
				"-noshell"))
			elixirVersion := strings.TrimSpace(runCommandAndReturnOutput("elixir",
				"-e",
				"IO.puts(System.version())"))

			meetsDeps := true

			if !isAtLeast(erlangVersion, "27.0.0") {
				fmt.Println("Erlang version is less than 27.0.0, please update.")
				meetsDeps = false
			}

			if !isAtLeast(elixirVersion, "1.18.0") {
				fmt.Println("Elixir version is less than 1.18.0, please update.")
				meetsDeps = false
			}

			if !meetsDeps {
				fmt.Println("Please ensure the minimum versions of Erlang and Elixir are installed.")
			} else {
				fmt.Println("Erlang and Elixir versions are up to date.")
			}

		} else {
			fmt.Println("Erlang, and Elixir are not installed.")

			distro, err := detectDistro()
			if err != nil {
				log.Fatal(err)
			}
			cmds, ok := depCommands[distro]
			if !ok {
				fmt.Println("Unrecognized distro, unable to determine the dependencies needed to build Erlang.")
				return
			} else {
				fmt.Println("Ensure the following dependencies are satisfied/installed:")
				for _, c := range cmds {
					fmt.Println("  ", c)
				}
			}

			if !hasASDF {
				fmt.Println("asdf is not installed.")

				proceed := false

				err := survey.AskOne(&survey.Confirm{
					Message: "Install asdf?",
					Default: true,
				}, &proceed)

				if err != nil {
					fmt.Println("Aborted or failed:", err)
					return
				}

				if !proceed {
					fmt.Println("Aborted.")
					return
				}

				err = installASDF()

				if err != nil {
					fmt.Println("asdf installation failed:", err)
					return
				}
				fmt.Println("asdf installed successfully.")
			} else {
				fmt.Println("Detected asdf, checking version...")

				rawAsdfVersion := runCommandAndReturnOutput("asdf", "--version")
				asdfVersion, err := extractSemver(rawAsdfVersion)

				if err != nil {
					fmt.Println("Could not reliably detect asdf version.")
					fmt.Println("asdf version:", rawAsdfVersion)
					return
				}

				if !isAtLeast(asdfVersion, "0.16.0") {
					fmt.Println("asdf version is less than 0.16.0, please update.")
					return
				}

				if !hasErlang {
					fmt.Println("Need to run the following commands to install Erlang:")
					fmt.Println("asdf plugin add erlang")
					fmt.Println("asdf install erlang 27.3.2")
					fmt.Println("asdf set -u erlang 27.3.2")

					proceed := false

					err := survey.AskOne(&survey.Confirm{
						Message: "Run commands now?",
						Default: true,
					}, &proceed)

					if err != nil {
						fmt.Println("Aborted or failed:", err)
						return
					}

					if proceed {
						output := runCommandAndReturnOutput("asdf", "plugin", "add", "erlang")
						if strings.Contains(output, "error") {
							fmt.Println("Failed to add erlang plugin:", output)
							return
						}

						fmt.Println("Installing Erlang 27.3.2, this may take several minutes...")
						output = runCommandAndReturnOutput("asdf", "install", "erlang", "27.3.2")
						if strings.Contains(output, "error") {
							fmt.Println("Failed to install erlang:", output)
							return
						}

						output = runCommandAndReturnOutput("asdf", "set", "-u", "erlang", "27.3.2")
						if strings.Contains(output, "error") {
							fmt.Println("Failed to set erlang version:", output)
							return
						}
						fmt.Println("Erlang installed successfully!")
					}
				}

				if !hasElixir {
					fmt.Println("Need to run the following commands to install Elixir:")
					fmt.Println("asdf plugin add elixir")
					fmt.Println("asdf install elixir 1.18.3")
					fmt.Println("asdf set -u elixir 1.18.3")

					proceed := false

					err := survey.AskOne(&survey.Confirm{
						Message: "Run commands now?",
						Default: true,
					}, &proceed)

					if err != nil {
						fmt.Println("Aborted or failed:", err)
						return
					}

					if proceed {
						fmt.Println("Running commands. This may take a while...")
						output := runCommandAndReturnOutput("asdf", "plugin", "add", "elixir")
						if strings.Contains(output, "error") {
							fmt.Println("Failed to add elixir plugin:", output)
							return
						}

						fmt.Println("Installing Elixir 1.18.3, this may take a few minutes...")
						output = runCommandAndReturnOutput("asdf", "install", "elixir", "1.18.3")
						if strings.Contains(output, "error") {
							fmt.Println("Failed to install elixir:", output)
							return
						}

						output = runCommandAndReturnOutput("asdf", "set", "-u", "elixir", "1.18.3")
						if strings.Contains(output, "error") {
							fmt.Println("Failed to set elixir version:", output)
							return
						}
						fmt.Println("Elixir installed successfully!")
					}
				}
			}
		}
	},
}

func init() {
	rootCmd.AddCommand(ensureDepsCmd)

	// Here you will define your flags and configuration settings.

	// Cobra supports Persistent Flags which will work for this command
	// and all subcommands, e.g.:
	// ensureDepsCmd.PersistentFlags().String("foo", "", "A help for foo")

	// Cobra supports local flags which will only run when this command
	// is called directly, e.g.:
	// ensureDepsCmd.Flags().BoolP("toggle", "t", false, "Help message for toggle")
}
