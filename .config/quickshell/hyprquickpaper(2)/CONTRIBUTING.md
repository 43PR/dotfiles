# Contributing

Thank you for considering contributing to this project! Since the project is still small and evolving, contributions are very welcome.

## Pull Requests

When submitting a pull request, please include the following:

1. **Screenshots or a screen recording** demonstrating the change or feature.
2. A **clear description of what was changed**.
3. A **short explanation of how the change was implemented**, especially if the logic is not obvious.

This helps reviewers(basically just me haha) quickly understand the purpose and impact of your contribution.

## Configuration Changes

This project is intended to be **customizable**.

If your change introduces new configurable behavior:

- Add the option to `config.json`.
- Document the option clearly in the **README**.

Please avoid hard-coding user-configurable values directly in the code.

## Project Structure

Currently, the project is intentionally kept **simple**:

- The UI logic exists in a **single QML file**.
- Since the project is still small, there is **no separate documentation folder**.

If the project grows larger in the future, the codebase may be refactored.

You are welcome to experiment with **refactoring**, but please note:

- Some internal structure choices are intentional.
- Large structural changes may be rejected if they conflict with the project's design goals.

## Things You Can Contribute To

Here are a few open issues that would make good contributions:

- [ ] **Path handling bug**  
      Missing the trailing `/` in paths inside `config.json` currently breaks the program.

- [ ] **Customizable image transform**  
      The image currently uses a hardcoded **shear transform**. Making this transform configurable would improve customization.

You can work on other issues that are open.

## General Guidelines

- Keep changes **focused and minimal**.
- If you're unsure about a change, feel free to open an **issue first** to discuss it.
