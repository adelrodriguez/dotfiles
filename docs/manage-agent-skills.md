# Manage agent skills

GNU Stow exposes `agents/skills/` at `~/.agents/skills`. Global Skills CLI commands write into this repository after you run `dot init` or `dot sync`.

## Add a skill from a remote repository

1. Add the skill through the global store.

	```sh
	npx skills add owner/repo -g -a opencode codex claude-code -s skill-name -y
	```

2. Review the files before you commit them.

	```sh
	git status --short
	git diff -- agents/skills
	```

Do not install a skill from the local `agents/skills/` path. That path is the destination, not a remote source.

## Create a personal skill

1. Create the skill in the repository.

	```sh
	mkdir -p "$HOME/Developer/dotfiles/agents/skills/my-skill"
	$EDITOR "$HOME/Developer/dotfiles/agents/skills/my-skill/SKILL.md"
	```

2. Add YAML frontmatter with a `name` and a `description`.

	```markdown
	---
	name: my-skill
	description: Describe when an agent must use this skill.
	---
	```

3. Link the skill into each detected agent tool.

	```sh
	dot sync
	```

4. Review the new files.

5. Commit the new files.
