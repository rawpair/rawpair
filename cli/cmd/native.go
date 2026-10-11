package cmd

import (
	"os"
	"os/exec"

	"github.com/spf13/cobra"
)

func nativeCommand(args ...string) error {
	command := exec.Command("/usr/bin/python3", append([]string{"/usr/lib/rawpair/setup.py"}, args...)...)
	command.Stdin, command.Stdout, command.Stderr = os.Stdin, os.Stdout, os.Stderr
	return command.Run()
}

func init() {
	var config string
	setup := &cobra.Command{Use: "setup", Short: "Configure, resume or upgrade a native installation", Args: cobra.NoArgs,
		RunE: func(cmd *cobra.Command, args []string) error {
			if config != "" {
				return nativeCommand("setup", "--config", config)
			}
			return nativeCommand("setup")
		}}
	setup.Flags().StringVar(&config, "config", "", "Protected JSON configuration file for unattended setup")
	var jsonOutput bool
	doctor := &cobra.Command{Use: "doctor", Short: "Read-only diagnostics (run with sudo to inspect protected configuration)", Args: cobra.NoArgs,
		RunE: func(cmd *cobra.Command, args []string) error {
			if jsonOutput {
				return nativeCommand("doctor", "--json")
			}
			return nativeCommand("doctor")
		}}
	doctor.Flags().BoolVar(&jsonOutput, "json", false, "Emit structured diagnostics")
	workspace := &cobra.Command{Use: "workspace", Short: "Manage native workspace accounts"}
	workspace.AddCommand(&cobra.Command{Use: "add NAME", Short: "Provision an account and the next available network index", Args: cobra.ExactArgs(1),
		RunE: func(cmd *cobra.Command, args []string) error { return nativeCommand("workspace", "add", args[0]) }})
	user := &cobra.Command{Use: "user", Short: "Manage RawPair logins"}
	user.AddCommand(&cobra.Command{Use: "add", Short: "Securely prompt for a new login", Args: cobra.NoArgs,
		RunE: func(cmd *cobra.Command, args []string) error { return nativeCommand("user", "add") }})
	rootCmd.AddCommand(setup, doctor, workspace, user, &cobra.Command{Use: "migrate", Short: "Back up and migrate a configured installation; controls remain stopped", Args: cobra.NoArgs,
		RunE: func(cmd *cobra.Command, args []string) error { return nativeCommand("migrate") }})
}
