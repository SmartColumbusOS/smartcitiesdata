defmodule DiscoveryApi.RecommendationEngine do
  @moduledoc false

  alias DiscoveryApi.Data.Persistence

  @prefix "discovery_api:dataset_recommendations:"

  def save(%SmartCity.Dataset{} = dataset) do
    recommendation_metadata = %{
      id: dataset.id,
      systemName: dataset.technical.systemName,
      orgName: dataset.technical.orgName,
      dataName: dataset.technical.dataName,
      dataTitle: dataset.business.dataTitle,
      schema: schema_mapper(dataset.technical.schema)
    }

    case Persistence.persist(@prefix <> dataset.id, recommendation_metadata) do
      {:ok, _} -> :ok
      error -> error
    end
  end

  def get_recommendations(%DiscoveryApi.Data.Model{} = dataset_to_match) do
    get_all_view_state_items()
    |> Enum.filter(&recommend?(&1, dataset_to_match))
    |> Enum.reject(&self?(&1, dataset_to_match))
    |> Enum.map(&map_result(&1))
  end

  defp schema_mapper(schema) do
    Enum.map(schema, fn column ->
      %{name: column[:name], type: column[:type]}
    end)
  end

  defp get_all_view_state_items() do
    Persistence.get_all(@prefix <> "*")
    |> Enum.map(&Jason.decode!(&1, keys: :atoms))
  end

  defp recommend?(%{schema: schema}, %{schema: schema_to_match}) do
    schema_to_match = schema_to_match |> schema_mapper() |> MapSet.new()
    this_schema = MapSet.new(schema)
    count_of_shared_columns = MapSet.intersection(schema_to_match, this_schema) |> MapSet.size()
    count_of_shared_columns >= 3
  end

  defp self?(%{id: id}, %{id: id_to_match}) do
    id == id_to_match
  end

  defp map_result(result) do
    %{
      id: result.id,
      systemName: result.systemName,
      dataName: result.dataName,
      orgName: result.orgName,
      dataTitle: result.dataTitle
    }
  end
end
