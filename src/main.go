package main

import (
	"fmt"
	"github.com/go-git/go-git/v5"
	"github.com/go-playground/webhooks/v6/github"
	"log"
	"net/http"
	"os"
	"os/exec"
)

func cloneRepository(repoURL string, dir string) error {
	// Clone options with authentication
	cloneOptions := &git.CloneOptions{
		URL:      repoURL,
		Progress: os.Stdout,
	}

	// Clone the repository
	fmt.Printf("Cloning repository into %s...\n", dir)
	_, err := git.PlainClone(dir, false, cloneOptions)
	if err != nil {
		return fmt.Errorf("failed to clone repository: %v", err)
	}

	fmt.Printf("\nRepository was cloned to %s\n", dir)
	return nil
}

func main() {
	// Set up webhook handler if no direct URL is provided
	webhookSecret := os.Getenv("WEBHOOK_SECRET")
	if webhookSecret == "" {
		log.Fatal("WEBHOOK_SECRET environment variable is not set")
	}

	hook, err := github.New(github.Options.Secret(webhookSecret))
	if err != nil {
		log.Fatal(err)
	}

	http.HandleFunc("/webhook", func(w http.ResponseWriter, r *http.Request) {
		log.Printf("Received webhook request from GitHub: %s", r.Method)
		payload, err := hook.Parse(r, github.IssuesEvent)

		if err != nil {
			http.Error(w, err.Error(), http.StatusBadRequest)
			return
		}

		switch payload.(type) {
		case github.IssuesPayload:
			issuePayload := payload.(github.IssuesPayload)

			// Only process newly created issues
			if issuePayload.Action != "opened" {
				return
			}

			// Check for "AI" tag
			hasAITag := false
			for _, label := range issuePayload.Issue.Labels {
				if label.Name == "AI" {
					hasAITag = true
					break
				}
			}

			if hasAITag {
				log.Printf("Processing issue #%d with AI tag from repository: %s",
					issuePayload.Issue.Number,
					issuePayload.Repository.CloneURL)

				// Clone the repository
				tempDir, err := os.MkdirTemp("", "git-clone-*")
				if err != nil {
					log.Printf("Error creating temp directory: %v", err)
					http.Error(w, "Internal server error", http.StatusInternalServerError)
					return
				}

				if err := cloneRepository(issuePayload.Repository.CloneURL, tempDir); err != nil {
					log.Printf("Error cloning repository: %v", err)
					http.Error(w, "Internal server error", http.StatusInternalServerError)
					return
				}

				// Get the issue body
				instructions := issuePayload.Issue.Body

				githubToken := os.Getenv("GITHUB_TOKEN")
				if githubToken == "" {
					log.Fatal("GITHUB_TOKEN environment variable is not set")
				}

				err = os.Chdir(tempDir)
				if err != nil {
					log.Printf("Error changing directory: %v", err)
					http.Error(w, "Internal server error", http.StatusInternalServerError)
					return
				}

				//Write instruction to file
				err = os.WriteFile(tempDir+"/instructions.txt", []byte(instructions), 0644)
				if err != nil {
					log.Printf("Error writing instructions to file: %v", err)
					http.Error(w, "Internal server error", http.StatusInternalServerError)
					return
				}

				gooseCommand := fmt.Sprintf("cd %s && goose run --with-extension 'GITHUB_PERSONAL_ACCESS_TOKEN=%s npx -y @modelcontextprotocol/server-github' --with-builtin 'developer' -i 'instructions.txt'", tempDir, githubToken)

				cmd := exec.Command("bash", "-c", gooseCommand)
				cmd.Dir = tempDir
				cmd.Stdout = os.Stdout
				cmd.Stderr = os.Stderr

				if err := cmd.Run(); err != nil {
					log.Printf("Error running Goose session: %v", err)
					http.Error(w, "Internal server error", http.StatusInternalServerError)
					return
				}

				// Ctrl+C the Goose session
				if err := cmd.Process.Signal(os.Interrupt); err != nil {
					log.Printf("Error sending Ctrl+C to Goose session: %v", err)
					http.Error(w, "Internal server error", http.StatusInternalServerError)
					return
				}

				// Clean up
				if err := os.RemoveAll(tempDir); err != nil {
					log.Printf("Warning: Failed to clean up temporary directory %s: %v", tempDir, err)
				}
			}
		}
	})

	port := os.Getenv("PORT")
	if port == "" {
		port = "3000"
	}

	log.Printf("Starting webhook server on port %s", port)
	log.Fatal(http.ListenAndServe(":"+port, nil))
}
