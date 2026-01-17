---
description: Setup Self-Hosted GitHub Runner on macOS
---

# Setup Self-Hosted Runner (macOS)

1.  **Go to GitHub Repo Settings**:
    *   Navigate to your repository: `https://github.com/jinzishuai/fitnessPipe`
    *   Click **Settings** tab.
    *   On the left sidebar, click **Actions** -> **Runners**.
    *   Click **New self-hosted runner**.

2.  **Select Architecture**:
    *   Image: **macOS**
    *   Architecture: **ARM64** (Apple Silicon)

3.  **Run Download Commands**:
    *   Run the commands provided by GitHub in your terminal (usually creates a `latest/actions-runner` directory).
    *   Example:
        ```bash
        mkdir actions-runner && cd actions-runner
        curl -o actions-runner-osx-arm64-2.311.0.tar.gz -L https://github.com/actions/runner/releases/download/v2.311.0/actions-runner-osx-arm64-2.311.0.tar.gz
        tar xzf ./actions-runner-osx-arm64-2.311.0.tar.gz
        ```

4.  **Configure**:
    *   Run `./config.sh --url https://github.com/jinzishuai/fitnessPipe --token <YOUR_TOKEN>`
    *   (The token is shown on the GitHub page).
    *   Name the runner: `mac-mini-runner` (or similar).
    *   Labels: Default `self-hosted`, `macOS`, `ARM64` are fine.

5.  **Run**:
    *   Run `./run.sh` to start it interactively.
    *   **Recommendation**: Install as a service so it runs in background even after reboot suitable for a server.
        ```bash
        ./svc.sh install
        ./svc.sh start
        ```

## Prerequisite Checks

Ensure your runner environment ("The Mac Mini") has these available in the path:

1.  `flutter` (Run `flutter doctor`)
2.  `maestro` (`export PATH="$PATH:$HOME/.maestro/bin"`)
3.  `xcrun simctl` (Xcode)

The runner uses a clean shell environment, so you might need to add paths to `.bashrc` or `.zshrc`.
