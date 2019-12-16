defmodule Forklift.Integration.MessageHandlingTest do
  use ExUnit.Case
  use Placebo

  import Mox
  import Forklift
  import SmartCity.Event, only: [data_ingest_end: 0]
  import SmartCity.Data, only: [end_of_data: 0]
  alias SmartCity.TestDataGenerator, as: TDG

  setup :set_mox_global
  setup :verify_on_exit!

  describe "on receiving a data message" do
    test "retries to persist to Presto if failing" do
      test = self()
      expect(MockTopic, :write, fn _, _ -> :ok end)

      expect(MockTable, :write, 5, fn _, _ ->
        send(test, :retry)
        :error
      end)

      expect(MockTable, :write, 1, fn _, args ->
        send(test, args[:table])
        :ok
      end)

      dataset = TDG.create_dataset(%{})
      table_name = dataset.technical.systemName

      datum = TDG.create_data(%{dataset_id: dataset.id, payload: %{"foo" => "bar"}})
      message = %Elsa.Message{key: "key_one", value: Jason.encode!(datum)}

      Forklift.MessageHandler.handle_messages([message], %{dataset: dataset})

      assert_receive :retry
      assert_receive ^table_name, 2_000
    end

    test "writes message to topic with timing data" do
      test = self()
      expect(MockTable, :write, fn _, _ -> :ok end)
      expect(MockTopic, :write, fn msg, _ -> send(test, msg) end)

      allow(Brook.Event.send(any(), any(), any(), any()), return: :whatever)

      dataset = TDG.create_dataset(%{})
      datum = TDG.create_data(%{dataset_id: dataset.id, payload: %{"foo" => "baz"}, operational: %{timing: []}})
      message = %Elsa.Message{key: "key_two", value: Jason.encode!(datum)}

      Forklift.MessageHandler.handle_messages([message], %{dataset: dataset})

      assert_receive [{"key_two", msg}]

      timing = Jason.decode!(msg)["operational"]["timing"]
      assert Enum.count(timing) == 2
      assert Enum.any?(timing, fn time -> time["label"] == "presto_insert_time" end)
      assert Enum.any?(timing, fn time -> time["label"] == "total_time" end)
    end

    #TODO Test that write complete event is sent to event state after DataWriter.write completes
    # name of event?
    test "sends 'dataset:write_complete event' with timestamp after writing records" do
      expect(MockTable, :write, fn [%{payload: "foobar"}, %{payload: "foobaz"}], _ -> :ok end)
      expect(MockTopic, :write, fn _, _ -> :ok end)

      dataset = TDG.create_dataset(%{})

      datum1 = TDG.create_data(%{dataset_id: dataset.id, payload: "foobar"})
      datum2 = TDG.create_data(%{dataset_id: dataset.id, payload: "foobaz"})

      message1 = %Elsa.Message{key: "one", value: Jason.encode!(datum1)}
      message2 = %Elsa.Message{key: "two", value: Jason.encode!(datum2)}

      Map.put(dataset, :lastUpdatedDate, DateTime.utc_now())

      now = DateTime.utc_now()
      greater_than_now = fn event_data ->
        event_data.id == dataset.id &&
          DateTime.to_iso8601(event_data.timestamp) > DateTime.to_iso8601(now)
      end
      expect Brook.Event.send(instance_name(), "dataset:write_complete", :forklift, is(greater_than_now)), return: :ok
      Forklift.MessageHandler.handle_messages([message1, message2], %{dataset: dataset})
    end

    test "handles errors gracefully" do
      allow(Brook.Event.send(instance_name(), "dataset:write_complete", any(), any()), return: :whatever)

      stub(MockTable, :write, fn _, _ -> {:error, :raisins} end)
      stub(MockTopic, :write, fn _, _ -> :ok end)

      dataset = TDG.create_dataset(%{})

      datum1 = TDG.create_data(%{dataset_id: dataset.id, payload: "foobar"})
      datum2 = TDG.create_data(%{dataset_id: dataset.id, payload: "foobaz"})

      message1 = %Elsa.Message{key: "one", value: Jason.encode!(datum1)}
      message2 = %Elsa.Message{key: "two", value: Jason.encode!(datum2)}

      assert_raise RuntimeError, fn ->
        Forklift.MessageHandler.handle_messages([message1, message2], %{dataset: dataset})
      end

      refute_called(Brook.Event.send, :any)
    end
  end

  describe "on receiving end-of-data message" do
    test "shuts down dataset reader" do
      expect(MockTable, :write, fn [%{payload: "foobar"}, %{payload: "foobaz"}], _ -> :ok end)
      expect(MockTopic, :write, fn _, _ -> :ok end)

      dataset = TDG.create_dataset(%{})

      datum1 = TDG.create_data(%{dataset_id: dataset.id, payload: "foobar"})
      datum2 = TDG.create_data(%{dataset_id: dataset.id, payload: "foobaz"})

      message1 = %Elsa.Message{key: "one", value: Jason.encode!(datum1)}
      message2 = %Elsa.Message{key: "two", value: Jason.encode!(datum2)}

      allow(Brook.Event.send(instance_name(), "dataset:write_complete", any(), any()), return: :whatever)
      expect Brook.Event.send(instance_name(), data_ingest_end(), :forklift, dataset), return: :ok
      Forklift.MessageHandler.handle_messages([message1, message2, end_of_data()], %{dataset: dataset})
    end
  end
end
