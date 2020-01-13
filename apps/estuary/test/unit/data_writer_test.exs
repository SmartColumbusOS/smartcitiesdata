defmodule Estuary.DataWriterTest do
  use ExUnit.Case
  import Mox

  alias Estuary.Datasets.DatasetSchema
  alias Estuary.DataWriter
  alias SmartCity.TestDataGenerator, as: TDG

  setup :set_mox_global
  setup :verify_on_exit!

  test "should insert events to history table" do
    test = self()

    expect(MockTable, :write, 1, fn payload, args ->
      send(test, %{
        payload: payload,
        table: Keyword.get(args, :table),
        schema: Keyword.get(args, :schema)
      })

      :ok
    end)

    table = DatasetSchema.table_name()
    schema = DatasetSchema.schema()

    event_a = %{
      "author" => "A nice fellow",
      "create_ts" => DateTime.to_unix(DateTime.utc_now()),
      "data" => Jason.encode!(TDG.create_dataset(%{})),
      "forwarded" => false,
      "type" => "data:ingest:start"
    }

    event_b = %{
      "author" => "A mean fellow",
      "create_ts" => DateTime.to_unix(DateTime.utc_now()),
      "data" => Jason.encode!(TDG.create_dataset(%{})),
      "forwarded" => false,
      "type" => "data:ingest:end"
    }

    DataWriter.write([event_a, event_b])

    payload = [
      %{
        payload: %{
          "author" => event_a["author"],
          "create_ts" => event_a["create_ts"],
          "data" => event_a["data"],
          "type" => event_a["type"]
        }
      },
      %{
        payload: %{
          "author" => event_b["author"],
          "create_ts" => event_b["create_ts"],
          "data" => event_b["data"],
          "type" => event_b["type"]
        }
      }
    ]

    expected = %{
      payload: payload,
      table: table,
      schema: schema
    }

    assert_receive(^expected)
  end
end