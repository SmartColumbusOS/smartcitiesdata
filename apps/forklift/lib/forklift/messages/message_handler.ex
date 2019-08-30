defmodule Forklift.Messages.MessageHandler do
  @moduledoc """
  Reads data off kafka topics, buffering it in batches.
  """
  use Retry
  use Elsa.Consumer.MessageHandler

  alias Forklift.Util
  alias Forklift.TopicManager
  alias Forklift.Datasets.DatasetSchema
  require Logger

  def init(args \\ []) do
    schema = Keyword.fetch!(args, :schema)

    {:ok, %{schema: schema}}
  end

  @doc """
  Handle each kafka message.
  """
  def handle_messages(messages, %{schema: %DatasetSchema{} = schema}) do
    messages
    |> Enum.map(&parse/1)
    |> Enum.map(&yeet_error/1)
    |> Enum.reject(&error_tuple?/1)
    |> Forklift.handle_batch(schema)
    |> send_to_output_topic()

    {:ack, %{schema: schema}}
  end

  defp parse(%{key: key, value: value} = message) do
    case SmartCity.Data.new(value) do
      {:ok, datum} -> Util.add_to_metadata(datum, :kafka_key, key)
      {:error, reason} -> {:error, reason, message}
    end
  end

  defp send_to_output_topic(data_messages) do
    data_messages
    |> Enum.map(fn datum -> {datum._metadata.kafka_key, Util.remove_from_metadata(datum, :kafka_key)} end)
    |> Enum.map(fn {key, datum} -> {key, Jason.encode!(datum)} end)
    |> Util.chunk_by_byte_size(max_bytes(), fn {key, value} -> byte_size(key) + byte_size(value) end)
    |> Enum.each(
      &Elsa.produce_sync(TopicManager.output_topic(), &1, name: Application.get_env(:forklift, :producer_name))
    )
  end

  defp yeet_error({:error, reason, message} = error_tuple) do
    Forklift.DeadLetterQueue.enqueue(message, reason: reason)
    error_tuple
  end

  defp yeet_error(valid), do: valid

  defp error_tuple?({:error, _, _}), do: true
  defp error_tuple?(_), do: false

  defp max_bytes() do
    Application.get_env(:forklift, :max_outgoing_bytes, 900_000)
  end
end
