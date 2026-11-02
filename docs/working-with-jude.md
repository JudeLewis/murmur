# Working with Jude

How Jude likes to work with Claude on Murmur. Read this before replying. It matches how Clocked In is run, so both projects feel the same.

## Who Jude is

- Jude owns Murmur and is its only user. They are not a coder.
- They test by using the app, not by reading code.

## How to reply

- Short and plain. One line that answers, then a few short bullets. Aim for under 15 lines.
- Everyday words and short sentences. No jargon: say "check", not "gate".
- No tables, background or caveats unless Jude asks. Offer detail instead of giving it.
- Put any decisions Jude needs to make at the end, numbered, with a recommendation.
- British English. No em dashes.

## How to give steps

- Jude can't be expected to find a file, a setting or a menu, or to know the terminal.
- Number the steps, one action each. Say which app, where to click, exactly what to type or paste, which key to press, and what they'll see when it worked.
- Prefer one paste-and-Enter command over "open X and edit Y".
- Give a check that prints a plain OK or NOT OK where possible.

## How work is done

1. **Plan first.** For anything beyond a trivial change, show the plan and wait for Jude's go-ahead.
2. **Build with tests.** Logic in MurmurCore with tests in the same change. Suite names start with their SPEC.md section.
3. **Review.** At the end of each piece of work, run /code-review and fix what it finds.
4. **Install.** Run `./scripts/install.sh` so the copy in Applications is the new one.
5. **Jude tests** by dictating into real apps.
6. **Commit.** Claude commits checked work with the pre-commit check passing, without asking each time, and tells Jude the commit hash. Never push. Never commit over failing checks.
7. **Keep the docs current, without asking.** In the same turn as any change or decision, update SPEC.md, docs/architecture.md, TODO.md (finished items to archive/) and Claude's memory, and say in one line what changed. Nothing important should live only in the conversation.

## Keep it light

- Don't add tools, services or routines Jude would have to manage. If a process idea would make things clunky or burn through usage, drop it and say why.
- Cap anything that loops (for example, three rounds of trying a fix before stopping to ask).
- Product questions ("is this worth building?") get an honest recommendation, not a list of every option.

## iPhone updates

- After every iPhone install the speech model needs one to a few minutes to get ready again. Say so in the reply, and group phone changes so installs are rare.

## When something breaks

- Read Murmur's log first: `/usr/bin/log show --last 10m --predicate 'subsystem == "com.judelewis.murmur"' --style compact`.
- Fix the cause, then turn the mistake into a test so it can't come back.
- Add a line to CLAUDE.md's Gotchas only when something actually broke.
