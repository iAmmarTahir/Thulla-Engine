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

    def check(%Rules{state: :player_four} = rules, :start_game) do
        {:ok, %Rules{rules | state: :game_started}}
    end

    def check(%Rules{state: :game_started} = rules, player) do
        {:ok, %Rules{rules | state: next_turn(player)}}
    end


    def check(%Rules{state: player} = rules, player) do
        {:ok, %Rules{rules | state: next_turn(player)}}
    end

    # def check(%Rules{state: :player_two_turn} = rules, :player_two_turn) do
    #     {:ok, %Rules{rules | state: :player_three_turn}}
    # end

    # def check(%Rules{state: :player_three_turn} = rules, :player_three_turn) do
    #     {:ok, %Rules{rules | state: :player_four_turn}}
    # end

    # def check(%Rules{state: :player_four_turn} = rules, :player_four_turn) do
    #     {:ok, %Rules{rules | state: :player_one_turn}}
    # end

    def check(_state,_action), do: :error

    defp next_turn(player) do
        case player do
            :player_one_turn    -> :player_two_turn
            :player_two_turn    -> :player_three_turn
            :player_three_turn    -> :player_four_turn
            :player_four_turn    -> :player_one_turn
        end
    end
end