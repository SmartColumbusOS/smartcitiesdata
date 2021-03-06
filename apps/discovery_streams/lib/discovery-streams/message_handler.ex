defmodule DiscoveryStreams.MessageHandler do
  @moduledoc """
    Gets messages out of kafka, adds them to the cache,
    broadcasts them, and records metrics.
  """

  require Logger
  require Poison
  require GenServer
  alias StreamingMetrics.Hostname

  @metric_collector Application.get_env(:streaming_metrics, :collector)

  def handle_messages(messages) do
    json_messages =
      messages
      |> Enum.map(&log_message/1)
      |> Enum.reduce([], &parse_message/2)

    record_outbound_count_metrics(json_messages)

    Enum.each(json_messages, &add_to_cache/1)
    Enum.each(json_messages, &broadcast/1)
  end

  defp record_outbound_count_metrics(messages) do
    messages
    |> Enum.reduce(%{}, fn %{topic: topic}, acc -> Map.update(acc, topic, 1, &(&1 + 1)) end)
    |> Enum.each(&record_metric/1)
  end

  defp record_metric({topic, count}) do
    converted_topic =
      topic
      |> String.replace("-", "_")

    count
    |> @metric_collector.count_metric("records", [{"PodHostname", "#{get_hostname()}"}, {"type", "outbound"}])
    |> List.wrap()
    |> @metric_collector.record_metrics(converted_topic)
    |> case do
      {:ok, _} -> {}
      {:error, reason} -> Logger.warn("Unable to write application metrics: #{inspect(reason)}")
    end
  end

  defp parse_message(%{value: value} = message, acc) do
    case Poison.decode(value) do
      {:ok, parsed} ->
        [%{message | value: parsed["payload"]} | acc]

      {:error, reason} ->
        Logger.warn("Poison parse error: #{inspect(reason)}")
        acc
    end
  end

  # sobelow_skip ["DOS.StringToAtom"]
  defp add_to_cache(%{key: key, topic: topic, value: message}) do
    dataset_id = DiscoveryStreams.TopicHelper.dataset_id(topic)

    GenServer.abcast(
      DiscoveryStreams.CacheGenserver,
      {:put, String.to_atom(dataset_id), key, message}
    )
  end

  defp broadcast(%{topic: "transformed-" <> channel, value: data}) do
    case Brook.get(:discovery_streams, :streaming_datasets_by_id, channel) do
      {:ok, system_name} ->
        DiscoveryStreamsWeb.Endpoint.broadcast!("streaming:#{system_name}", "update", data)

      _ ->
        nil
    end
  end

  defp log_message(message) do
    Logger.log(:info, "#{inspect(message)}")
    message
  end

  defp get_hostname(), do: Hostname.get()
end
