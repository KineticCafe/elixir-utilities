required_modules? =
  Enum.all?(
    [
      MyApp.Schema,
      Plug,
      Absinthe.Plug,
      Jason,
      AbsintheSecurity
    ],
    &Code.loaded?/1
  )

if required_modules? do
  defmodule KineticLib.Absinthe.Plug do
    @moduledoc """
    This is a sample of how to extend Absinthe.Plug in useful ways.

    It cannot be used as is, unless your GraphQL schema is literally `MyApp.Schema`.
    """

    use Plug.Builder

    plug KineticLib.Absinthe.Plug.InitializeContext

    plug Absinthe.Plug,
      schema: MyApp.Schema,
      json_codec: Jason,
      pipeline: {__MODULE__, :absinthe_pipeline}

    def absinthe_pipeline(config, options) do
      options = Absinthe.Pipeline.options(options)

      config
      |> Absinthe.Plug.default_pipeline(options)
      |> Absinthe.Pipeline.insert_after(
        Absinthe.Phase.Document.Complexity.Result,
        {AbsintheSecurity.Phase.IntrospectionCheck, options}
      )
      |> Absinthe.Pipeline.insert_after(
        Absinthe.Phase.Document.Result,
        {AbsintheSecurity.Phase.FieldSuggestionsCheck, options}
      )
      |> Absinthe.Pipeline.insert_after(
        Absinthe.Phase.Document.Complexity.Result,
        {AbsintheSecurity.Phase.MaxAliasesCheck, options}
      )
      |> Absinthe.Pipeline.insert_after(
        Absinthe.Phase.Document.Complexity.Result,
        {AbsintheSecurity.Phase.MaxDepthCheck, options}
      )
      |> Absinthe.Pipeline.insert_after(
        Absinthe.Phase.Document.Complexity.Result,
        {AbsintheSecurity.Phase.MaxDirectivesCheck, options}
      )
    end
  end
end
