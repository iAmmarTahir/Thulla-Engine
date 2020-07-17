defmodule ThullaEngine.TablePot do
    defstruct [:cards, :suit] 
    alias __MODULE__
    def new(), do: %TablePot{cards: MapSet.new()}
    def new(suit), do: %TablePot{cards: MapSet.new(), suit: suit}
   
    def add_card(%TablePot{} = pot, card, player) do
        case check_card_suit?(card, pot.suit) do
            true -> {:ok, %TablePot{cards: MapSet.put(pot.cards, {player, card}), suit: pot.suit}}
            false -> {:ok, :thulla_call}
        end
    end
  
    def set_suit(%TablePot{} = pot, suit) do
        %TablePot{pot | suit: suit}
    end

    defp check_card_suit?(card, suit) do
        [_h|t] = card
        case t == suit do
            true -> true
            false -> false
        end
    end

    def highest_card_player(%TablePot{} = pot) do
        l =  '23456789TJQKA' 
             |> Enum.with_index 
             |> Map.new
        res = Enum.max_by(pot.cards, fn {player, [h|t]} -> l[h] end)
        {player, card} = res
        case player do
            :player_one     -> :player_one_turn
            :player_two     -> :player_two_turn
            :player_three   -> :player_three_turn
            :player_four    -> :player_four_turn
        end
    end

    def get_cards(%TablePot{} = pot) do
        l = MapSet.to_list(pot.cards)
        c = Enum.map(l, fn {_k, v} -> v end)
        MapSet.new(c)
    end

    def add_badrang_card(%TablePot{} = pot, card, player) do
        %TablePot{cards: MapSet.put(pot.cards, {player, card}), suit: pot.suit}
    end
end