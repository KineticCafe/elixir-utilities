defmodule KineticLib.RandomString do
  @moduledoc """
  A module to generate random strings that can be used for authentication tokens, etc.
  """

  defdelegate seed(), to: :crypto, as: :rand_seed

  def subset(enumerable, count \\ nil)

  def subset(_, 0) do
    []
  end

  def subset(enumerable, nil) do
    subset(enumerable, Enum.random(0..Enum.count(enumerable)))
  end

  def subset(enumerable, count) when is_integer(count) and count > 0 do
    {_, subset} =
      Enum.reduce(1..count, {Enum.to_list(enumerable), []}, fn _, {set, subset} ->
        {value, set} = List.pop_at(set, Enum.random(0..(length(set) - 1)))
        {set, [value | subset]}
      end)

    subset
  end

  def string(alphabet, size) when is_binary(alphabet) do
    string(String.graphemes(alphabet), size)
  end

  def string(alphabet, size) when is_list(alphabet) do
    Enum.map_join(1..size, "", fn _ -> Enum.random(alphabet) end)
  end

  @doc """
  Generate a random string of a specified size from a supplied alphabet.

  The supplied alphabet must contain three or more graphemes, and the size
  must be less than half the length of the alphabet.

      iex> alphabet = "BDGHKMNRSTVXZ"
      ...> Task.await(Task.async(fn ->
      ...>   :rand.seed(:default, [2])
      ...>   permuted_string(alphabet, 6)
      ...> end))
      "MXVGSK"

  The alphabet can contain repeated graphemes if you want to allow repeated
  graphemes in the resulting string. For example:

      iex> alphabet = "BDGHKMNRSTVXZ"
      ...> double_alphabet = alphabet <> alphabet
      ...> Task.await(Task.async(fn ->
      ...>   :rand.seed(:default, [2])
      ...>   permuted_string(double_alphabet, 7)
      ...> end))
      "MGVMKKT"

  > ### Testing a “random” function {: info}
  >
  > The OTP `:rand` module is the source of randomness in this function, and
  > it stores its state per process.
  > The `Task.async/1` and `Task.await/1` are an attempt to isolate the
  > example’s random state to avoid prevent concurrent tests from messing it
  > up.
  >
  > The seed used was the first one I came across that showed the presence of
  > doubled graphemes in the output realistically.
  >
  > If the default random number generator changes from `exsss` then this test
  > will fail.

  ## Intended use and caveats

  The original use case for this is to generate tokens that a customer can
  read and use for verification of SMS messages.

  The OTP `:rand` module is used “under the hood”, so it is not cryptographically
  secure.
  """
  def permuted_string(alphabet, size) when is_binary(alphabet) and is_integer(size) do
    permuted_string(String.graphemes(alphabet), size)
  end

  def permuted_string(alphabet, size)
      when is_list(alphabet) and length(alphabet) < 3 and is_integer(size) do
    raise("The alphabet supplied must have at least 3 graphemes")
  end

  def permuted_string(alphabet, size)
      when is_list(alphabet) and is_integer(size) and size < length(alphabet) / 2 do
    alphabet
    |> Enum.take_random(size)
    |> Enum.join()
  end

  def permuted_string(alphabet, size) when is_list(alphabet) and is_integer(size) do
    raise(
      "The size of the requested string must be less than half the size of the supplied alphabet"
    )
  end
end
