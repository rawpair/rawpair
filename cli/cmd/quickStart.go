package cmd

import (
	"encoding/json"
	"fmt"
	"net/http"
	"os"
	"os/exec"
	"strings"
	"time"

	// "path/filepath"
	"runtime"

	"github.com/AlecAivazis/survey/v2"
	"github.com/spf13/cobra"
)

type StackTag struct {
	Id        string   `json:"id"`
	Name      string   `json:"name"`
	Base      string   `json:"base"`
	Platforms []string `json:"platforms"`
}

type StackDescriptor struct {
	Name string     `json:"name"`
	Tags []StackTag `json:"tags"`
}

type StackDescriptorList []StackDescriptor

type FlattenedTag struct {
	StackName string
	Id        string
	Name      string
	Base      string
	Platforms []string
}

func FlattenStacks(stacks []StackDescriptor) []FlattenedTag {
	var flat []FlattenedTag
	for _, stack := range stacks {
		for _, tag := range stack.Tags {
			flat = append(flat, FlattenedTag{
				StackName: stack.Name,
				Id:        tag.Id,
				Name:      tag.Name,
				Base:      tag.Base,
				Platforms: tag.Platforms,
			})
		}
	}
	return flat
}

func fetchRawPairStacks() ([]FlattenedTag, error) {
	url := "https://raw.githubusercontent.com/rawpair/stacks/refs/heads/main/stacks/stacks.json"

	client := &http.Client{Timeout: 10 * time.Second}

	resp, err := client.Get(url)
	if err != nil {
		return nil, fmt.Errorf("failed to fetch from GitHub: %w", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		return nil, fmt.Errorf("unexpected status code: %d", resp.StatusCode)
	}

	var data StackDescriptorList
	if err := json.NewDecoder(resp.Body).Decode(&data); err != nil {
		return nil, fmt.Errorf("failed to decode response: %w", err)
	}

	var flattenedStacks = FlattenStacks(data)

	return flattenedStacks, nil
}

var quickStartCmd = &cobra.Command{
	Use:   "quickStart",
	Short: "Interactively choose arch and stacks to build",
	Run: func(cmd *cobra.Command, args []string) {
		// Detect architecture
		defaultArch := runtime.GOARCH
		var arch string
		promptArch := &survey.Select{
			Message: "Choose your architecture:",
			Options: []string{"amd64", "arm64"},
			Default: defaultArch,
		}
		err := survey.AskOne(promptArch, &arch)
		if err != nil {
			fmt.Println("Aborted or failed:", err)
			return
		}

		flattenedTags, err := fetchRawPairStacks()
		if err != nil {
			fmt.Println("Failed to fetch images:", err)
			return
		}

		labelMap := make(map[string]FlattenedTag)
		var displayOptions []string
		for _, tag := range flattenedTags {
			var supportsArch bool
			for _, platform := range tag.Platforms {
				if strings.HasSuffix(platform, arch) {
					supportsArch = true
					break
				}
			}
			if !supportsArch {
				continue // skip this tag
			}

			label := fmt.Sprintf("%s - %s - [%s]", tag.StackName, tag.Id, strings.Join(tag.Platforms, ","))
			displayOptions = append(displayOptions, label)
			labelMap[label] = tag
		}

		var selectedTagOptions []string
		var selectedTags []FlattenedTag
		promptStacks := &survey.MultiSelect{
			Message:  "Select stacks to build:",
			Options:  displayOptions,
			PageSize: 8,
		}
		if err := survey.AskOne(promptStacks, &selectedTagOptions); err != nil {
			fmt.Println("Selection failed:", err)
			return
		}

		fmt.Println("\nSelected options:")
		fmt.Println("Architecture:", arch)
		fmt.Println("Stacks:", selectedTagOptions)

		for _, name := range selectedTagOptions {
			fmt.Printf("📦 Pulling rawpair/%s:latest...\n", name)
			cmd := exec.Command("docker", "pull", fmt.Sprintf("rawpair/%s:latest", name))
			cmd.Stdout = os.Stdout
			cmd.Stderr = os.Stderr
			if err := cmd.Run(); err != nil {
				fmt.Printf("Failed to pull rawpair/%s: %v\n", name, err)
			}
		}

		for _, label := range selectedTagOptions {
			if tag, ok := labelMap[label]; ok {
				selectedTags = append(selectedTags, tag)
			}
		}
	},
}

func init() {
	rootCmd.AddCommand(quickStartCmd)
}
