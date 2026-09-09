This project uses a CLI ticket system for task management. Run `tk help` when you need to use it.

Keep each PR narrowly focused on one problem. Do not bundle unrelated fixes, input validation, refactors, cleanup, or documentation changes into the same PR. Discovering another issue while working does not authorize adding it to the current PR: put it in a separate PR with its own explanation and validation. Include only changes necessary for the PR's stated purpose, and document dependencies between PRs explicitly. If an implementation expands the agreed scope, split that work before presenting the PR as ready for review.

Run `flutter analyze` regularly to check if your changes have any syntax errors. 


From the top level directory:
- run `make materials`  to rebuild materials
- run `make bindings` to regenerate FFI bindings
