defmodule Telemetrex.ModuledocBuilder do
  @moduledoc """
  TODO
  """

  def build(%Telemetrex.App{} = app) do
    """
    The following telemetry spans are emitted by #{app.app_name}

    #{Enum.map_join(app.spans, "\n", &pretty_print_span(&1, app))}
    """
  end

  defp pretty_print_span(span, app) do
    """
    ## `[#{inspect(app.app_name)}, #{inspect(span.name)}, *]`

    #{span.description}

    This span is started by the following event:

    #{pretty_print_event(span.start_event, span, app)}

    This span is ended by the following event:

    #{pretty_print_event(span.stop_event, span, app)}

    The following events may be emitted within this span:

    #{pretty_print_event(span.exception_event, span, app)}

    #{Enum.map_join(span.extra_events, "\n", &pretty_print_event(&1, span, app))}
    """
  end

  defp pretty_print_event(event, span, app) do
    """
    * `#{inspect([app.app_name, span.name, event.name])}`

        #{event.description}

        This event contains the following measurements:
        
        #{Enum.map_join(event.measurements, "\n    ", fn {k, v} -> "* `#{k}`: #{v}" end)}
        
        This event contains the following metadata:
        
        #{Enum.map_join(event.metadata, "\n    ", fn {k, v} -> "* `#{k}`: #{v}" end)}
    """
  end
end
