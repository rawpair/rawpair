// SPDX-License-Identifier: MPL-2.0

package cmd

import (
	"fmt"

	executils "github.com/rawpair/rawpair/cli/internal/executils"
	osutils "github.com/rawpair/rawpair/cli/internal/osutils"
	setup "github.com/rawpair/rawpair/cli/internal/setup"
	userflow "github.com/rawpair/rawpair/cli/internal/userflow"
	versionutils "github.com/rawpair/rawpair/cli/internal/versionutils"

	"github.com/spf13/cobra"
)

const (
	minErlangVersion         = "27.0.0"
	minElixirVersion         = "1.18.0"
	minAsdfVersion           = "0.16.0"
	asdfVersionToBeInstalled = "0.16.7"
)

var installDeps bool
var nonInteractive bool

var depCommands = map[string][]string{
	"ubuntu": {
		"apt-get update",
		"apt-get install -y curl git autoconf build-essential libssl-dev libncurses-dev libwxgtk3.2-dev libgl1-mesa-dev libglu1-mesa-dev libpng-dev libssh-dev unixodbc-dev",
	},
	"debian": {
		"apt-get update",
		"apt-get install -y curl git autoconf build-essential libssl-dev libncurses-dev libwxgtk3.2-dev libgl1-mesa-dev libglu1-mesa-dev libpng-dev libssh-dev unixodbc-dev",
	},
	"fedora": {
		"dnf install -y awk unzip curl git make automake gcc gcc-c++ kernel-devel openssl-devel ncurses-devel wxGTK-devel mesa-libGL-devel mesa-libGLU-devel libpng-devel libssh-devel unixODBC-devel",
	},
	"arch": {
		"pacman -Sy --noconfirm curl git base-devel openssl ncurses wxgtk3 mesa glu libpng libssh unixodbc unzip",
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

		pathToAsdf, err := setup.GetPathToASDF()

		if err != nil {
			fmt.Println("Error checking for asdf installation:", err)
			return
		}

		hasErlang := executils.CheckInstalled("erl")
		hasElixir := executils.CheckInstalled("elixir")
		hasASDF := pathToAsdf != ""

		var shellRcFile = ""

		if hasErlang && hasElixir {
			meetsDeps := true

			erlangVersion, err := versionutils.GetErlangVersion()
			if err != nil {
				fmt.Printf("Could not reliably detect Erlang version. Please ensure you have v%s or greater installed.\n", minErlangVersion)
				return
			}

			if !versionutils.IsAtLeast(erlangVersion, minErlangVersion) {
				fmt.Printf("Erlang version is less than %s, please update.\n", minErlangVersion)
				meetsDeps = false
			}

			elixirVersion, err := versionutils.GetElixirVersion()

			if err != nil {
				fmt.Printf("Could not reliably detect Elixir version. Please run `elixir --version` manually and ensure you have v%s or greater installed.\n", minElixirVersion)
				return
			}

			if !versionutils.IsAtLeast(elixirVersion, minElixirVersion) {
				fmt.Printf("Elixir version is less than %s, please update.\n", minElixirVersion)
				meetsDeps = false
			}

			if !meetsDeps {
				fmt.Println("Please ensure the minimum versions of Erlang and Elixir are installed.")
			} else {
				fmt.Println("Erlang and Elixir versions are up to date.")
			}
		} else {
			distro, err := osutils.DetectDistro()
			if err != nil {
				fmt.Println("Could not detect Linux distribution:", err)
				return
			}

			cmds, ok := depCommands[distro]
			if !ok {
				fmt.Println("Unrecognized distro, unable to determine the dependencies needed to build Erlang.")
				return
			}

			if installDeps {
				fmt.Println("Attempting to install dependencies...")
				for _, c := range cmds {
					fmt.Println("Running:", c)
					err := executils.RunCommandString(c)
					if err != nil {
						fmt.Println("Error running command:", c, err)
						return
					}
					fmt.Println("Command completed successfully.")
				}
				fmt.Println("Dependencies installed successfully.")
			} else {
				fmt.Println("Ensure the following dependencies are satisfied/installed:")
				for _, c := range cmds {
					fmt.Println("  ", c)
				}

				proceed := userflow.AskToProceedOrAuto("Proceed with asdf detection?", nonInteractive)

				if !proceed {
					fmt.Println("Aborted.")
					return
				}
			}

			if !hasASDF {
				fmt.Println("asdf is not installed.")

				proceed := userflow.AskToProceedOrAuto("asdf is not installed. Would you like to install it?", nonInteractive)

				if !proceed {
					fmt.Println("Aborted.")
					return
				}

				shellRcFile, _ = osutils.DetectShellRCFile()

				pathToAsdf, err = setup.InstallASDF(shellRcFile, asdfVersionToBeInstalled)

				if err != nil {
					fmt.Println("asdf installation failed:", err)
					return
				}
				fmt.Println("asdf installed successfully.")
			}

			fmt.Println("Detected asdf, checking version...")

			asdfVersion, err := versionutils.GetAsdfVersion(pathToAsdf)

			if err != nil {
				fmt.Println("Could not reliably detect asdf version.")
				return
			}

			if !versionutils.IsAtLeast(asdfVersion, minAsdfVersion) {
				fmt.Printf("asdf version is less than %s, please update.\n", minAsdfVersion)
				return
			}

			if !hasErlang {
				proceed := userflow.AskToProceedOrAuto("Erlang is not installed. Would you like to install it?", nonInteractive)

				if proceed {
					err := setup.InstallErlang(pathToAsdf)

					if err != nil {
						fmt.Println("Erlang installation failed:", err)
						return
					}

					fmt.Println("Erlang installed successfully!")
				} else {
					fmt.Println("Aborted.")
					return
				}
			}

			if !hasElixir {
				proceed := userflow.AskToProceedOrAuto("Elixir is not installed. Would you like to install it?", nonInteractive)

				if proceed {
					err := setup.InstallElixir(pathToAsdf)

					if err != nil {
						fmt.Println("Elixir installation failed:", err)
						return
					}

					fmt.Println("Elixir installed successfully!")
				} else {
					fmt.Println("Aborted.")
					return
				}
			}

			if !executils.CheckInstalled("erl") && !executils.CheckInstalled("elixir") && !executils.CheckInstalled("asdf") {
				fmt.Println("asdf, Erlang, and Elixir were likely correctly installed but are not in your PATH.")

				if shellRcFile != "" {
					fmt.Println("Please restart your terminal.")
				} else {
					fmt.Println("Could not detect your shell RC file. Please manually add the following line to your shell RC file then either source it or start a new terminal.")
					fmt.Println("export PATH=\"$HOME/.asdf/bin:${ASDF_DATA_DIR:-$HOME/.asdf}/shims:$PATH\"")
				}
			}
		}
	},
}

func init() {
	rootCmd.AddCommand(ensureDepsCmd)

	ensureDepsCmd.Flags().BoolVar(&installDeps, "install-deps", false, "Attempts to install dependencies automatically")
	ensureDepsCmd.Flags().BoolVar(&nonInteractive, "non-interactive", false, "Run without prompting for confirmation")
}
