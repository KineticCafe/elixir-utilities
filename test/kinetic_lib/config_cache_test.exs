defmodule KineticLib.ConfigCacheTest do
  use ExUnit.Case

  alias KineticLib.ConfigCache

  doctest ConfigCache, import: true

  setup do
    on_exit(fn -> :persistent_term.erase({KineticLib.ConfigCache, "key"}) end)
  end
end
