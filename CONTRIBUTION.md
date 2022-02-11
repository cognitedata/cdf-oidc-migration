## Contribution

### Development

Development of these scripts require Python `3` and Powershell version `7` or higher. The requirements need to be installed to run the Python script. Use the following command to install the required dependencies.

`pip install -r requirements.txt`

### Commit naming conventions

We use [Angular Commit Message Conventions](https://github.com/angular/angular.js/blob/master/DEVELOPERS.md#-git-commit-guidelines).

Examples of a proper commit message:
`feat(AssetMeta): added a new "isCollapsed" property`
or
`fix: proper components behaviour on mobile`

Here is a short cheat sheet of available options:

* `feat(pencil):` A new feature
* `fix:` A bug fix
* `docs:` Documentation only changes
* `style:` Changes that do not affect the meaning of the code (white-space, formatting, missing semi-colons, etc)
* `refactor:` A code change that neither fixes a bug nor adds a feature
* `perf:` A code change that improves performance
* `test:` Adding missing or correcting existing tests
* `chore:` Changes to the build process or auxiliary tools and libraries such as documentation generation

### Publishing changes

Only basic steps are needed:

1. Create a new branch from the `main` branch.
2. Commit changes and remember about [proper commit messages](#commit-naming-conventions)
3. Push branch to GitHub
4. Open a new pull request, ask for review, get feedback, apply fixes if needed
5. When PR is approved you can merge the branch and remove it afterwards
