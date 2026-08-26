defmodule ThousandIsland.TelemetryTest do
  use ExUnit.Case, async: true

  alias ThousandIsland.Telemetry

  test "start spans preserve caller-supplied system and monotonic times" do
    handler_id = make_ref()

    :ok =
      :telemetry.attach(
        handler_id,
        [:thousand_island, :connection, :start],
        &__MODULE__.forward_event/4,
        self()
      )

    on_exit(fn -> :telemetry.detach(handler_id) end)

    _span =
      Telemetry.start_span(
        :connection,
        %{monotonic_time: 123, system_time: 456},
        %{handler: __MODULE__}
      )

    assert_receive {:telemetry_event, %{monotonic_time: 123, system_time: 456}, metadata}
    assert metadata.handler == __MODULE__
    assert is_reference(metadata.telemetry_span_context)
  end

  def forward_event(_event, measurements, metadata, pid) do
    send(pid, {:telemetry_event, measurements, metadata})
  end
end
