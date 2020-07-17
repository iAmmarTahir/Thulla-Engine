defmodule ThullaEngineTest do
    use ExUnit.Case
    alias ThullaEngine.{Table, TablePot, Rules}
  
    test "check highest card in deck" do
        {:ok, game} = Table.new("A")
        assert type(game) ==  'PID'
    end
  end
  