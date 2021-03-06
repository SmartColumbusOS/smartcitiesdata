defmodule DiscoveryApi.Data.CachePopulator do
  @moduledoc """
  Module to prepopulate the SystemNameCache with values from the Brook view state.
  """
  alias DiscoveryApi.Data.SystemNameCache
  alias DiscoveryApi.Search
  use GenServer, restart: :transient

  def start_link(_) do
    GenServer.start_link(__MODULE__, nil)
  end

  def init(_) do
    models = get_all_models()

    Enum.each(models, fn model ->
      SystemNameCache.put(model.id, model.organizationDetails.orgName, model.name)
      Search.Storage.index(model)
    end)

    {:ok, nil, {:continue, :stop}}
  end

  def handle_continue(:stop, _) do
    {:stop, :normal, nil}
  end

  defp get_all_models(), do: Brook.get_all_values!(DiscoveryApi.instance(), :models)
end
