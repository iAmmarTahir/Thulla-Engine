defmodule ThullaEngineTest do
    use ExUnit.Case
    alias ThullaEngine.{Table, TablePot, Rules}
  
    test "Add card to Table Pot" do
        t = TablePot.new('C')
        a = TablePot.add_card(t, 'AC', :player_one)
        assert {:ok, %TablePot{cards: MapSet.new([{:player_one, 'AC'}]), suit: 'C'}} == a
    end

    test "Check for thulla call from Table Pot" do
        t = TablePot.new('C')
        a = TablePot.add_card(t, '3H', :player_one)
        assert {:ok, :thulla_call} == a
    end

    test "Highest card player in a Table Pot" do
        t = TablePot.new('H')
        {:ok, t} = TablePot.add_card(t, '3H', :player_one)
        {:ok, t} = TablePot.add_card(t, 'AH', :player_two)
        {:ok, t} = TablePot.add_card(t, '9H', :player_three)
        {:ok, t} = TablePot.add_card(t, 'TH', :player_four)

        assert :player_two == TablePot.highest_card_player(t)
    end

    test "Add BadRang card to Table Pot" do
        t = TablePot.new('C')
        t = TablePot.add_badrang_card(t, '3H', :player_one)
        assert %TablePot{cards: MapSet.new([{:player_one, '3H'}]), suit: 'C'} == t
    end
  end
  