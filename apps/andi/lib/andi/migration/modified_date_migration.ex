defmodule Andi.Migration.ModifiedDateMigration do
  import SmartCity.Event, only: [dataset_update: 0]
  import Andi, only: [instance_name: 0]

  @instance Andi.instance_name()

  def do_migration() do
    Brook.get_all_values!(@instance, :dataset)
    |> Enum.each(&migrate_dataset/1)
  end

  defp migrate_dataset(dataset) do
    migrated_dataset = fix_timing(dataset)
    Brook.Event.send(@instance, dataset_update(), :andi, migrated_dataset)
    Brook.ViewState.merge(:dataset, migrated_dataset.id, migrated_dataset)
  end

  defp fix_timing(dataset) do
    dataset
  end
end
