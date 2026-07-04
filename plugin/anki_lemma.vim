if exists('g:loaded_anki_lemma')
  finish
endif
let g:loaded_anki_lemma = 1

command! AnkiCreateCard lua require('anki_lemma').create_card()
command! AnkiSetDeck lua require('anki_lemma').set_deck()
