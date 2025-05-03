package executils

import "os/exec"

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
		return "", nil
	}
	return string(out), nil
}
