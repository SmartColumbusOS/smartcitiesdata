defmodule Forklift.MessageHandlerTest do
  use ExUnit.Case
  use Placebo

  alias SmartCity.TestDataGenerator, as: TDG
  alias Forklift.MessageHandler
  import SmartCity.TestHelper, only: [eventually: 1]

  @moduletag capture_log: true
  test "malformed messages are sent to dead letter queue" do
    malformed_kafka_message =
      TDG.create_data(dataset_id: "ds1")
      |> (fn message -> Helper.make_kafka_message(message, "streaming-transformed") end).()
      |> Map.update(:value, "", fn value ->
        value
        |> Jason.decode!()
        |> Map.drop(["dataset_id", "payload"])
        |> Jason.encode!()
      end)

    dataset = TDG.create_dataset(%{id: "ds1", technical: %{systemName: "system__name", schema: []}})

    expect Forklift.DataWriter.write(any(), dataset: dataset), return: []
    allow Elsa.produce(any(), any(), any()), return: :ok

    MessageHandler.handle_messages([malformed_kafka_message], %{dataset: dataset})

    eventually(fn ->
      {:ok, dlqd_message} = DeadLetter.Carrier.Test.receive()

      assert dlqd_message.app == "forklift"
      assert dlqd_message.dataset_id == "Unknown"
      assert dlqd_message.reason =~ "Invalid data message"
    end)

    refute_called Elsa.produce_sync(any(), any(), name: any())
  end
end
