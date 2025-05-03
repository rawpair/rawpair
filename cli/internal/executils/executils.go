package executils

import (
	"fmt"
	"os"
	"os/exec"
	"strings"
)

func CheckInstalled(name string) bool {
	_, err := exec.LookPath(name)
	return err == nil
}

func GetPathToExecutable(name string) (string, error) {
	return exec.LookPath(name)
}

func RunCommandAndReturnOutput(cmd string, args ...string) (string, error) {
	command := exec.Command(cmd, args...)
	out, err := command.CombinedOutput()
	if err != nil {
		return "", err
	}
	return string(out), nil
}

func RunCommandString(cmdStr string) error {
	args := strings.Fields(cmdStr)
	if len(args) == 0 {
		return fmt.Errorf("empty command string")
	}

	cmd := exec.Command(args[0], args[1:]...)
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr

	return cmd.Run()
}
