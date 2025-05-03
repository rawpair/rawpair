package versionutils

import (
	"fmt"
	"log"
	"regexp"
	"strings"

	"github.com/Masterminds/semver/v3"
	"github.com/rawpair/rawpair/cli/internal/executils"
)

func IsAtLeast(versionStr, minVersionStr string) bool {
	version, err := semver.NewVersion(versionStr)
	if err != nil {
		log.Fatalf("Invalid version: %s", err)
	}

	constraints, err := semver.NewConstraint(">=" + minVersionStr)
	if err != nil {
		log.Fatalf("Invalid constraint: %s", err)
		return false
	}

	return constraints.Check(version)
}

func ExtractSemver(text string) (string, error) {
	re := regexp.MustCompile(`v?(\d+\.\d+\.\d+)`)
	matches := re.FindStringSubmatch(text)
	if len(matches) < 2 {
		return "", fmt.Errorf("no semantic version found")
	}
	return matches[1], nil // stripped leading "v"
}

func GetErlangVersion() (string, error) {
	erlRawVersionOutput, err := executils.RunCommandAndReturnOutput("erl",
		"-eval",
		`{ok, Version} = file:read_file(filename:join([code:root_dir(), "releases", erlang:system_info(otp_release), "OTP_VERSION"])), io:fwrite(Version), halt().`,
		"-noshell")

	if err != nil {
		return "", err
	}

	return strings.TrimSpace(erlRawVersionOutput), nil
}

func GetElixirVersion() (string, error) {
	elixirRawVersionOutput, err := executils.RunCommandAndReturnOutput("elixir",
		"-e",
		"IO.puts(System.version())")

	if err != nil {
		return "", err
	}

	return ExtractSemver(strings.TrimSpace(elixirRawVersionOutput))
}

func GetAsdfVersion(pathToAsdf string) (string, error) {
	asdfRawVersionOutput, err := executils.RunCommandAndReturnOutput(pathToAsdf, "--version")

	if err != nil {
		return "", err
	}

	return ExtractSemver(strings.TrimSpace(asdfRawVersionOutput))
}
