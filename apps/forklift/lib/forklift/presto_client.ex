defmodule Forklift.PrestoClient do
  alias Forklift.Statement

  def upload_data(dataset_id, messages) do
    schema = RegistryStore.get_schema(dataset_id)

    statement = Statement.build(schema, messages)

    Prestige.execute(statement, catalog: "hive", schema: "default")

  rescue
    e -> IO.inspect(e, label: "UNHANDLED ERROR IN PRESTO CLIENT")
  end
end
