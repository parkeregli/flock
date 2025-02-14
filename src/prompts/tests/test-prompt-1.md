# Autonomous AI Developer Workflow Guide

## Initial Processing
- Parse the provided markdown specification document
- Generate structured task list from requirements
- Create internal validation checklist based on specification
- Store original specification for final verification
- Create a new branch for implementation

## Branch Creation
```bash
git checkout main
git pull origin main
git checkout -b feature/auto-implementation-{timestamp}
```

## Implementation Phase
- Process requirements sequentially without waiting for feedback
- Generate all necessary code files
- Create corresponding test files
- Implement error handling and logging
- Add required documentation

## Testing Phase
- Execute full test suite autonomously
- Record all test results and coverage metrics
- Store test execution logs
- Document any edge cases encountered

## Success Metrics
- All requirements implemented
- Test coverage meets minimum threshold
- No linting errors present

This async workflow operates independently without requiring human intervention until review phase. All decisions and implementations are made based on the initial specification document.

Here are the instructions for adding webhook support to your main.go:
# Instructions for Adding Webhook Support to main.go

## Important Note
This implementation builds upon your existing code, preserving the crucial GitHub URL and token functionality for repository cloning. The webhook handling is additional functionality that triggers the same cloning process when issues with the "ai" tag are created.

## Updated Dependencies
Add these imports while keeping your existing ones:
```go
import (
    // Existing imports
    "fmt"
    "log"
    "os"
    "path/filepath"
    "github.com/go-git/go-git/v5"
    "github.com/go-git/go-git/v5/plumbing/transport/http"
    
    // New imports for webhook handling
    "github.com/go-playground/webhooks/v6/github"
    "net/http"
)
```

## Code Structure
Your main function should be refactored into two parts:
1. A `cloneRepository` function containing your existing cloning logic
2. A new `main` function that sets up the webhook server

## Implementation Steps

1. First, move your existing cloning logic into a separate function:
```go
func cloneRepository(repoURL string) error {
    // Your existing temporary directory creation
    tempDir, err := os.MkdirTemp("", "git-clone-*")
    if err != nil {
        return fmt.Errorf("failed to create temporary directory: %v", err)
    }
    
    // Existing cleanup defer
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

    // Your existing clone options
    cloneOptions := &git.CloneOptions{
        URL:      repoURL,
        Progress: os.Stdout,
        Auth: &http.BasicAuth{
            Username: "git",
            Password: accessToken,
        },
    }

    // Your existing clone and file walking logic
    fmt.Printf("Cloning repository into %s...\n", tempDir)
    _, err = git.PlainClone(tempDir, false, cloneOptions)
    if err != nil {
        return fmt.Errorf("failed to clone repository: %v", err)
    }

    // Rest of your existing repository handling code
    return nil
}
```

2. Then, update the main function to handle both direct cloning and webhooks:
```go
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
    hook, err := github.New(github.Options.Secret(os.Getenv("WEBHOOK_SECRET")))
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
            hasAITag := false
            for _, label := range issuePayload.Issue.Labels {
                if label.Name == "ai" {
                    hasAITag = true
                    break
                }
            }

            if hasAITag {
                if err := cloneRepository(issuePayload.Repository.CloneURL); err != nil {
                    log.Printf("Error processing webhook: %v", err)
                    http.Error(w, "Internal server error", http.StatusInternalServerError)
                    return
                }
            }
        }
    })

    log.Fatal(http.ListenAndServe(":3000", nil))
}
```

## Configuration
1. Keep your existing environment variables:
   - `GITHUB_TOKEN`: Your GitHub access token
   - `GITHUB_URL`: (Optional) Direct repository URL for immediate cloning

2. Add new environment variable:
   - `WEBHOOK_SECRET`: Your GitHub webhook secret

## Behavior
- If `GITHUB_URL` is set, the program will perform a direct clone as before
- If `GITHUB_URL` is not set, it will start a webhook server that:
  - Listens for GitHub issue events
  - Clones repositories when issues are created with the "ai" tag
  - Uses the same authentication and cloning logic as the direct clone

Would you like me to explain any part of this implementation in more detail?
