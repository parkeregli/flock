package main

import (
	"fmt"
	"github.com/go-git/go-git/v5"
	github_http "github.com/go-git/go-git/v5/plumbing/transport/http"
	"github.com/go-playground/webhooks/v6/github"
	"log"
	"net/http"
	"os"
)

func cloneRepository(repoURL string) error {
	// Create a temporary directory
	tempDir, err := os.MkdirTemp("", "git-clone-*")
	if err != nil {
		return fmt.Errorf("failed to create temporary directory: %v", err)
	}

	// Ensure cleanup of the temporary directory
	defer func() {
		if err := os.RemoveAll(tempDir); err != nil {
			log.Printf("Warning: Failed to clean up temporary directory %s: %v", tempDir, err)
		}
	}()

	// Get GitHub access token from environment variable
	accessToken := os.Getenv("GITHUB_TOKEN")
	if accessToken == "" {
		return fmt.Errorf("GITHUB_TOKEN environment variable is not set")
	}

	// Clone options with authentication
	cloneOptions := &git.CloneOptions{
		URL:      repoURL,
		Progress: os.Stdout,
		Auth: &github_http.BasicAuth{
			Username: "git", // This can be anything except empty string
			Password: accessToken,
		},
	}

	// Clone the repository
	fmt.Printf("Cloning repository into %s...\n", tempDir)
	_, err = git.PlainClone(tempDir, false, cloneOptions)
	if err != nil {
		return fmt.Errorf("failed to clone repository: %v", err)
	}

	fmt.Printf("\nRepository was cloned to %s\n", tempDir)
	fmt.Println("Note: The temporary directory will be deleted when the program exits")
	return nil
}

func main() {
	// Check if direct clone URL is provided
	repoURL := os.Getenv("GITHUB_URL")
	if repoURL != "" {
		if err := cloneRepository(repoURL); err != nil {
			log.Fatal(err)
		}
		return
	}

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

			// Check for "ai" tag
			hasAITag := false
			for _, label := range issuePayload.Issue.Labels {
				if label.Name == "ai" {
					hasAITag = true
					break
				}
			}

			if hasAITag {
				log.Printf("Processing issue #%d with AI tag from repository: %s",
					issuePayload.Issue.Number,
					issuePayload.Repository.CloneURL)

				/*
					if err := cloneRepository(issuePayload.Repository.CloneURL); err != nil {
						log.Printf("Error processing webhook: %v", err)
						http.Error(w, "Internal server error", http.StatusInternalServerError)
						return
					}
				*/
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
