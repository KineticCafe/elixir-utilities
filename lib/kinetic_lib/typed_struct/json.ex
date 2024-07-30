defmodule KineticLib.TypedStruct.Json do
  @moduledoc """
  A TypedStruct plugin that automatically adds a JSON encoder protocol derivation.

  There are two options available during initialization:

  - `json_encoder`: The JSON encoder module to derive. Defaults to `Jason.Encoder`.
  - `json`: If specified as `json: :all`, all fields will be added to the JSON encoder
    automatically, equivalent to `@derive json_encoder`.

  Fields have an additional option available:

  - `json`: If specified as `json: true`, this field will be added to the JSON encoder.
    Any other value will cause the field to be ignored. This field option is ignored if
    the plugin was initialized with `json: :all`.
  """

  use TypedStruct.Plugin

  @impl true
  defmacro init(opts) do
    json_encoder = opts[:json_encoder] || Jason.Encoder

    if opts[:json] == :all do
      quote do
        @derive unquote(json_encoder)
      end
    else
      quote do
        @ts_json_encoder unquote(json_encoder)

        Module.register_attribute(__MODULE__, :ts_json_fields, accumulate: true)
      end
    end
  end

  @impl true
  def field(name, _type, opts, _env) do
    if opts[:json] == true do
      quote do
        @ts_json_fields unquote(name)
      end
    end
  end

  @impl true
  def after_definition(opts) do
    if opts[:json] != :all do
      quote do
        if !Enum.empty?(@ts_json_fields) do
          require Protocol
          Protocol.derive(@ts_json_encoder, __MODULE__, only: @ts_json_fields)
        end

        Module.delete_attribute(__MODULE__, :ts_json_fields)
        Module.delete_attribute(__MODULE__, :ts_json_encoder)
      end
    end
  end
end
