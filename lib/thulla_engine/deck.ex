defmodule ThullaEngine.Deck do
    alias __MODULE__

    defstruct [:content]

    @rank '23456789TAJQK'
    @suit 'CDSH'
    def new() do
        l = for x <- @rank, y <- @suit, do: [x, y]
        {:ok, %Deck{content: l}}
    end
end