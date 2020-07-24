defmodule ThullaEngine.Table do
  alias ThullaEngine.{Deck, TablePot, Rules}

  use GenServer

  @timeout 1000 * 10 * 5

  def new(), do: %{}

  ##################
  ### PUBLIC API ###
  ##################

  def start_link(name), do: GenServer.start_link(__MODULE__, name, name: via_tuple(name))

  def next_round(game), do: GenServer.call(game, {:next_round})

  def add_player(game, name) when is_binary(name), do: GenServer.call(game, {:add_player, name})

  def remove_player(game, player), do: GenServer.call(game, {:remove_player, player})

  def deal_cards(game), do: GenServer.call(game, {:dealing_cards})

  def player_move(game, player, card), do: GenServer.call(game, {:player_move, player, card})

  ############################
  ### INTERNAL GAME SERVER ###
  ############################

  def init(_name) do
    {:ok, fresh_state(), @timeout}
  end

  def handle_call({:next_round}, _from, state) do
    {:reply, :ok, updated_state(state)}
  end

  def handle_call({:add_player, name}, _from, state) do
    with {:ok, rules} <- Rules.check(state.rules, :add_player) do
      s =
        state
        |> check_to_update_rules(rules)
        |> update_player_name(name)

      reply_success(s.state, {:player_added, s.player})
    else
      :error -> {:reply, :error, state}
    end
  end

  def handle_call({:remove_player, player}, _from, state) do
    p = get_player_from_index(player)

    case state.players[p].joined do
      true ->
        state
        |> update_player_status(player)
        |> next_player_turn(player)
        |> update_no_of_turns(player)
        |> remove_tablepot_card(player)
        |> remove_from_turns(player)
        |> reply_success({:ok, :player_removed, player})

      false ->
        {:reply, {:error, :player_not_joined}, state}
    end
  end

  def handle_info(:timeout, state) do
    IO.inspect("Timeout: Server shutting down...")
    {:stop, {:shutdown, :timeout}, state}
  end

  def terminate({:shutdown, :timeout}, state) do
    :ok
  end

  def terminate(_reason, _state), do: :ok

  def handle_call({:dealing_cards}, _from, state) do
    with {:ok, rules} <- Rules.check(state.rules, :dealing_cards) do
      state
      |> update_rules(rules)
      |> reply_success({state.players, state.turn})
    else
      :error -> {:reply, :error, state}
    end
  end

  def handle_call({:player_move, player, card}, _from, state) do
    cond do
      state.rules.state != :dealt_cards ->
        reply_success(state, :error)

      player != state.turn ->
        reply_success(state, {:error, :invalid_player})

      MapSet.member?(state.players[get_player_from_index(player)].deck, card) == false ->
        reply_success(state, {:error, :invalid_card})

      player == state.turn and
          MapSet.member?(state.players[get_player_from_index(player)].deck, card) == true ->
        state
        |> update_player_deck(card)
        |> update_table_pot(card)
        |> update_turn()
        |> empty_pot()
        |> reply_success(:ok)
    end
  end

  #########################
  ### UTILITY FUNCTIONS ###
  #########################

  ## Returns the fresh state of table
  def fresh_state() do
    l = chunked_deck()

    [deck_one | tail] = l
    [deck_two | tail] = tail
    [deck_three | tail] = tail
    [deck_four | _] = tail

    player_one = %{name: nil, deck: MapSet.new(deck_one), winner: false, joined: false}
    player_two = %{name: nil, deck: MapSet.new(deck_two), winner: false, joined: false}
    player_three = %{name: nil, deck: MapSet.new(deck_three), winner: false, joined: false}
    player_four = %{name: nil, deck: MapSet.new(deck_four), winner: false, joined: false}

    turn = first_turn(player_one, player_two, player_three, player_four)
    table_pot = TablePot.new('C')

    %{
      players: %{
        player_one: player_one,
        player_two: player_two,
        player_three: player_three,
        player_four: player_four
      },
      turn: turn,
      table_pot: table_pot,
      rules: Rules.new(),
      no_of_turns: 0,
      is_first_turn: true,
      players_turn: [0, 1, 2, 3]
    }
  end

  def updated_state(state) do
    l = chunked_deck()
    [deck_one | tail] = l
    [deck_two | tail] = tail
    [deck_three | tail] = tail
    [deck_four | _] = tail

    player_one = %{state.players[:player_one] | deck: MapSet.new(deck_one), winner: false}
    player_two = %{state.players[:player_two] | deck: MapSet.new(deck_two), winner: false}
    player_three = %{state.players[:player_three] | deck: MapSet.new(deck_three), winner: false}
    player_four = %{state.players[:player_four] | deck: MapSet.new(deck_four), winner: false}

    turn = first_turn(player_one, player_two, player_three, player_four)
    table_pot = TablePot.new('C')

    %{
      players: %{
        player_one: player_one,
        player_two: player_two,
        player_three: player_three,
        player_four: player_four
      },
      turn: turn,
      table_pot: table_pot,
      rules: Rules.new(),
      no_of_turns: 0,
      is_first_turn: true,
      players_turn: [0, 1, 2, 3]
    }
  end

  ## Determines which player's turn is first
  def first_turn(player_one, player_two, player_three, player_four) do
    a = check_for_ace?(player_one)
    b = check_for_ace?(player_two)
    c = check_for_ace?(player_three)
    d = check_for_ace?(player_four)

    case {a, b, c, d} do
      {true, _, _, _} -> 0
      {_, true, _, _} -> 1
      {_, _, true, _} -> 2
      {_, _, _, true} -> 3
    end
  end

  defp update_player_status(state, index) do
    player = get_player_from_index(index)
    put_in(state.players[player].joined, false)
  end

  defp remove_from_turns(state, player) do
    remove_player_from_state(state, player)
  end

  defp next_player_turn(state, player) do
    case state.turn == player do
      true -> put_in(state.turn, next_turn(state, player))
      false -> state
    end
  end

  defp check_to_update_rules(state, rules) do
    case has_any_seats?(state) do
      false -> update_rules(state, rules)
      true -> state
    end
  end

  defp has_any_seats?(state) do
    seats_available =
      Enum.count(
        Enum.filter(state.players, fn player -> state.players[elem(player, 0)].joined == false end)
      ) - 1

    case seats_available do
      0 -> false
      _ -> true
    end
  end

  defp update_no_of_turns(state, player) do
    p = get_player_from_index(player)
    res = Enum.filter(state.table_pot.cards, fn {x, _y} -> x == p end)

    case Enum.count(res) do
      0 -> state
      1 -> update_in(state.no_of_turns, &(&1 - 1))
    end
  end

  defp remove_tablepot_card(state, player) do
    p = get_player_from_index(player)
    put_in(state.table_pot, TablePot.remove_card(state.table_pot, p, state.is_first_turn))
  end

  ## Updating the Rules in game state
  def update_rules(state, rules) do
    %{state | rules: rules}
  end

  ## Checks for an ace in a deck
  defp check_for_ace?(%{} = player) do
    MapSet.member?(player.deck, 'AC')
  end

  defp test_deck() do
    [
      ['AC', '3D'],
      ['2C', '3H'],
      ['4C', '4H'],
      ['3S', 'TH', '2D']
    ]
  end

  ## Returns the deck chunked into 13 cards for each player
  defp chunked_deck() do
    {:ok, deck} = Deck.new()

    deck.content
    |> Enum.shuffle()
    |> Enum.chunk_every(13)
  end

  ## Updates the player names according to their joining the game
  defp update_player_name(state, name) do
    l =
      Enum.filter(state.players, fn player -> state.players[elem(player, 0)].joined == false end)

    [first | rest] = l
    player = elem(first, 0)
    s = put_in(state.players[player].name, name)
    %{player: player, state: put_in(s.players[player].joined, true)}
  end

  ## Success reply
  defp reply_success(state, reply) do
    {:reply, reply, state}
  end

  defp update_player_deck(state, card) do
    player = get_player_from_index(state.turn)
    put_in(state.players[player].deck, MapSet.delete(state.players[player].deck, card))
  end

  defp update_table_pot(state, card) do
    player = get_player_from_index(state.turn)
    [_rank | suit] = card

    state
    |> set_suit_for_new_round(suit)
    |> check_for_thulla(card, player)
  end

  defp set_suit_for_new_round(state, suit) do
    case state.table_pot.suit === nil do
      true -> put_in(state.table_pot, TablePot.set_suit(state.table_pot, suit))
      false -> state
    end
  end

  defp check_for_thulla(state, card, player) do
    case TablePot.add_card(state.table_pot, card, player) do
      {:ok, :thulla_call} -> is_valid_thulla(state, card, player)
      {:ok, pot} -> put_in(state.table_pot, pot)
    end
  end

  defp is_valid_thulla(state, card, player) do
    case state.is_first_turn do
      false -> thulla(state, card)
      true -> put_in(state.table_pot, TablePot.add_badrang_card(state.table_pot, card, player))
    end
  end

  defp thulla(state, card) do
    bhabhi = TablePot.highest_card_player(state.table_pot)

    state
    |> add_pot_cards_to_deck(bhabhi)
    |> add_thulla_card(bhabhi, card)
    |> new_turn(Enum.count(state.players_turn) - 1)
  end

  defp add_pot_cards_to_deck(state, player) do
    put_in(
      state.players[player].deck,
      MapSet.union(state.players[player].deck, TablePot.get_cards(state.table_pot))
    )
  end

  defp add_thulla_card(state, player, card) do
    put_in(state.players[player].deck, MapSet.put(state.players[player].deck, card))
  end

  defp new_turn(state, turns) do
    put_in(state.no_of_turns, turns)
  end

  defp update_turn(state) do
    s = put_in(state.turn, next_turn(state, state.turn))
    update_in(s.no_of_turns, &(&1 + 1))
  end

  defp empty_pot(state) do
    size = Enum.count(state.players_turn)

    cond do
      state.no_of_turns === size ->
        state
        |> next_highest_card_player()
        |> make_first_round_false()
        |> reset_no_of_turns()
        |> check_winners()
        |> initialize_new_pot()

      true ->
        state
    end
  end

  defp check_winners(state) do
    l =
      Enum.filter(state.players_turn, fn x ->
        MapSet.size(state.players[get_player_from_index(x)].deck) == 0
      end)

    s = put_in(state.players_turn, state.players_turn -- l)

    p = Enum.map(l, &get_player_from_index(&1))
    Enum.map(p, fn x -> put_in(s.players[x].winner, true) end)
    s = Enum.reduce(p, s, fn x, acc -> put_in(acc.players[x].winner, true) end)

    {:ok, rules} = Rules.check(s.rules, :game_over)

    case Enum.count(s.players_turn) do
      1 ->
        update_rules(s, rules)

      0 ->
        update_rules(s, rules)
        |> handle_tie()

      _ ->
        s
    end
  end

  defp handle_tie(state) do
    loser = TablePot.highest_card_player(state.table_pot)
    put_in(state.players[loser].winner, false)
  end

  defp next_highest_card_player(state) do
    put_in(state.turn, player_to_index(TablePot.highest_card_player(state.table_pot)))
  end

  defp initialize_new_pot(state) do
    put_in(state.table_pot, TablePot.new())
  end

  defp make_first_round_false(state) do
    case state.is_first_turn do
      true -> put_in(state.is_first_turn, false)
      false -> state
    end
  end

  defp reset_no_of_turns(state) do
    put_in(state.no_of_turns, 0)
  end

  defp next_turn(state, turn_index) do
    index = rem(get_index(state, turn_index) + 1, Enum.count(state.players_turn))
    Enum.at(state.players_turn, index)
  end

  defp remove_player_from_state(state, player) do
    %{state | players_turn: List.delete(state.players_turn, player)}
  end

  defp get_index(state, player) do
    Enum.find_index(state.players_turn, fn x -> x === player end)
  end

  defp get_player(state, index) do
    Enum.at(state.players_turn, index)
  end

  defp get_player_from_index(index) do
    case index do
      0 -> :player_one
      1 -> :player_two
      2 -> :player_three
      3 -> :player_four
    end
  end

  defp player_to_index(player) do
    case player do
      :player_one -> 0
      :player_two -> 1
      :player_three -> 2
      :player_four -> 3
    end
  end

  def via_tuple(name), do: {:via, Registry, {Registry.Table, name}}
end
