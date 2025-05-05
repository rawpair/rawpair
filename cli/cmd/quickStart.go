// SPDX-License-Identifier: MPL-2.0

package cmd

import (
	"bytes"
	"crypto/rand"
	"encoding/hex"
	"encoding/json"
	"fmt"
	"net/http"
	"net/url"
	"os"
	"os/exec"
	"strings"
	"text/template"
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

const envTemplate = `
RAWPAIR_DOCKER_PLATFORM=linux/{{ .Arch }}
RAWPAIR_STACKS_VERSION=0.1.4

DATABASE_URL="{{ .Db.Url }}"
SECRET_KEY_BASE="{{ .SecretKeyBase }}"
CHECK_ORIGIN=//{{ .RawPair.Host }}:{{ .RawPair.Port }}

RAWPAIR_PROTOCOL={{ .RawPair.Protocol }}
RAWPAIR_HOST={{ .RawPair.Host }}
RAWPAIR_PORT={{ .RawPair.Port }}
RAWPAIR_BASE_PATH={{ .RawPair.BasePath }}

RAWPAIR_TERMINAL_HOST={{ .TerminalService.Host }}
RAWPAIR_TERMINAL_PORT={{ .TerminalService.Port }}

RAWPAIR_GRAFANA_HOST={{ .Grafana.Host }}
RAWPAIR_GRAFANA_PORT={{ .Grafana.Port }}

PHX_HOST={{ .RawPair.Host }}
PORT={{ .RawPair.Port }}
`

const dockerComposeYmlTemplate = `
networks:
  rawpair:
    name: rawpair

services:
{{ if .UseContainerizedPostgres }}
  db:
    networks:
      - rawpair
    image: postgres:15
    container_name: rawpair_db
    restart: always
    environment:
      POSTGRES_USER: postgres
      POSTGRES_PASSWORD: postgres
      POSTGRES_DB: rawpair_dev
    volumes:
      - pgdata:/var/lib/postgresql/data
    ports:
      - "5432:5432"
{{ end }}

  yjs:
    networks:
      - rawpair
    build:
      context: ./yjs-server
    container_name: rawpair_yjs
    environment:
      - HOST=0.0.0.0
      - PORT=1234
    ports:
      - "1234:1234"

  nginx:
    networks:
      - rawpair
    image: nginx:stable
    container_name: rawpair_nginx
    ports:
      - "{{ .TerminalService.Port }}:80"
    volumes:
      - ./nginx.conf:/etc/nginx/nginx.conf:ro

{{ if .UseGrafana }}
  loki:
    networks:
      - rawpair
    image: grafana/loki:2.9.4
    container_name: rawpair_loki
    ports:
      - "3100:3100"
    command: -config.file=/etc/loki/local-config.yaml
    restart: unless-stopped

  grafana:
    networks:
      - rawpair
    image: grafana/grafana-oss:10.3.1
    container_name: rawpair_grafana
    ports:
      - "3000:3000"
    depends_on:
      - loki
    environment:
      - GF_SECURITY_ADMIN_USER=admin
      - GF_SECURITY_ADMIN_PASSWORD=admin
      - GF_USERS_ALLOW_SIGN_UP=false
    volumes:
      - grafana_data:/var/lib/grafana
      - ./grafana/grafana.ini:/etc/grafana/grafana.ini:ro
      - ./grafana/provisioning/datasources:/etc/grafana/provisioning/datasources:ro
      - ./grafana/provisioning/dashboards:/etc/grafana/provisioning/dashboards:ro
      - ./grafana/dashboards:/var/lib/grafana/dashboards:ro
    restart: unless-stopped
{{ end }}
{{ if .UsePortainer }}
  portainer:
    image: portainer/portainer-ce:latest
    container_name: portainer
    restart: unless-stopped
    ports:
      - "9000:9000"
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock
      - portainer_data:/data
{{ end }}
{{ if or .UseContainerizedPostgres .UseGrafana .UsePortainer }}
volumes:
{{ if .UseContainerizedPostgres }}
  pgdata:
{{ end }}
{{ if .UseGrafana }}
  grafana_data:
{{ end }}
{{ if .UsePortainer }}
  portainer_data:
{{ end }}
{{ end }}
 `

func isDockerInstalled() bool {
	_, err := exec.LookPath("docker")
	return err == nil
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

type QuickStartConfig struct {
	Arch                     string
	SelectedTags             []string
	UseContainerizedPostgres bool
	UseGrafana               bool
	UsePortainer             bool
	SecretKeyBase            string

	RawPair struct {
		Host     string
		Protocol string
		Port     string
		BasePath string
	}

	TerminalService struct {
		Host string
		Port string
	}

	Grafana struct {
		Host string
		Port string
	}

	Db struct {
		Host     string
		Port     string
		Name     string
		User     string
		Password string
		Url      string
	}
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

func reviewAndConfirm(cfg *QuickStartConfig) {
	fmt.Println("\n🔍 Review your configuration:")
	fmt.Println("--------------------------------")
	fmt.Printf("\nArchitecture: %s\n", cfg.Arch)
	fmt.Printf("Selected Tags: %v\n", cfg.SelectedTags)

	fmt.Println("\n--------------------------------")

	if cfg.UseContainerizedPostgres {
		fmt.Println("\nUse Containerized Postgres: Yes")
		fmt.Printf("  DB Host: %s\n", cfg.Db.Host)
		fmt.Printf("  DB Port: %s\n", cfg.Db.Port)
		fmt.Printf("  DB Name: %s\n", cfg.Db.Name)
		fmt.Printf("  DB User: %s\n", cfg.Db.User)
		fmt.Printf("  DB Password: %s\n", cfg.Db.Password)
		fmt.Printf("  DB URL: %s\n", cfg.Db.Url)
	} else {
		fmt.Println("\nUse Containerized Postgres: No")
	}

	fmt.Println("\n--------------------------------")

	fmt.Println("\nRawPair Configuration:")
	fmt.Printf("  Host: %s\n", cfg.RawPair.Host)
	fmt.Printf("  Protocol: %s\n", cfg.RawPair.Protocol)
	fmt.Printf("  Port: %s\n", cfg.RawPair.Port)
	fmt.Printf("  BasePath: %s\n", cfg.RawPair.BasePath)

	fmt.Println("\n--------------------------------")

	fmt.Println("\nTerminal Service:")
	fmt.Printf("  Host: %s\n", cfg.TerminalService.Host)
	fmt.Printf("  Port: %s\n", cfg.TerminalService.Port)

	fmt.Println("\n--------------------------------")

	if cfg.UseGrafana {
		fmt.Println("\nUse Grafana: Yes")
		fmt.Printf("  Grafana Host: %s\n", cfg.Grafana.Host)
		fmt.Printf("  Grafana Port: %s\n", cfg.Grafana.Port)
	} else {
		fmt.Println("\nUse Grafana: No")
	}

	if cfg.UsePortainer {
		fmt.Println("\nUse Portainer: Yes")
	} else {
		fmt.Println("\nUse Portainer: No")
	}
}

func runTemplate(data QuickStartConfig, rawTmpl string) (string, error) {
	tmpl, err := template.New("env").Parse(rawTmpl)
	if err != nil {
		return "", err
	}
	var buf bytes.Buffer
	if err := tmpl.Execute(&buf, data); err != nil {
		return "", err
	}

	return buf.String(), nil
}

var quickStartCmd = &cobra.Command{
	Use:   "quickStart",
	Short: "Generates .env and docker-compose.yml files for RawPair",
	Run: func(cmd *cobra.Command, args []string) {
		cfg := QuickStartConfig{}

		randomBytes := make([]byte, 32)
		if _, err := rand.Read(randomBytes); err != nil {
			fmt.Println("Unable to generate a secret key base:", err)
			cfg.SecretKeyBase = "Generate your own by running `mix phx.gen.secret`"
		} else {
			cfg.SecretKeyBase = hex.EncodeToString(randomBytes)
		}

		defaultArch := runtime.GOARCH

		var selectedTagOptions []string

		labelMap := make(map[string]FlattenedTag)
		var displayOptions []string

		promptArch := &survey.Select{
			Message: "Choose your architecture:",
			Options: []string{"amd64", "arm64"},
			Default: defaultArch,
		}
		var err = survey.AskOne(promptArch, &cfg.Arch)
		if err != nil {
			fmt.Println("Aborted or failed:", err)
			return
		}

		flattenedTags, err := fetchRawPairStacks()
		if err != nil {
			fmt.Println("Failed to fetch images:", err)
			return
		}

		for _, tag := range flattenedTags {
			var supportsArch bool
			for _, platform := range tag.Platforms {
				if strings.HasSuffix(platform, cfg.Arch) {
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

		promptStacks := &survey.MultiSelect{
			Message:  "Select stacks to include:",
			Options:  displayOptions,
			PageSize: 8,
		}
		if err := survey.AskOne(promptStacks, &selectedTagOptions); err != nil {
			fmt.Println("Selection failed:", err)
			return
		}

		fmt.Println("\nSelected options:")
		fmt.Println("Architecture:", cfg.Arch)
		fmt.Println("Stacks:", selectedTagOptions)

		for _, label := range selectedTagOptions {
			if tag, ok := labelMap[label]; ok {
				cfg.SelectedTags = append(cfg.SelectedTags, tag.Id)
			}
		}

		if isDockerInstalled() {
			pullDockerImages := false

			err = survey.AskOne(&survey.Confirm{
				Message: "Pull docker images for selected stacks?",
				Default: false,
			}, &pullDockerImages)

			if err != nil {
				fmt.Println("Aborted or failed:", err)
				return
			}

			if pullDockerImages {
				for _, name := range cfg.SelectedTags {
					fmt.Printf("Pulling rawpair/%s...\n", name)
					cmd := exec.Command("docker", "pull", fmt.Sprintf("rawpair/%s", name))
					cmd.Stdout = os.Stdout
					cmd.Stderr = os.Stderr
					if err := cmd.Run(); err != nil {
						fmt.Printf("Failed to pull rawpair/%s: %v\n", name, err)
					}
				}
			}
		}

		err = survey.AskOne(&survey.Confirm{
			Message: "Use containerized Postgres? (Not recommended for production)",
			Default: false,
		}, &cfg.UseContainerizedPostgres)

		if err != nil {
			fmt.Println("Aborted or failed:", err)
			return
		}

		if !cfg.UseContainerizedPostgres {
			fmt.Println("Using non-containerized Postgres")
			fmt.Println("Please ensure that Postgres is running and accessible.")

			promptDbHost := &survey.Input{
				Message: "DB Host:",
				Default: "localhost",
			}
			err = survey.AskOne(promptDbHost, &cfg.Db.Host)
			if err != nil {
				fmt.Println("Aborted or failed:", err)
				return
			}

			promptDbPort := &survey.Input{
				Message: "DB Port:",
				Default: "5432",
			}
			err = survey.AskOne(promptDbPort, &cfg.Db.Port)
			if err != nil {
				fmt.Println("Aborted or failed:", err)
				return
			}

			promptDbUser := &survey.Input{
				Message: "DB User:",
				Default: "postgres",
			}
			err = survey.AskOne(promptDbUser, &cfg.Db.User)
			if err != nil {
				fmt.Println("Aborted or failed:", err)
				return
			}

			promptDbPassword := &survey.Input{
				Message: "DB Password:",
				Default: "postgres",
			}
			err = survey.AskOne(promptDbPassword, &cfg.Db.Password)
			if err != nil {
				fmt.Println("Aborted or failed:", err)
				return
			}

			promptDbName := &survey.Input{
				Message: "DB Name:",
				Default: "rawpair",
			}
			err = survey.AskOne(promptDbName, &cfg.Db.Name)
			if err != nil {
				fmt.Println("Aborted or failed:", err)
				return
			}

			cfg.Db.Url = fmt.Sprintf("postgres://%s:%s@%s:%s/%s", url.QueryEscape(cfg.Db.User), url.QueryEscape(cfg.Db.Password), cfg.Db.Host, cfg.Db.Port, cfg.Db.Name)
		} else {
			cfg.Db.Url = "postgres://postgres:postgres@localhost:5432/rawpair_dev"
		}

		if err != nil {
			fmt.Println("Aborted or failed:", err)
			return
		}

		promptRawPairProtocol := &survey.Select{
			Message: "RawPair Protocol:",
			Options: []string{"http", "https"},
			Default: "http",
		}

		err = survey.AskOne(promptRawPairProtocol, &cfg.RawPair.Protocol)
		if err != nil {
			fmt.Println("Aborted or failed:", err)
			return
		}

		promptRawPairHost := &survey.Input{
			Message: "RawPair Host:",
			Default: "localhost",
		}
		err = survey.AskOne(promptRawPairHost, &cfg.RawPair.Host)
		if err != nil {
			fmt.Println("Aborted or failed:", err)
			return
		}

		promptRawPairPort := &survey.Input{
			Message: "RawPair Port:",
			Default: "4000",
		}
		err = survey.AskOne(promptRawPairPort, &cfg.RawPair.Port)
		if err != nil {
			fmt.Println("Aborted or failed:", err)
			return
		}

		promptRawPairBasePath := &survey.Input{
			Message: "RawPair Base Path:",
			Default: "/",
		}
		err = survey.AskOne(promptRawPairBasePath, &cfg.RawPair.BasePath)
		if err != nil {
			fmt.Println("Aborted or failed:", err)
			return
		}

		promptTerminalServiceHost := &survey.Input{
			Message: "Terminal Service Host:",
			Default: "localhost",
		}
		err = survey.AskOne(promptTerminalServiceHost, &cfg.TerminalService.Host)
		if err != nil {
			fmt.Println("Aborted or failed:", err)
			return
		}

		promptTerminalServicePort := &survey.Input{
			Message: "Terminal Service Port:",
			Default: "8080",
		}
		err = survey.AskOne(promptTerminalServicePort, &cfg.TerminalService.Port)
		if err != nil {
			fmt.Println("Aborted or failed:", err)
			return
		}

		err = survey.AskOne(&survey.Confirm{
			Message: "Use Grafana?",
			Default: false,
		}, &cfg.UseGrafana)

		if err != nil {
			fmt.Println("Aborted or failed:", err)
			return
		}

		if cfg.UseGrafana {
			promptGrafanaHost := &survey.Input{
				Message: "Grafana Host:",
				Default: "localhost",
			}
			err = survey.AskOne(promptGrafanaHost, &cfg.Grafana.Host)
			if err != nil {
				fmt.Println("Aborted or failed:", err)
				return
			}

			promptGrafanaPort := &survey.Input{
				Message: "Grafana Port:",
				Default: "3000",
			}
			err = survey.AskOne(promptGrafanaPort, &cfg.Grafana.Port)
			if err != nil {
				fmt.Println("Aborted or failed:", err)
				return
			}
		}

		err = survey.AskOne(&survey.Confirm{
			Message: "Use Portainer?",
			Default: false,
		}, &cfg.UsePortainer)

		if err != nil {
			fmt.Println("Aborted or failed:", err)
			return
		}

		reviewAndConfirm(&cfg)

		confirm := false
		err = survey.AskOne(&survey.Confirm{
			Message: "Is everything correct?",
			Default: true,
		}, &confirm)

		if err != nil {
			fmt.Println("Aborted or failed:", err)
			return
		}

		if !confirm {
			fmt.Println("Aborting configuration.")
			return
		}

		envContents, err := runTemplate(cfg, envTemplate)

		if err != nil {
			fmt.Println("Failed generating .env file contents:", err)
			return
		}

		fmt.Println(".env file contents:")
		fmt.Println(envContents)

		writeEnvFile := false
		survey.AskOne(&survey.Confirm{
			Message: "Write .env file to disk in the current folder?",
			Default: true,
		}, &writeEnvFile)

		if writeEnvFile {
			if err := os.WriteFile(".env", []byte(envContents), 0644); err != nil {
				fmt.Println("Error writing .env file:", err)
			} else {
				fmt.Println("Successfully wrote .env file")
			}
		}

		dockerComposeYmlContents, err := runTemplate(cfg, dockerComposeYmlTemplate)

		if err != nil {
			fmt.Println("Failed generating docker-compose.yml file contents:", err)
			return
		}

		fmt.Println("docker-compose.yml file contents:")
		fmt.Println(dockerComposeYmlContents)

		writeComposeFile := false
		survey.AskOne(&survey.Confirm{
			Message: "Write docker-compose.yml file to disk?",
			Default: true,
		}, &writeComposeFile)

		if writeComposeFile {
			if err := os.WriteFile("docker-compose.yml", []byte(dockerComposeYmlContents), 0644); err != nil {
				fmt.Println("Error writing docker-compose.yml file:", err)
			} else {
				fmt.Println("Successfully wrote docker-compose.yml file")
			}
		}
	},
}

func init() {
	rootCmd.AddCommand(quickStartCmd)
}
