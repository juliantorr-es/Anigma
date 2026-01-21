# Contributing to Anigma

We welcome contributions from the community to help make the Anigma ecosystem even better! This guide outlines the process for getting involved, from setting up your development environment to submitting your first contribution.

## 1. Code of Conduct

Please review our [Code of Conduct](link-to-code-of-conduct.md) before contributing. We are committed to fostering an open and welcoming environment. All contributors are expected to adhere to the principles of respect, inclusivity, and collaboration.

## 2. Getting Started

To set up your development environment and get Anigma running locally, please follow the instructions in our [Getting Started Guide](/guide/getting-started). This will cover prerequisites, cloning the repository, and building the core components.

## 3. How to Contribute

We encourage contributions of all kinds, including:

*   **Bug Reports:** Identify and report issues that affect the functionality or stability of Anigma.
*   **Feature Requests:** Suggest new features or enhancements that would improve the ecosystem.
*   **Code Contributions:** Fix bugs, implement new features, or improve existing code.
*   **Documentation Improvements:** Enhance existing documentation or create new guides.

### General Workflow

Our contribution workflow typically follows these steps:

1.  **Fork the Repository:** Create your own fork of the Anigma monorepo on GitHub.
2.  **Clone Your Fork:** Clone your forked repository to your local machine.
3.  **Create a New Branch:** For each feature or bug fix, create a new branch from `main` with a descriptive name (e.g., `feature/add-new-ecs-component`, `bugfix/fix-daemon-crash`).
4.  **Make Your Changes:** Implement your changes, ensuring they adhere to the coding style guidelines.
5.  **Test Your Changes:** Run relevant tests to ensure your changes work as expected and don't introduce regressions.
6.  **Commit Your Changes:** Write clear, concise commit messages that explain the purpose of your changes. (Refer to the Harmonia Agent Governance Model for structured commit message guidance if applicable).
7.  **Push Your Branch:** Push your changes to your fork on GitHub.
8.  **Open a Pull Request (PR):** Submit a pull request to the `main` branch of the upstream Anigma repository. Provide a detailed description of your changes, reference any related issues, and ensure all checks pass.

## 4. Coding Style & Conventions

*   **Swift Linting:** All Swift code should adhere to the project's SwiftLint rules. Please run `swiftlint autocorrect` before submitting a PR.
*   **Existing Style:** Match the coding style of the surrounding code. Consistency is key.
*   **ECS Principles:** New features should align with the Entity-Component-System (ECS) architectural pattern.

## 5. Running Tests

Before submitting a Pull Request, please ensure all relevant tests pass.

*   **Swift Tests:** Navigate to the root of the `Anigma/` directory and run:
    ```bash
    swift test
    ```
*   **Documentation Site Tests (if applicable):**
    ```bash
    npm test # If specific JS tests are added later
    ```

## 6. Reporting Bugs & Suggesting Features

If you've found a bug or have an idea for a new feature:

1.  **Check Existing Issues:** Before opening a new issue, please check the [GitHub Issues](link-to-github-issues) to see if a similar bug has already been reported or feature requested.
2.  **Open a New Issue:** If not, open a new issue with a clear title and detailed description.
    *   **For Bug Reports:** Include steps to reproduce, expected behavior, actual behavior, and your environment details.
    *   **For Feature Requests:** Describe the problem you're trying to solve, the proposed solution, and potential benefits.

We appreciate your interest in contributing to Anigma! Your efforts help us build a more robust and accessible ecosystem.
