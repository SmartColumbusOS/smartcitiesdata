defmodule Andi.Services.DatasetDisable do
  @moduledoc """
  Service for disabling datasets
  """
  import Andi
  import SmartCity.Event, only: [dataset_disable: 0]

  @doc """
  Disable a dataset
  """
  @spec disable(term()) :: {:ok, SmartCity.Dataset.t()} | {:error, any()} | {:not_found, any()}
  def disable(dataset_id) do
    with {:ok, dataset} when not is_nil(dataset) <- Brook.get(instance_name(), :dataset, dataset_id),
         :ok <- Brook.Event.send(instance_name(), dataset_disable(), :andi, dataset) do
      {:ok, dataset}
    else
      {:ok, nil} ->
        {:not_found, dataset_id}

      error ->
        error
    end
  end
end
