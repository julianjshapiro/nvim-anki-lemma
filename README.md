# nvim-anki-lemma

A Neovim plugin for creating Anki cards from mathematical lemmas and proofs in markdown.

## Features

- Extract lemma statements and proofs from markdown files
- Create Anki cards with LaTeX and wiki-link support
- Preserve formatting (bold, italics, code blocks)
- Integrate with Anki via AnkiConnect

## Installation

Using lazy.nvim:

```lua
{
  "julianjshapiro/nvim-anki-lemma",
  config = function()
    require("anki_lemma").setup({
      anki_port = 8765,
      deck_name = "Math",
      model_name = "Proof",
    })
  end,
}
```

## Usage

Open a markdown file with a lemma and proof, then run:

```
:AnkiCreateCard
```

This will extract the lemma and proof, then create an Anki card.

## Requirements

- Neovim 0.7+
- [AnkiConnect](https://github.com/FooSoft/anki-connect) addon installed in Anki
- Anki running with AnkiConnect enabled

## License

MIT
