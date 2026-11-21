# Upstream

This fork takes changes from [abue-ammar/tinycast](https://github.com/abue-ammar/tinycast) one commit at
a time, by cherry-pick. **Never `git merge upstream/main`**: a merge would bring back every removed
feature, the update and support code, and the translations in one go.

## Remotes and tags

- `origin` is the fork. `upstream` is the original repository, fetch only: its push URL is set to
  `DISABLED` so nothing can be pushed there by accident.
- `upstream-base` marks the upstream commit the fork started from. It never moves.
- `upstream-reviewed` marks the newest upstream commit that has been reviewed, picked or skipped. It
  moves forward after every review; it starts at `upstream-base`.

If a clone lacks the remote:

```sh
git remote add upstream https://github.com/abue-ammar/tinycast.git
git remote set-url --push upstream DISABLED
```

## Reviewing a batch

1. Fetch: `git fetch upstream --no-tags`, so upstream's release tags stay out of the fork.
2. List what is new, limited to the paths this fork still has:

   ```sh
   git log --oneline --reverse upstream-reviewed..upstream/main -- \
     Tinycast Tests Scripts project.yml docs AGENTS.md
   ```

   A commit that only touches a removed feature (clipboard, snippets, notes, emoji, calendar, uninstall,
   extensions, AI, MCP, quick actions, dictation, iCloud sync, deep links, updates, support, website,
   CI, release tooling) or only translations is skipped without a closer look.

3. For each commit worth taking, on a branch: `git cherry-pick -x <sha>`. The `-x` records the upstream
   SHA in the message. Resolve conflicts toward the fork: drop hunks for removed features, keep
   English strings only, and never re-add a request to `tinycast.dev` or GitHub.
4. Run the definition of done from [testing.md](testing.md#definition-of-done) before pushing.
5. Log the batch in the PR description: each upstream SHA, picked or skipped, and why for each skip.
6. Move the tag to the last upstream commit reviewed, picked or not, and push it:

   ```sh
   git tag -f upstream-reviewed <last-reviewed-upstream-sha>
   git push -f origin upstream-reviewed
   ```

## License

The fork stays under the AGPL-3.0. Keep `LICENSE` and `NOTICE.md` intact; the original copyright stays
in both.
