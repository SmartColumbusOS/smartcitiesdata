defmodule DiscoveryStreamsWeb.Endpoint.Instrumenter do
  @moduledoc """
  Module for prometheus instrumentation
  """
  use Prometheus.PhoenixInstrumenter
end

defmodule DiscoveryStreamsWeb.Endpoint do
  use Phoenix.Endpoint, otp_app: :discovery_streams

  socket("/socket", DiscoveryStreamsWeb.UserSocket)

  plug(DiscoveryStreams.MetricsExporter)

  plug(
    Plug.Parsers,
    parsers: [:urlencoded, :multipart, :json],
    pass: ["*/*"],
    json_decoder: Poison
  )

  plug(Plug.MethodOverride)
  plug(Plug.Head)

  plug(
    Plug.Session,
    store: :cookie,
    key: "_cota_streaming_consumer_key",
    signing_salt: "qigJncyv"
  )

  plug(DiscoveryStreamsWeb.Router)

  def init(_key, config) do
    {:ok, config}
  end
end
