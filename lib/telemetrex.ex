defmodule Telemetrex do
  @moduledoc """
  TODO
  """

  defmacro __using__(telemetrex_def) do
    telemetrex_def = Telemetrex.App.new(telemetrex_def)

    quote do
      @moduledoc unquote(Telemetrex.ModuledocBuilder.build(telemetrex_def))

      use Telemetrex.Telemetry, app_name: unquote(telemetrex_def.app_name)
    end
  end
end
