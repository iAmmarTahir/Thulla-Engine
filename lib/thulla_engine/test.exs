alias ThullaEngine.Table

{:ok, game} = Table.start_link("A")
Table.add_player(game, "B")
Table.add_player(game, "C")
Table.add_player(game, "D")
Table.deal_cards(game)
