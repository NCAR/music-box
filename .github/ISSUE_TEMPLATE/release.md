---
name: Version Release
about: Create an issue to make a new release
title: 'Release X.X.X'
labels: ''
assignees: ''

---

## Dependency version update

- [ ] Update musica python package version in `pyproject.toml`

## Testing steps

- [ ] GitHub Actions are passing on `main`
- [ ] Launch Binder and run all tutorial examples

## Deployment and release steps

- [ ] Update the music box version in `python/acom_music_box/__init__.py` on a new branch (call it anything but `release`)
- [ ] Update the `CITATION.cff` file
  - [ ] Update version number
  - [ ] Ensure all contributors are listed as authors
- [ ] On GitHub, merge `main` into `release` — **do NOT squash and merge**
  - Alternatively, merge locally and push: `git checkout release && git merge main && git push`
- [ ] Make a tag and add release notes on GitHub
  - Be sure to choose the `release` branch for the target
## Python (automatic)
PyPI publishing happens automatically via the release action when a tag and release are created.

- [ ] Verify the PyPI release was published successfully

---

## JavaScript (automatic)

npm publishing happens automatically via the release action when a tag and release are created.

- [ ] Verify the npm release was published successfully