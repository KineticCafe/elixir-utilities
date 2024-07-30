defmodule KineticLib.Math do
  @moduledoc """
  Useful math extensions.
  """

  @doc """
  Returns an tuple containing the quotient and modulus obtained by dividing `x`
  by `y`.

  ```
  iex> {q, r} = KineticLib.Math.divmod(x, y)
  iex> q == Integer.floor_div(x, y)
  true
  iex> x == q * y + r
  true
  ```

  The quotient is rounded toward negative infinity, as shown in the following
  table:

  | a     |  b  |  a.divmod(b)  |   a/b   | a.modulo(b) | a.remainder(b) |
  | ----: | --: | ------------: | ------: | ----------: | -------------: |
  |  13   |  4  |   3,    1     |   3     |    1        |     1          |
  |  13   | -4  |  -4,   -3     |  -4     |   -3        |     1          |
  | -13   |  4  |  -4,    3     |  -4     |    3        |    -1          |
  | -13   | -4  |   3,   -1     |   3     |   -1        |    -1          |
  |  11.5 |  4  |   2,    3.5   |   2.875 |    3.5      |     3.5        |
  |  11.5 | -4  |  -3,   -0.5   |  -2.875 |   -0.5      |     3.5        |
  | -11.5 |  4  |  -3,    0.5   |  -2.875 |    0.5      |    -3.5        |
  | -11.5 | -4  |   2,   -3.5   |   2.875 |   -3.5      |    -3.5        |

  ### Examples

  iex> divmod(11, 3)
  {3, 2}
  iex> divmod(11, -3)
  {-4, -1}
  iex> divmod(11, 3.5)
  {3, 0.5}
  iex> divmod(-11, 3.5)
  {-4, 3.0}
  iex> divmod(11.5, 3.5)
  {3, 1.0}
  """
  def divmod(x, y) do
    {Integer.floor_div(x, y), mod(x, y)}
  end

  def mod(x, y) do
    x - y * Integer.floor_div(x, y)
  end
end
