defmodule ThullaEngine.Table do
    alias ThullaEngine.{Deck, TablePot, Rules}
    
    use GenServer

    def new(), do: %{}

    ### PUBLIC API
    def start_link(name), do:
        GenServer.start_link(__MODULE__, name)

    def add_player(game, name) when is_binary(name), do:
        GenServer.call(game, {:add_player, name})

    def make_move(game, card), do:
        GenServer.call(game, {:make_move, card})
    
    def start_game(game), do:
        GenServer.call(game, {:start_game})

    
    
    ### Internal Game Server
    def init(name) do
        {:ok, fresh_state(name)}
    end

    def handle_call({:add_player, name}, _from, state) do
        with {:ok, rules} <- Rules.check(state.rules, :add_player)
        do
            state
            |> update_player_name(name, rules)
            |> update_rules(rules)
            |> reply_success(:ok)
        else
            :error -> {:reply, :error, state}
        end
    end

    def handle_call({:start_game}, _from, state) do
        with {:ok, rules} <- Rules.check(state.rules, :start_game) 
        do
            state
            |> update_rules(rules)
            |> reply_success(:ok)
        else
            :error -> {:reply, :error, state}
        end
    end

    def handle_call({:make_move, card}, _from, state) do  
        with {:ok, rules} <- Rules.check(state.rules, state.turn)
        do
            player = get_player(state.turn)
            case state[player].winner do
                true -> state
                        |> update_rules(rules)
                        |> update_turn()
                        |> empty_pot()
                        |> reply_success(:winner)
                false -> case MapSet.size(state[player].deck) do
                            0 ->    put_in(state[player].winner, true)
                                    |> update_winners()
                                    |> update_rules(rules)
                                    |> update_turn()
                                    |> check_game_over()
                                    |> final_reply()
                            _ ->    case MapSet.member?(state[player].deck, card) do
                                        true -> state
                                                |> update_player_deck(card)
                                                |> update_table_pot(card)
                                                |> update_rules(rules)
                                                |> update_turn()
                                                |> empty_pot()
                                                |> reply_success(:move_success)
                                        false -> state
                                                |> reply_success(:wrong_card)
                                    end
                        end
            end
                     
        else
            :error -> {:reply, :error, state}
        end
    end

    ### Game Logic
    ## Returns the fresh state of table
    def fresh_state(name) do   
        l = chunked_deck()

        [deck_one | tail] = l
        [deck_two | tail] = tail
        [deck_three | tail] = tail
        [deck_four | _] = tail
        
        player_one = %{name: name, deck: MapSet.new(deck_one), winner: false} 
        player_two = %{name: nil, deck: MapSet.new(deck_two), winner: false}
        player_three = %{name: nil, deck: MapSet.new(deck_three), winner: false}
        player_four = %{name: nil, deck: MapSet.new(deck_four), winner: false}

        turn = first_turn(player_one, player_two, player_three, player_four)
        table_pot = TablePot.new('C')
        %{
            player_one: player_one, 
            player_two: player_two, 
            player_three: player_three, 
            player_four: player_four,
            turn: turn,
            table_pot: table_pot,
            rules: Rules.new(),
            no_of_turns: 0,
            first_turn: true,
            winners: 0
        }
    end

    ## Determines which player's turn is first
    def first_turn(player_one, player_two, player_three, player_four) do

        a = check_for_ace?(player_one)
        b = check_for_ace?(player_two)
        c = check_for_ace?(player_three)
        d = check_for_ace?(player_four)

        case {a, b, c, d} do
            {true,_,_,_}    ->   :player_one_turn
            {_,true,_,_}    ->   :player_two_turn
            {_,_,true,_}    ->   :player_three_turn
            {_,_,_,true}    ->   :player_four_turn
        end
    end

    ### PRIVATE ULTILITY FUNCS
    
    ## Updating the Rules in game state
    def update_rules(state, rules) do
        %{state | rules: rules}
    end

    ## Checks for an ace in a deck
    defp check_for_ace?(%{} = player) do
        MapSet.member?(player.deck, 'AC')
    end

    ## Returns the deck chunked into 13 cards for each player
    defp chunked_deck() do
        {:ok, deck} = Deck.new()     
        deck.content 
        |> Enum.shuffle()
        |> Enum.chunk_every(13)
    end

    ## Updates the player names according to their joining the game
    defp update_player_name(state, name, rules) do
        put_in(state[rules.state].name, name)
    end

    ## Success reply
    defp reply_success(state, reply) do
        {:reply, reply, state}
    end

    ## Update each players deck
    defp update_player_deck(state, card) do
        player = get_player(state.turn)
        %{player: player,state: put_in(state[player].deck, MapSet.delete(state[player].deck, card))}   
    end

    ## Update the game pot on each turn
    defp update_table_pot(%{player: player, state: state}, card) do
        [_rank | suit] = card   
        state
        |> set_suit_for_new_round(suit)
        |> add_card_to_pot_or_thulla(card, player) 
    end

    ## Updates the next player turn
    defp update_turn(state) do
        s = put_in(state[:turn], state.rules.state)
        update_in(s.no_of_turns, &(&1 + 1))
    end

    ## Empties pot if all 4 players have made their turns successfully (Sarr)
    defp empty_pot(state) do
        case state.no_of_turns do
            4   ->  state
                    |> next_turn
                    |> add_new_rules
                    |> initiate_new_tablepot
                    |> check_for_first_round
                    |> reset_no_of_turns
            _ -> state
        end
    end

    defp thulla(state, card) do
        bhabhi = TablePot.highest_card_player(state[:table_pot])
        player = get_player(bhabhi)
        state
        |> add_tablepot_cards_to_deck(player)
        |> add_thulla_card(player, card)
        |> update_turn(3)
    end

    defp get_player(turn) do
        case turn do
            :player_one_turn    -> :player_one
            :player_two_turn    -> :player_two
            :player_three_turn  -> :player_three
            :player_four_turn   -> :player_four
        end
    end

    defp update_turn(state, turns) do
        put_in(state[:no_of_turns], turns)
    end

    defp add_tablepot_cards_to_deck(state, player) do
        put_in(state[player].deck, MapSet.union(state[player].deck, TablePot.get_cards(state[:table_pot])))
    end

    defp add_thulla_card(state, player, card) do
        put_in(state[player].deck, MapSet.put(state[player].deck, card))
    end

    defp next_turn(state) do
        put_in(state[:turn], TablePot.highest_card_player(state[:table_pot]))
    end 

    defp add_new_rules(state) do
        put_in(state[:rules], Rules.new(state[:turn]))
    end

    defp initiate_new_tablepot(state) do
        put_in(state[:table_pot], TablePot.new())
    end

    defp check_for_first_round(state) do
        case state[:first_turn] do 
            true    -> put_in(state[:first_turn], false)
            false   -> state
        end
    end

    defp reset_no_of_turns(state) do
        put_in(state[:no_of_turns], 0)
    end

    defp set_suit_for_new_round(state, suit) do
        case state[:table_pot].suit === nil do
            true -> put_in(state[:table_pot], TablePot.set_suit(state[:table_pot], suit))
            false -> state
        end
    end

    defp add_card_to_pot_or_thulla(state, card, player) do
        case TablePot.add_card(state.table_pot, card, player) do
            {:ok, :thulla_call} -> check_first_turn(state, card, player)
            {:ok, pot} -> put_in(state[:table_pot], pot)
        end
    end

    defp check_first_turn(state, card, player) do
        case state.first_turn do 
            false -> thulla(state, card)
            true ->  put_in(state[:table_pot], TablePot.add_badrang_card(state.table_pot, card, player))
        end
    end

    defp update_winners(state) do 
        update_in(state[:winners], &(&1 + 1))
    end

    defp check_winner_players(state) do
        case  { check_winner(state.player_one), 
                check_winner(state.player_two), 
                check_winner(state.player_three), 
                check_winner(state.player_four)}
        do 
            {false, _, _, _} -> %{loser: {:player_one}, winner: {:player_two, :player_three, :player_four}}
            {_, false, _, _} -> %{loser: {:player_two}, winner: {:player_one, :player_three, :player_four}}
            {_, _, false, _} -> %{loser: {:player_three}, winner: {:player_one, :player_two, :player_four}}
            {_, _, _, false} -> %{loser: {:player_four}, winner: {:player_one, :player_two, :player_three}}
        end
    end

    defp check_winner(%{} = player) do
        case player.winner do
            true -> true
            false -> false
        end
    end

    defp check_game_over(state) do
        case state.winners do
            3 -> %{result: check_winner_players(state), state: state}
            _ -> state
        end
    end

    defp final_reply(res) do
        case res do
            {result, state} -> {:reply, result, fresh_state(state.player_one.name)}
            _ -> {:reply, :winner, res}
        end
    end
end