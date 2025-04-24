package cmd

import (
	"encoding/json"
	"fmt"
	"net/http"
	"os"
	"os/exec"
	"sort"
	"time"

	// "path/filepath"
	"runtime"

	"github.com/AlecAivazis/survey/v2"
	"github.com/spf13/cobra"
)

type dockerHubResponse struct {
	Results []struct {
		Name string `json:"name"`
	} `json:"results"`
	Next string `json:"next"`
}

func fetchRawPairImages() ([]string, error) {
	var images []string
	url := "https://hub.docker.com/v2/repositories/rawpair/?page_size=100"

	client := &http.Client{Timeout: 10 * time.Second}

	for url != "" {
		resp, err := client.Get(url)
		if err != nil {
			return nil, fmt.Errorf("failed to fetch from Docker Hub: %w", err)
		}
		defer resp.Body.Close()

		if resp.StatusCode != http.StatusOK {
			return nil, fmt.Errorf("unexpected status code: %d", resp.StatusCode)
		}

		var data dockerHubResponse
		if err := json.NewDecoder(resp.Body).Decode(&data); err != nil {
			return nil, fmt.Errorf("failed to decode response: %w", err)
		}

		for _, repo := range data.Results {
			images = append(images, repo.Name)
		}

		url = data.Next // if there's another page
	}

	sort.Strings(images)

	return images, nil
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

		imageNames, err := fetchRawPairImages()
		if err != nil {
			fmt.Println("Failed to fetch images:", err)
			return
		}

		var selectedStacks []string
		promptStacks := &survey.MultiSelect{
			Message:  "Select stacks to build:",
			Options:  imageNames,
			PageSize: 8,
		}
		survey.AskOne(promptStacks, &selectedStacks)

		fmt.Println("\nSelected options:")
		fmt.Println("Architecture:", arch)
		fmt.Println("Stacks:", selectedStacks)

		for _, name := range selectedStacks {
			fmt.Printf("📦 Pulling rawpair/%s:latest...\n", name)
			cmd := exec.Command("docker", "pull", fmt.Sprintf("rawpair/%s:latest", name))
			cmd.Stdout = os.Stdout
			cmd.Stderr = os.Stderr
			if err := cmd.Run(); err != nil {
				fmt.Printf("Failed to pull rawpair/%s: %v\n", name, err)
			}
		}
	},
}

func init() {
	rootCmd.AddCommand(quickStartCmd)
}
