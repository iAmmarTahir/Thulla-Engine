defmodule ThullaEngine.Rules do
  alias __MODULE__

  defstruct state: :initialized

  def new(), do: %Rules{}

  def new(state), do: %Rules{state: state}

  def check(%Rules{state: :initialized} = rules, :add_player) do
    {:ok, %Rules{rules | state: :player_two}}
  end

  def check(%Rules{state: :player_two} = rules, :add_player) do
    {:ok, %Rules{rules | state: :player_three}}
  end

  def check(%Rules{state: :player_three} = rules, :add_player) do
    {:ok, %Rules{rules | state: :player_four}}
  end

  def check(%Rules{state: :player_four} = rules, :dealing_cards) do
    {:ok, %Rules{rules | state: :dealt_cards}}
  end

  def check(%Rules{state: :dealt_cards} = rules, :game_over) do
    {:ok, %Rules{rules | state: :game_over}}
  end

  def check(_state, _action), do: :error

end
