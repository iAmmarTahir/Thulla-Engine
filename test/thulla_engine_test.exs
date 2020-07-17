defmodule ThullaEngineTest do
  use ExUnit.Case
  doctest ThullaEngine

  test "greets the world" do
    assert ThullaEngine.hello() == :world
  end
end
