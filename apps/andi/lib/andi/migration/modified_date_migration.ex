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

  defp try_parse(modified_date) do
    format_strings = [
      "%-m/%-d/%y",
      "%B %d, %Y",
      "%-m/%-d/%Y",
      "%Y-%m-%d",
      "%b %d, %Y",
    ]

    results = Enum.map(format_strings, fn x -> Timex.parse(modified_date, x, :strftime) end)
    ok_dates = for {:ok, term} <- results, do: term

    if length(ok_dates) > 0 do
      ok_dates
      |> List.first()
      |> DateTime.from_naive!("Etc/UTC")
      |> DateTime.to_iso8601()
    else
      nil
    end
end
