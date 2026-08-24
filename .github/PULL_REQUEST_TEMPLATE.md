## Description
Please include a summary of the change and which issue is fixed (if applicable).
Include relevant motivation and context.

Fixes # (issue number)

## Type of change
Please delete options that are not relevant.

- [ ] Bug fix (non-breaking change which fixes an issue)
- [ ] New feature (non-breaking change which adds functionality)
- [ ] Breaking change (fix or feature that would cause existing functionality to not work as expected)
- [ ] Documentation update
- [ ] New Plugin/Provider

## Architecture Contract Check
Before submitting this PR, please verify the following:
- [ ] I have read the `ARCHITECTURE.md` and my code respects the boundaries between Workflow, Pipeline, and Job.
- [ ] I am not adding mutable state or parallel properties to models outside of `NoemaProject`.
- [ ] I have read the `CONTRIBUTING.md` guidelines.

## Checklist
- [ ] My code follows the style guidelines of this project
- [ ] I have performed a self-review of my own code
- [ ] I have commented my code, particularly in hard-to-understand areas
- [ ] My changes generate no new warnings (ran `dart analyze`)
- [ ] Any dependent changes have been merged and published in downstream modules
